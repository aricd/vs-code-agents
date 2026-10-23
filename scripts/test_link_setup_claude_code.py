#!/usr/bin/env python3
"""test_link_setup_claude_code.py -- oracle for link_setup.py's `format: claude-code` target.

The claude-code target GENERATES files (it does not link), so it owns content it writes and
must never own content it did not write. Each case below pins one half of that contract:

  A  conversion   frontmatter, tool mapping, lowercase names, absolute repo paths
  B  idempotence  a second run changes nothing
  C  protection   a hand-written file at a destination survives a normal run
  D  pruning      a generated file whose source is gone is removed; a hand-written one is not

No pytest dependency (this repo's scripts/ tests are standalone and exit 0/1).

USAGE
    python3 scripts/test_link_setup_claude_code.py                    # test the sibling link_setup.py
    python3 scripts/test_link_setup_claude_code.py /path/to/other.py  # test a specific implementation
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

AGENT = """---
description: Reviews code.
name: Code Reviewer
target: vscode
argument-hint: Reference the plan
tools: ['execute/runInTerminal', read, 'todo', 'vscode/vscodeAPI']
---
Run `pwsh scripts/check.ps1` then ./scripts/check.sh, read `agents/other.agent.md`.
Leave `scripts/missing.ps1`, `.agent-output/scripts/x.md` and agents/prompts alone.
"""

PROMPT = """---
name: "OBS-Create"
description: >
  Create an OBS
  for a service.
argument-hint: "ServiceName"
agent: "agent"
---
Use `templates/t.md`. Literal awk '{print $1}' and $ARGUMENTS stay literal.
"""


def load_impl(path: Path):
    spec = importlib.util.spec_from_file_location("link_setup_under_test", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build(root: Path) -> tuple:
    repo = root / "repo"
    for rel, text in {
        "agents/reviewer.agent.md": AGENT,
        "agents/other.agent.md": "---\nname: Other\ndescription: x\n---\nbody\n",
        "prompts/obs.prompt.md": PROMPT,
        "scripts/check.ps1": "",
        "scripts/check.sh": "",
        "templates/t.md": "",
    }.items():
        (repo / rel).parent.mkdir(parents=True, exist_ok=True)
        (repo / rel).write_text(text, encoding="utf-8")
    (repo / "skills").mkdir()
    home = root / "home" / ".claude"
    home.mkdir(parents=True)
    cfg = root / "cfg.yaml"
    cfg.write_text(
        f'shared_root: "{repo.as_posix()}"\n'
        f"targets:\n"
        f'  - name: "claude-code"\n'
        f'    target_root: "{home.as_posix()}"\n'
        f'    format: "claude-code"\n',
        encoding="utf-8",
    )
    return repo, home, cfg


def snapshot(home: Path) -> dict:
    return {str(p.relative_to(home)): p.read_text(encoding="utf-8")
            for p in sorted(home.rglob("*.md"))}


def run_cases(mod, tmp: Path) -> list:
    failures = []
    repo, home, cfg = build(tmp)
    argv = ["--config", str(cfg)]

    # A -- conversion
    if mod.main(argv) != 0:
        failures.append("A: first run exited non-zero")
    agent = home / "agents" / "code-reviewer.md"
    command = home / "commands" / "obs-create.md"
    for path in (agent, command, home / "agents" / "other.md"):
        if not path.is_file():
            failures.append(f"A: {path.relative_to(home)} not generated")
    if failures:
        return failures
    a, c, root = agent.read_text(encoding="utf-8"), command.read_text(encoding="utf-8"), repo.as_posix()
    expect_in = {
        "A: name": (a, "\nname: code-reviewer\n"),
        "A: argument-hint folded into description": (a, '"Reviews code. Input: Reference the plan"'),
        "A: tools": (a, "\ntools: Bash, PowerShell, Read, LSP, TaskCreate, TaskGet, TaskList, "
                        "TaskUpdate, TodoWrite, Skill, ToolSearch\n"),
        "A: script path absolutized": (a, f"`pwsh {root}/scripts/check.ps1`"),
        "A: ./ script path absolutized": (a, f" {root}/scripts/check.sh,"),
        "A: agent path absolutized": (a, f"`{root}/agents/other.agent.md`"),
        "A: missing path untouched": (a, "`scripts/missing.ps1`"),
        "A: workspace path untouched": (a, "`.agent-output/scripts/x.md`"),
        "A: prose untouched": (a, " agents/prompts alone"),
        "A: folded description": (c, '\ndescription: "Create an OBS for a service."\n'),
        "A: argument-hint": (c, '\nargument-hint: "ServiceName"\n'),
        "A: template path absolutized": (c, f"`{root}/templates/t.md`"),
        "A: placeholders escaped": (c, "'{print \\$1}' and \\$ARGUMENTS"),
    }
    for label, (text, needle) in expect_in.items():
        if needle not in text:
            failures.append(f"{label}: expected {needle!r}")
    for label, (text, needle) in {
        "A: VS Code-only key dropped": (a, "target:"),
        "A: prompt agent key dropped": (c, "agent:"),
    }.items():
        if needle in text:
            failures.append(f"{label}: found {needle!r}")

    # B -- idempotence
    before = snapshot(home)
    mod.main(argv)
    if snapshot(home) != before:
        failures.append("B: second run changed generated files")

    # C -- protection of a hand-written file
    hand = "---\nname: obs-create\ndescription: mine\n---\nhand-written\n"
    command.write_text(hand, encoding="utf-8")
    mod.main(argv)
    if command.read_text(encoding="utf-8") != hand:
        failures.append("C: hand-written command was overwritten without --force/--backup")

    # D -- pruning
    keep = home / "agents" / "mine.md"
    keep.write_text("---\nname: mine\ndescription: x\n---\n", encoding="utf-8")
    os.remove(repo / "agents" / "other.agent.md")
    mod.main(argv)
    if (home / "agents" / "other.md").exists():
        failures.append("D: generated file for a removed source was not pruned")
    if not keep.exists():
        failures.append("D: hand-written agent was pruned")
    return failures


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    impl = Path(argv[0]) if argv else Path(__file__).resolve().parent / "link_setup.py"
    print(f"Testing implementation: {impl}")
    mod = load_impl(impl)

    with tempfile.TemporaryDirectory() as td:
        failures = run_cases(mod, Path(td))

    print()
    print("=" * 60)
    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        print(f"\nFAIL: {len(failures)} assertion(s) failed")
        return 1
    print("PASS: conversion (A), idempotence (B), hand-written protection (C), pruning (D)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
