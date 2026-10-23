#!/usr/bin/env python3
"""validate_skill.py -- check SKILL.md files against the rules each consuming surface enforces.

Every finding names the surfaces it affects, so a skill that is only ever used in Claude Code
can ignore an upload-only finding knowingly instead of discovering it at upload time.

    ERROR  breaks loading, triggering, or upload on the named surface(s)
    WARN   works, but degrades or surprises (truncation, substitution, shell execution)

USAGE
    python validate_skill.py <skill-dir | dir-of-skills> [...] [--upload]

    --upload   treat frontmatter keys outside the Agent Skills spec as ERRORs (claude.ai upload,
               Skills API, package_skill.py reject them); default is WARN

Exit status is 1 when any ERROR is reported. PyYAML is used for the strict YAML check when
importable; without it that one check is skipped and reported.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PORTABLE_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
CLAUDE_CODE_KEYS = PORTABLE_KEYS | {
    "when_to_use", "argument-hint", "arguments", "disable-model-invocation", "user-invocable",
    "model", "effort", "context", "agent", "hooks", "paths", "shell",
}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
XML_TAG_RE = re.compile(r"</?[A-Za-z][^<>]*>")
# Claude Code runs !`cmd` at the start of a line or after whitespace, and ```! fenced blocks.
INJECTION_RE = re.compile(r"(?:^|(?<=\s))!`[^`]+`|^```!", re.M)

SPEC = "Agent Skills spec"
UPLOAD = "claude.ai upload/Skills API"
VSCODE = "VS Code"
CC = "Claude Code"


def split(text: str):
    """(frontmatter text or None, body, problem or None)."""
    if text.startswith("﻿"):
        return None, text, "file starts with a UTF-8 BOM, so the first line is not `---`"
    if not text.startswith("---\n"):
        return None, text, "first line is not `---`"
    end = text.find("\n---\n", 3)
    if end == -1 and text.endswith("\n---"):
        end = len(text) - 4
    if end == -1:
        return None, text, "no closing `---` line"
    return text[4:end], text[end + 5:], None


def parse(head: str):
    """(fields dict or None, strict-parse error or None, strict check ran?)."""
    try:
        import yaml  # type: ignore
    except ImportError:
        fields = {}
        for line in head.split("\n"):
            m = re.match(r"^([\w-]+):\s*(.*)$", line)
            if m:
                fields[m.group(1)] = m.group(2).strip().strip("\"'")
        return fields, None, False
    try:
        fields = yaml.safe_load(head)
    except yaml.YAMLError as exc:
        return None, " ".join(str(exc).split()), True
    if not isinstance(fields, dict):
        return None, "frontmatter is not a YAML mapping", True
    return fields, None, True


def check(skill_dir: Path, upload: bool) -> tuple:
    findings = []

    def add(level, surfaces, msg):
        findings.append((level, surfaces, msg))

    path = skill_dir / "SKILL.md"
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    head, body, problem = split(text)
    if problem:
        add("ERROR", [CC, SPEC, UPLOAD, VSCODE],
            f"{problem}; Claude Code then treats the whole file as content (no name, no description)")
        return findings, None, ""
    fields, yaml_error, strict = parse(head)
    if yaml_error:
        add("ERROR", [SPEC, UPLOAD, CC],
            f"frontmatter is not valid YAML ({yaml_error}); where Claude Code's parser also rejects "
            "it, the skill loads with empty metadata and never auto-triggers. Fold the value with "
            "`>-` or quote it")
        return findings, None, body
    if not strict:
        add("WARN", ["all"], "PyYAML not installed -- strict YAML validity was not checked")

    name = fields.get("name")
    if not name:
        add("ERROR", [SPEC, UPLOAD, VSCODE], "`name` is missing (Claude Code falls back to the directory name)")
    else:
        name = str(name)
        if len(name) > 64 or not NAME_RE.match(name):
            add("ERROR", [SPEC, UPLOAD, VSCODE],
                f"`name: {name}` must be 1-64 chars of a-z, 0-9 and single hyphens, no leading/trailing hyphen")
        if name != skill_dir.name:
            add("ERROR", [SPEC, UPLOAD, VSCODE], f"`name: {name}` does not match directory `{skill_dir.name}`")
        if "anthropic" in name or "claude" in name:
            add("ERROR", [UPLOAD], f"`name: {name}` contains a reserved word (anthropic, claude)")
        if name.lower() == "synced":
            add("ERROR", [CC], "`synced` is reserved for skills downloaded from claude.ai; Claude Code skips it")

    desc = " ".join(str(fields.get("description") or "").split())
    if not desc:
        add("ERROR", [SPEC, UPLOAD, CC], "`description` is missing or empty; nothing for the model to match")
    else:
        if len(desc) > 1024:
            add("ERROR", [SPEC, UPLOAD, VSCODE], f"`description` is {len(desc)} chars (max 1024)")
        if XML_TAG_RE.search(desc):
            add("ERROR", [UPLOAD], "`description` contains an XML tag")
        if re.match(r"(I|I'm|You)\b", desc):
            add("WARN", [UPLOAD, CC], "`description` is not in third person (it is injected into the system prompt)")
    listing = " ".join(filter(None, [desc, " ".join(str(fields.get("when_to_use") or "").split())]))
    if len(listing) > 1536:
        add("WARN", [CC], f"description + when_to_use is {len(listing)} chars; the listing truncates at 1,536")

    for key in fields:
        if key not in CLAUDE_CODE_KEYS:
            add("WARN", [CC, SPEC], f"unknown key `{key}` -- Claude Code ignores it silently (typo?)")
        elif key not in PORTABLE_KEYS:
            add("ERROR" if upload else "WARN", [UPLOAD],
                f"`{key}` is not in the Agent Skills spec; upload fails with a hard error")
    compat = fields.get("compatibility")
    if compat is not None and len(str(compat)) > 500:
        add("ERROR", [SPEC, UPLOAD], "`compatibility` exceeds 500 chars")
    meta = fields.get("metadata")
    if meta is not None:
        if not isinstance(meta, dict):
            add("ERROR", [SPEC, CC], "`metadata` must be a map (Claude Code drops any other value)")
        elif any(not isinstance(v, str) for v in meta.values()):
            add("WARN", [SPEC], "`metadata` values should be strings (quote numbers, e.g. version: \"1.0\")")

    lines = body.count("\n") + 1
    if lines > 500:
        add("WARN", [CC, SPEC], f"body is {lines} lines (keep SKILL.md under 500; move detail to references/)")
    # Claude Code substitutes these in SKILL.md content; a preceding backslash keeps them literal.
    names = [r"ARGUMENTS\b", r"\d"] + [re.escape(str(a)) + r"\b" for a in _arg_names(fields)]
    for m in re.finditer(r"(?<!\\)\$(" + "|".join(names) + ")", body):
        add("WARN", [CC], f"`${m.group(1)}` on body line {body.count(chr(10), 0, m.start()) + 1} is "
                          "substituted when invoked with arguments; escape it as `\\$` if literal")
    for m in INJECTION_RE.finditer(body):
        add("WARN", [CC], f"body line {body.count(chr(10), 0, m.start()) + 1} runs a shell command when the "
                          f"skill loads in Claude Code: {m.group(0)[:60]}")
    prose = re.sub(r"^(```|~~~).*?^\1", "", body, flags=re.M | re.S)   # links in fences are examples
    for m in re.finditer(r"\]\((?!https?:|#|mailto:|/)([^)\s#]+)", prose):
        if not (skill_dir / m.group(1)).exists():
            add("WARN", ["all"], f"linked file not found relative to the skill directory: {m.group(1)}")
    return findings, name, listing


def _arg_names(fields: dict) -> list:
    args = fields.get("arguments")
    if isinstance(args, str):
        return args.split()
    return [str(a) for a in args] if isinstance(args, list) else []


def skill_dirs(paths) -> list:
    out = []
    for p in map(Path, paths):
        if (p / "SKILL.md").is_file():
            out.append(p)
        elif p.is_dir():
            out += sorted(d for d in p.iterdir() if (d / "SKILL.md").is_file())
        else:
            print(f"ERROR {p}: not a skill directory or a directory of skills")
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--upload", action="store_true", help="non-spec frontmatter keys are errors")
    args = ap.parse_args(argv)

    errors, seen, total = 0, {}, 0
    dirs = skill_dirs(args.paths)
    for d in dirs:
        findings, name, listing = check(d, args.upload)
        total += min(len(listing), 1536)
        if name and name in seen:
            findings.append(("ERROR", [CC, VSCODE], f"name `{name}` is also used by {seen[name]}"))
        seen.setdefault(name, d)
        for level, surfaces, msg in findings:
            errors += level == "ERROR"
            print(f"{level:5} {d.name}: [{', '.join(surfaces)}] {msg}")
    print(f"\n{len(dirs)} skill(s), {errors} error(s); listing text {total:,} chars "
          "(Claude Code budget: 1% of the context window -- see its --debug log)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
