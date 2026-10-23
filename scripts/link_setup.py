#!/usr/bin/env python3
"""link_setup.py -- distribute shared agents/skills/prompts/scripts into workspaces.

CANONICAL IMPLEMENTATION. `link-setup.ps1` and `link-setup.sh` are thin shims that
exec this file; they hold no logic of their own. Edit behaviour here only.

DIRECTION
    shared repo  ->  each consuming workspace

    <target_root>/skills/<skill>    ->  <shared_root>/skills/<skill>
    <target_root>/agents/<agent>    ->  <shared_root>/agents/<agent>
    <target_root>/prompts/<prompt>  ->  <shared_root>/prompts/<prompt>
    <target_root>/scripts/<script>  ->  <shared_root>/scripts/<script>

    Per-item links (not one directory link) so a workspace can keep sibling
    content -- notably an `old/` archive -- alongside the links.

    A target with `format: "claude-code"` is GENERATED instead of linked, because
    Claude Code reads a different agent/command format than VS Code:

    <target_root>/agents/<name>.md    <=  <shared_root>/agents/<agent>.agent.md
    <target_root>/commands/<name>.md  <=  <shared_root>/prompts/<prompt>.prompt.md

    Skills need no conversion; <target_root>/skills is one whole-directory link
    made by hand (LINKING.md). Re-run after editing an agent or prompt.

LINK STRATEGY (why this file exists)
    POSIX    directories and files -> symlink.
    Windows  directories -> NTFS *junction* via _winapi.CreateJunction.
             files       -> symlink, falling back to hardlink, falling back to copy.

    This matters: on Windows a symlink needs Developer Mode or an elevated shell,
    but a junction needs neither. The previous bash implementation used `ln -s`
    for everything, which fails unprivileged on Windows -- the observed result was
    that someone copied the tree by hand instead, and the copy then forked from
    the repo in both directions.

SAFETY
    This tool refuses, by default, to destroy a real (non-link) target directory
    whose contents differ from the source. That is not paranoia: the divergence
    described above included an entire test suite and several reference documents
    that existed ONLY in the deployed copy. Use `--check` to see the drift,
    `--backup` to move it aside, or `--force` to overwrite it deliberately.

USAGE
    python link_setup.py [--config FILE] [--check] [--dry-run] [--verbose]
                         [--backup] [--force] [--target NAME]
"""

from __future__ import annotations

import argparse
import filecmp
import json
import os
import platform
import re
import shutil
import sys
from pathlib import Path
from typing import Iterable, NamedTuple

IS_WINDOWS = platform.system() == "Windows"
PRESERVE_DEFAULT = "old"
LINKABLE_DIRS = ("skills", "agents", "prompts", "scripts")


# --------------------------------------------------------------------------
# Config parsing
#
# Deliberately a small hand-rolled reader for the documented subset of
# link-config.yaml, so this script has no third-party dependency. PyYAML is
# used when importable, because it is strictly more correct.
# --------------------------------------------------------------------------

class Target(NamedTuple):
    name: str
    root: str
    link: dict          # {"skills": bool, "agents": bool, ...}
    format: str = "link"    # "link" | "claude-code"


class Config(NamedTuple):
    shared_root: Path
    preserve: set
    backup_ext: str
    backup_replaced: bool
    targets: list


def _as_bool(value, default: bool = True) -> bool:
    if value is None:
        return default
    return str(value).strip().strip("\"'").lower() in ("true", "yes", "1", "on")


