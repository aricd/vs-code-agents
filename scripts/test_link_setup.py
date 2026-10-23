#!/usr/bin/env python3
"""test_link_setup.py -- regression oracle for link_setup.py's self-reference guard.

Mode under test: FM-T-SELFLINK.THROUGH-LINK (guarantee G-T-SELFLINK).

WHY THIS EXISTS. A destination that resolves, through a link higher in its own path, back to
the link source is the one condition under which "replace the destination" is unconditionally
destructive -- and it was the one condition the drift guard read as safe, because
trees_differ(dest, source) necessarily reports "identical" when the two paths ARE the same
directory. On 2026-09-16 that emptied the repository's skills/ tree.

THIS IS A PROPERTY TEST, NOT A REGRESSION TEST IN COSTUME. Case A alone would also pass against
an implementation that refused everything, which is why Case B (an ordinary, non-self-
referential target) is part of the oracle: the guard must refuse self-reference AND still link
normally. Both must hold for a PASS.

No pytest dependency (this repo's scripts/ tests are standalone and exit 0/1).

USAGE
    python3 scripts/test_link_setup.py                    # test the sibling link_setup.py
    python3 scripts/test_link_setup.py /path/to/other.py  # test a specific implementation
                                                          #   (used to demonstrate red/green)
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

SKILLS = ("alpha", "beta", "gamma")


def load_impl(path: Path):
    spec = importlib.util.spec_from_file_location("link_setup_under_test", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build_repo(root: Path) -> Path:
    """A miniature shared repo: <root>/repo/skills/<name>/SKILL.md"""
    skills = root / "repo" / "skills"
    for name in SKILLS:
        d = skills / name
        d.mkdir(parents=True)
        (d / "SKILL.md").write_text(f"name: {name}\n", encoding="utf-8")
    return skills


def write_config(path: Path, shared_root: Path, target_root: Path) -> Path:
    path.write_text(
        f'shared_root: "{shared_root.as_posix()}"\n'
        f'preserve: "old"\n'
        f"backup_replaced: true\n"
        f'backup_ext: ".bak"\n'
        f"targets:\n"
        f'  - name: "t"\n'
        f'    target_root: "{target_root.as_posix()}"\n'
        f'    link_skills: "true"\n'
        f'    link_agents: "false"\n'
        f'    link_prompts: "false"\n'
        f'    link_scripts: "false"\n',
        encoding="utf-8",
    )
    return path


def sources_intact(skills: Path) -> bool:
    return all(
        (skills / n).is_dir() and (skills / n / "SKILL.md").read_text(encoding="utf-8").strip()
        == f"name: {n}"
        for n in SKILLS
    )


def any_bak(root: Path) -> list:
    return [str(p) for p in root.rglob("*.bak")]


def case_a_self_reference(mod, tmp: Path) -> list:
    """Destination resolves through a whole-directory link back to the source. MUST refuse."""
    failures = []
    root = tmp / "case_a"
    root.mkdir()
    skills = build_repo(root)

    agents = root / "home" / ".agents"
    agents.mkdir(parents=True)
    # The real-world shape: ~/.agents/skills is ONE link onto the whole shared skills/ tree.
    os.symlink(skills, agents / "skills", target_is_directory=True)

    cfg = write_config(root / "cfg.yaml", root / "repo", agents)
    rc = mod.main(["--config", str(cfg), "--verbose"])

    if rc == 0:
        failures.append("Case A: expected non-zero exit, got 0")
    if not sources_intact(skills):
        failures.append("Case A: SOURCE DESTROYED -- skills missing or altered after run")
    stray = any_bak(root)
    if stray:
        failures.append(f"Case A: .bak artifacts created (source was moved): {stray}")
    return failures


def case_b_ordinary_target(mod, tmp: Path) -> list:
    """An ordinary target with no self-reference. MUST still link."""
    failures = []
    root = tmp / "case_b"
    root.mkdir()
    skills = build_repo(root)

    target = root / "workspace" / ".github"
    target.mkdir(parents=True)

    cfg = write_config(root / "cfg.yaml", root / "repo", target)
    rc = mod.main(["--config", str(cfg), "--verbose"])

    if rc != 0:
        failures.append(f"Case B: expected exit 0, got {rc} -- guard is refusing valid targets")
    for n in SKILLS:
        link = target / "skills" / n
        if not link.exists():
            failures.append(f"Case B: {n} was not linked")
        elif os.path.realpath(link) != os.path.realpath(skills / n):
            failures.append(f"Case B: {n} resolves to {os.path.realpath(link)}, not its source")
    if not sources_intact(skills):
        failures.append("Case B: source altered by a normal link run")
    return failures


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    impl = Path(argv[0]) if argv else Path(__file__).resolve().parent / "link_setup.py"
    print(f"Testing implementation: {impl}")
    mod = load_impl(impl)

    failures = []
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        failures += case_a_self_reference(mod, tmp)
        failures += case_b_ordinary_target(mod, tmp)

    print()
    print("=" * 60)
    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        print(f"\nFAIL: {len(failures)} assertion(s) failed")
        return 1
    print("PASS: self-reference refused (Case A); ordinary target still links (Case B)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
