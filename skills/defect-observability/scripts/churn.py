#!/usr/bin/env python3
"""churn module (rung 2): append per-commit per-file line deltas, idempotently.

Language-independent (pure git). Spec: references/churn.md
"""
import os
import re
import subprocess
import sys

import obs_common as oc

TYPE_RE = re.compile(r"^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)[(!:]")


def main():
    root = oc.repo_root()
    cfg = oc.load_config(root)
    if oc.module_state(cfg, "churn") == "disabled":
        sys.exit("churn module is disabled in .observability.yml")
    art_dir = str(cfg["artifacts_dir"])
    state_path = oc.artifact_path(root, cfg, "churn.state")
    last = open(state_path).read().strip() if os.path.exists(state_path) else None
    rev_range = f"{last}..HEAD" if last else "HEAD"

    fmt = "%x1e%H%x00%cI%x00%s"
    out = subprocess.run(
        ["git", "-C", root, "log", "--numstat", "--no-renames" if False else "-M",
         f"--format={fmt}", "--reverse", rev_range],
        capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"git log failed: {out.stderr.strip()}")

    records, newest = [], last
    for chunk in out.stdout.split("\x1e"):
        if not chunk.strip():
            continue
        header, _, body = chunk.partition("\n")
        sha, ts, subject = (header.split("\x00") + ["", ""])[:3]
        newest = sha
        m = TYPE_RE.match(subject)
        ctype = m.group(1) if m else None
        for line in body.splitlines():
            parts = line.split("\t")
            if len(parts) != 3:
                continue
            added, deleted, path = parts
            renamed_from = None
            if "=>" in path:
                renamed_from, path = _split_rename(path)
            if path.startswith(art_dir + "/"):
                continue
            records.append({
                "sha": sha, "ts": ts, "file": path,
                "added": None if added == "-" else int(added),
                "deleted": None if deleted == "-" else int(deleted),
                "renamed_from": renamed_from, "commit_type": ctype,
            })
    oc.append_jsonl(oc.artifact_path(root, cfg, "churn.jsonl"), records)
    if newest:
        open(state_path, "w").write(newest + "\n")
    print(f"churn: {len(records)} records appended ({rev_range})")


def _split_rename(path):
    if "{" in path:  # a/{old => new}/b.py
        pre, rest = path.split("{", 1)
        inner, post = rest.split("}", 1)
        old, _, new = inner.partition(" => ")
        return (pre + old + post).replace("//", "/"), (pre + new + post).replace("//", "/")
    old, _, new = path.partition(" => ")
    return old, new


if __name__ == "__main__":
    main()