def _strip(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    return value


def _parse_with_pyyaml(text: str):
    try:
        import yaml  # type: ignore
    except ImportError:
        return None
    try:
        return yaml.safe_load(text)
    except Exception:
        return None


def _parse_fallback(text: str) -> dict:
    """Minimal reader for the documented link-config.yaml subset."""
    data: dict = {"targets": []}
    current: dict | None = None
    in_targets = False

    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue

        if not line[0].isspace():
            key = line.split(":", 1)[0].strip()
            in_targets = key == "targets"
            if not in_targets and ":" in line:
                data[key] = _strip(line.split(":", 1)[1])
            continue

        if not in_targets:
            continue

        stripped = line.strip()
        if stripped.startswith("- "):
            current = {}
            data["targets"].append(current)
            stripped = stripped[2:].strip()
        if current is not None and ":" in stripped:
            k, v = stripped.split(":", 1)
            current[k.strip()] = _strip(v)

    return data


def load_config(path: Path) -> Config:
    text = path.read_text(encoding="utf-8")
    raw = _parse_with_pyyaml(text) or _parse_fallback(text)

    shared_root = str(raw.get("shared_root") or "..")
    root_path = Path(shared_root)
    if not root_path.is_absolute():
        root_path = (path.parent / root_path).resolve()

    preserve = {n for n in str(raw.get("preserve") or PRESERVE_DEFAULT).split() if n}

    targets = []
    for entry in raw.get("targets") or []:
        root = entry.get("target_root")
        if not root:
            continue
        targets.append(
            Target(
                name=entry.get("name") or root,
                root=str(Path(os.path.expandvars(os.path.expanduser(str(root))))),
                link={d: _as_bool(entry.get(f"link_{d}"), default=(d != "scripts"))
                      for d in LINKABLE_DIRS},
                format=str(entry.get("format") or "link").strip().lower(),
            )
        )

    return Config(
        shared_root=root_path,
        preserve=preserve,
        backup_ext=str(raw.get("backup_ext") or ".bak"),
        backup_replaced=_as_bool(raw.get("backup_replaced"), True),
        targets=targets,
    )


# --------------------------------------------------------------------------
# Link primitives
# --------------------------------------------------------------------------

def is_link(path: Path) -> bool:
    """True for a symlink OR a Windows junction (which islink() misses on <3.12)."""
    if path.is_symlink():
        return True
    if IS_WINDOWS and path.exists():
        try:
            return bool(os.lstat(path).st_reparse_tag)  # type: ignore[attr-defined]
        except (AttributeError, OSError):
            try:
                return bool(os.readlink(path))
            except OSError:
                return False
    return False


def link_target(path: Path) -> str | None:
    try:
        return os.path.realpath(path)
    except OSError:
        return None


def make_link(source: Path, dest: Path, log) -> str:
    """Create dest -> source. Returns the strategy used.

    Windows directories use a junction: unprivileged, unlike a symlink.
    """
    if IS_WINDOWS:
        if source.is_dir():
            import _winapi
            _winapi.CreateJunction(str(source), str(dest))
            return "junction"
        try:
            os.symlink(source, dest)
            return "symlink"
        except OSError:
            try:
                os.link(source, dest)
                log.warn(f"hardlink (symlink unavailable): {dest}")
                return "hardlink"
            except OSError:
                shutil.copy2(source, dest)
                log.warn(f"COPY (no link available, will drift): {dest}")
                return "copy"

    rel = os.path.relpath(source, dest.parent)
    os.symlink(rel, dest)
    return "symlink"


def trees_differ(a: Path, b: Path) -> bool:
    """True if the two trees differ in names or file contents."""
    if a.is_file() or b.is_file():
        return not (a.is_file() and b.is_file() and filecmp.cmp(a, b, shallow=False))

    cmp = filecmp.dircmp(str(a), str(b))

    def walk(node) -> bool:
        if node.left_only or node.right_only or node.funny_files:
            return True
        _, mismatch, errors = filecmp.cmpfiles(
            node.left, node.right, node.common_files, shallow=False
        )
        if mismatch or errors:
            return True
        return any(walk(sub) for sub in node.subdirs.values())

    return walk(cmp)


# --------------------------------------------------------------------------
# Logging
# --------------------------------------------------------------------------

class Log:
    def __init__(self, verbose: bool):
        self.verbose = verbose

    def info(self, msg):  print(f"[INFO] {msg}", file=sys.stderr)
    def warn(self, msg):  print(f"[WARN] {msg}", file=sys.stderr)
    def error(self, msg): print(f"[ERROR] {msg}", file=sys.stderr)
    def debug(self, msg):
        if self.verbose:
            print(f"[DEBUG] {msg}", file=sys.stderr)


# --------------------------------------------------------------------------
# Core
# --------------------------------------------------------------------------

class Stats:
    def __init__(self):
        self.linked = 0
        self.already = 0
        self.drifted = []      # (dest, source) real dirs whose content differs
        self.blocked = 0
        self.failed = 0
        self.generated = 0     # claude-code files written / would be written
        self.pruned = 0        # claude-code files whose source is gone


def link_entry(source: Path, dest: Path, cfg: Config, args, log: Log, stats: Stats) -> None:
    if not source.exists():
        log.error(f"Source not found: {source}")
        stats.failed += 1
        return

    # SELF-REFERENCE GUARD. A dest that resolves to the source itself is not a link target --
    # it is the source seen through a link higher in its own path. Example that motivated this:
    # ~/.agents/skills was a junction onto this repo's skills/, so ~/.agents/skills/<name> IS
    # <repo>/skills/<name>.
    #
    # trees_differ() structurally cannot catch this. The two paths compare byte-identical
    # because they are the same directory, so the drift guard sees "no drift", concludes the
    # destination is safe to replace, and the backup path then moves the SOURCE aside --
    # destroying every skill in the repo before failing to link anything. The guard asks
    # whether dest DIFFERS from source; it never asked whether dest IS source.
    try:
        self_referential = os.path.realpath(dest) == os.path.realpath(source)
    except OSError:
        self_referential = False
    if self_referential:
        log.error(f"Destination resolves to the source itself -- refusing: {dest}")
        log.error(f"  -> {os.path.realpath(source)}")
        log.error("  Something in the destination's parent path already links to the shared "
                  "root. That target is already served by a whole-directory link and must not "
                  "also be given per-item links.")
        stats.failed += 1
        return

    dest.parent.mkdir(parents=True, exist_ok=True)

    if is_link(dest):
        if link_target(dest) == os.path.realpath(source):
            log.debug(f"Already linked: {dest}")
            stats.already += 1
            return
        log.info(f"Replacing stale link: {dest}")
        if not args.dry_run:
            dest.unlink()

    elif dest.exists():
        # A REAL file/dir sits here. This is where content gets destroyed.
        differs = trees_differ(dest, source)
        if differs and not (args.force or args.backup):
            log.warn(f"DRIFT -- refusing to replace real path: {dest}")
            stats.drifted.append((dest, source))
            stats.blocked += 1
            return
        if args.backup or cfg.backup_replaced:
            backup = dest.with_name(dest.name + cfg.backup_ext)
            log.info(f"Backing up: {dest} -> {backup}")
            if not args.dry_run:
                if backup.exists():
                    shutil.rmtree(backup) if backup.is_dir() else backup.unlink()
                shutil.move(str(dest), str(backup))
        else:
            log.info(f"Removing (forced): {dest}")
            if not args.dry_run:
                shutil.rmtree(dest) if dest.is_dir() else dest.unlink()

    if args.dry_run:
        log.info(f"Would link: {dest} -> {source}")
        stats.linked += 1
        return

    try:
        how = make_link(source, dest, log)
        log.info(f"Linked ({how}): {dest} -> {source}")
        stats.linked += 1
    except OSError as exc:
        log.error(f"Failed to link {dest}: {exc}")
        stats.failed += 1


def link_dir_contents(src_dir: Path, tgt_dir: Path, cfg: Config, args, log: Log, stats: Stats) -> None:
    if not src_dir.is_dir():
        log.warn(f"Skipping (no source dir): {src_dir}")
        return
    for entry in sorted(src_dir.iterdir()):
        if entry.name in cfg.preserve:
            log.debug(f"Preserving (skip): {entry.name}")
            continue
        link_entry(entry, tgt_dir / entry.name, cfg, args, log, stats)


# --------------------------------------------------------------------------
# Claude Code conversion (format: "claude-code")
#
# A generated file carries GENERATED_MARK. Only a marked file is ever
# overwritten or pruned; an unmarked file at a destination is someone's
# hand-written agent/command and gets the same drift protection as a real
# directory in link mode (--backup / --force to replace it).
# --------------------------------------------------------------------------

GENERATED_MARK = "# generated-by: vs-code-agents scripts/link_setup.py (claude-code target)"

_SHELL = ("Bash", "PowerShell")

# VS Code tool (or tool set) -> Claude Code tools. A "set/tool" entry missing
# here falls back to its set's mapping, with a warning so the table gets updated.
VSCODE_TO_CLAUDE_TOOLS = {
    "execute": _SHELL,
    "execute/getTerminalOutput": _SHELL,
    "execute/runInTerminal": _SHELL,
    "execute/runTask": _SHELL,
    "execute/getTaskOutput": _SHELL,
    "execute/createAndRunTask": _SHELL,
    "execute/runNotebookCell": _SHELL,
    "read": ("Read", "LSP"),
    "read/readFile": ("Read",),
    "read/problems": ("LSP",),
    "read/terminalSelection": (),
    "read/terminalLastCommand": (),
    "edit": ("Edit", "Write", "NotebookEdit"),
    "edit/editFiles": ("Edit",),
    "edit/createFile": ("Write",),
    "edit/createDirectory": ("Write",),     # Write creates missing parent directories
    "edit/rename": _SHELL,
    "search": ("Glob", "Grep", "LSP"),
    "search/codebase": ("Glob", "Grep"),
    "search/fileSearch": ("Glob",),
    "search/listDirectory": ("Glob",),
    "search/textSearch": ("Grep",),
    "search/usages": ("LSP",),
    "web": ("WebFetch", "WebSearch"),
    "web/fetch": ("WebFetch",),
    "todo": ("TaskCreate", "TaskGet", "TaskList", "TaskUpdate", "TodoWrite"),
    "agent": ("Agent",),
    "vscode": ("AskUserQuestion",),         # the set's askQuestions tool; the rest has no equivalent
    "vscode/askQuestions": ("AskUserQuestion",),
    "vscode/vscodeAPI": (),
}

# Added to every converted tool list: the agents load skills by name, and an
# explicit `tools` allowlist would otherwise withhold the Skill tool (and
# ToolSearch, which loads deferred tools such as WebFetch).
ALWAYS_TOOLS = ("Skill", "ToolSearch")

# Repo-relative references to repo-owned assets. Rewritten to absolute paths only
# when the path exists under shared_root, so prose like "agents/prompts" and
# workspace paths like `.agent-output/...` are left alone.
_REPO_PATH = re.compile(r"(?<![\w./\\-])(?:\.\.?/)?((?:scripts|agents|templates|skills)/[\w.*/-]*[\w*])")


def _parse_frontmatter_fallback(head: str) -> dict:
    """Minimal reader for agent/prompt frontmatter: scalars, flow lists, block scalars."""
    fields: dict = {}
    key, block = None, None
    for line in head.split("\n"):
        if block is not None:
            if line.startswith((" ", "\t")) or not line.strip():
                block.append(line.strip())
                continue
            fields[key], block = " ".join(p for p in block if p), None
        if line.startswith((" ", "\t", "#")) or ":" not in line:
            continue
        key, value = (s.strip() for s in line.split(":", 1))
        if value in (">", ">-", ">+", "|", "|-", "|+"):
            block = []
        elif value.startswith("[") and value.endswith("]"):
            fields[key] = [_strip(v) for v in value[1:-1].split(",") if v.strip()]
        else:
            fields[key] = _strip(value)
    if block is not None:
        fields[key] = " ".join(p for p in block if p)
    return fields


def split_frontmatter(text: str) -> tuple:
    """(fields, body) of a markdown file with optional '---' frontmatter."""
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    head, body = text[4:end], text[end + 4:].lstrip("\n")
    fields = _parse_with_pyyaml(head)
    if not isinstance(fields, dict):
        fields = _parse_frontmatter_fallback(head)
    return fields, body


def claude_name(name: str) -> str:
    """'Code Reviewer' -> 'code-reviewer', 'OBS-Create' -> 'obs-create'."""
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def map_tools(vscode_tools, source: Path, log: Log) -> list:
    out: list = []
    for tool in (str(t).strip() for t in vscode_tools):
        if tool in VSCODE_TO_CLAUDE_TOOLS:
            mapped = VSCODE_TO_CLAUDE_TOOLS[tool]
        elif tool.split("/", 1)[0] in VSCODE_TO_CLAUDE_TOOLS:
            mapped = VSCODE_TO_CLAUDE_TOOLS[tool.split("/", 1)[0]]
            log.warn(f"{source.name}: no mapping for VS Code tool '{tool}' -- using its tool set's")
        else:
            mapped = ()
            log.warn(f"{source.name}: unknown VS Code tool '{tool}' -- dropped")
        out += [t for t in mapped if t not in out]
    return out + [t for t in ALWAYS_TOOLS if t not in out]


def absolutize_repo_paths(body: str, shared_root: Path) -> str:
    def replace(m: re.Match) -> str:
        rel = m.group(1)
        probe = shared_root / (rel.split("*", 1)[0].rsplit("/", 1)[0] if "*" in rel else rel)
        return f"{shared_root.as_posix()}/{rel}" if probe.exists() else m.group(0)
    return _REPO_PATH.sub(replace, body)


def _yaml_str(value: str) -> str:
    return json.dumps(" ".join(str(value).split()), ensure_ascii=False)


def convert_agent(source: Path, cfg: Config, rerun: str, log: Log) -> tuple:
    fields, body = split_frontmatter(source.read_text(encoding="utf-8"))
    name = claude_name(str(fields.get("name") or source.name.split(".", 1)[0]))
    description = str(fields.get("description") or name)
    if fields.get("argument-hint"):
        description += f" Input: {fields['argument-hint']}"
    lines = ["---", GENERATED_MARK, rerun, f"name: {name}", f"description: {_yaml_str(description)}"]
    if fields.get("tools"):
        lines.append("tools: " + ", ".join(map_tools(fields["tools"], source, log)))
    if fields.get("model"):
        lines.append(f"model: {fields['model']}")
    lines.append("---")
    return name, "\n".join(lines) + "\n" + absolutize_repo_paths(body, cfg.shared_root)


def convert_prompt(source: Path, cfg: Config, rerun: str, log: Log) -> tuple:
    fields, body = split_frontmatter(source.read_text(encoding="utf-8"))
    name = claude_name(str(fields.get("name") or source.name.split(".", 1)[0]))
    lines = ["---", GENERATED_MARK, rerun]
    if fields.get("description"):
        lines.append(f"description: {_yaml_str(fields['description'])}")
    if fields.get("argument-hint"):
        lines.append(f"argument-hint: {_yaml_str(fields['argument-hint'])}")
    lines.append("---")
    body = absolutize_repo_paths(body, cfg.shared_root)
    # Claude Code substitutes $ARGUMENTS / $0..$N in command bodies; keep any literal ones literal.
    body = re.sub(r"(?<!\\)\$(?=\d|ARGUMENTS)", r"\\$", body)
    return name, "\n".join(lines) + "\n" + body


def write_generated(dest: Path, content: str, source: Path, cfg: Config, args, log: Log,
                    stats: Stats) -> None:
    if dest.exists():
        current = dest.read_text(encoding="utf-8")
        if current == content:
            log.debug(f"Already current: {dest}")
            stats.already += 1
            return
        if GENERATED_MARK not in current:
            if not (args.force or args.backup):
                log.warn(f"DRIFT -- refusing to replace hand-written file: {dest}")
                stats.drifted.append((dest, source))
                stats.blocked += 1
                return
            if args.backup or cfg.backup_replaced:
                backup = dest.with_name(dest.name + cfg.backup_ext)
                log.info(f"Backing up: {dest} -> {backup}")
                if not args.dry_run:
                    if backup.exists():
                        backup.unlink()
                    shutil.move(str(dest), str(backup))
    if args.dry_run:
        log.info(f"Would generate: {dest} <= {source}")
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8", newline="\n")
        log.info(f"Generated: {dest} <= {source}")
    stats.generated += 1


def convert_claude_code(target: Target, cfg: Config, args, log: Log, stats: Stats) -> None:
    root = Path(target.root)
    skills = root / "skills"
    if not (is_link(skills) and link_target(skills) == os.path.realpath(cfg.shared_root / "skills")):
        log.warn(f"{skills} is not a whole-directory link to {cfg.shared_root / 'skills'} -- "
                 "skills are not converted; create that link by hand (see LINKING.md)")

    rerun = f"# edit the source in {cfg.shared_root.as_posix()}, then re-run: " \
            f"python {Path(__file__).resolve().as_posix()} --target {target.name}"
    jobs = []
    if target.link.get("agents"):
        jobs.append((cfg.shared_root / "agents", "*.agent.md", root / "agents", convert_agent))
    if target.link.get("prompts"):
        jobs.append((cfg.shared_root / "prompts", "*.prompt.md", root / "commands", convert_prompt))

    for src_dir, pattern, out_dir, convert in jobs:
        produced: dict = {}
        for source in sorted(src_dir.glob(pattern)):
            try:
                name, content = convert(source, cfg, rerun, log)
            except (OSError, UnicodeDecodeError) as exc:
                log.error(f"Failed to convert {source}: {exc}")
                stats.failed += 1
                continue
            if name in produced:
                log.error(f"{source.name} and {produced[name].name} both convert to '{name}' -- skipped")
                stats.failed += 1
                continue
            produced[name] = source
            write_generated(out_dir / f"{name}.md", content, source, cfg, args, log, stats)

        # Prune generated files whose source was removed or renamed.
        for stale in sorted(out_dir.glob("*.md")) if out_dir.is_dir() else []:
            if stale.stem in produced:
                continue
            if GENERATED_MARK not in stale.read_text(encoding="utf-8", errors="replace"):
                continue
            log.info(f"{'Would remove' if args.dry_run else 'Removing'} orphaned generated file: {stale}")
            if not args.dry_run:
                stale.unlink()
            stats.pruned += 1


def run(cfg: Config, args, log: Log) -> int:
    stats = Stats()
    log.info(f"Shared root: {cfg.shared_root}")
    log.info(f"Platform: {platform.system()} "
             f"({'junction' if IS_WINDOWS else 'symlink'} strategy for directories)")

    selected = [t for t in cfg.targets if not args.target or t.name == args.target]
    if args.target and not selected:
        log.error(f"No target named '{args.target}'. Known: "
                  f"{', '.join(t.name for t in cfg.targets) or '(none)'}")
        return 1

    for target in selected:
        root = Path(target.root)
        # Skip a target belonging to another machine rather than manufacturing its
        # tree here. Without this, a Linux target_root creates C:\home\... on Windows.
        if not root.parent.exists():
            log.warn(f"Skipping target '{target.name}': parent does not exist ({root.parent})")
            continue

        log.info(f"Processing target: {target.name} -> {target.root}")
        if target.format == "claude-code":
            convert_claude_code(target, cfg, args, log, stats)
            continue
        if target.format != "link":
            log.error(f"Target '{target.name}': unknown format '{target.format}' "
                      "(expected 'link' or 'claude-code')")
            stats.failed += 1
            continue
        for kind in LINKABLE_DIRS:
            if target.link.get(kind):
                link_dir_contents(cfg.shared_root / kind, root / kind,
                                  cfg, args, log, stats)

    print()
    print(f"linked/would-link : {stats.linked}")
    print(f"generated/would   : {stats.generated}")
    print(f"pruned/would      : {stats.pruned}")
    print(f"already correct   : {stats.already}")
    print(f"blocked by drift  : {stats.blocked}")
    print(f"failed            : {stats.failed}")

    if stats.drifted:
        print()
        print("DRIFT -- these targets are real paths whose content differs from the repo.")
        print("Nothing was changed for them. Reconcile first, or re-run with --backup.")
        for dest, source in stats.drifted:
            print(f"  {dest}")
            print(f"    vs {source}")

    if args.dry_run:
        print("\n[DRY-RUN -- no changes made]")

    if args.check:
        return 1 if (stats.drifted or stats.failed) else 0
    return 1 if stats.failed else 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Link shared skills/agents/prompts/scripts into consuming workspaces."
    )
    parser.add_argument("--config", default=None, help="path to link-config.yaml")
    parser.add_argument("--dry-run", action="store_true", help="show actions, change nothing")
    parser.add_argument("--check", action="store_true",
                        help="report drift and exit non-zero if any (implies --dry-run)")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--backup", action="store_true",
                        help="move a drifted real path aside instead of refusing")
    parser.add_argument("--force", action="store_true",
                        help="replace a drifted real path (honours backup_replaced)")
    parser.add_argument("--target", default=None, help="only process this target name")
    args = parser.parse_args(argv)

    if args.check:
        args.dry_run = True

    log = Log(args.verbose)

    config_path = Path(args.config) if args.config else Path(__file__).parent / "link-config.yaml"
    if not config_path.is_file():
        log.error(f"Config file not found: {config_path}")
        return 1
    log.info(f"Using config: {config_path}")

    return run(load_config(config_path), args, log)


if __name__ == "__main__":
    sys.exit(main())
