#!/usr/bin/env python3
"""snapshots module (rung 1): append per-file metric records at merge cadence.

Uses radon when importable. Repos with their own collector (e.g. crest_metrics.py)
should adapt that collector to emit the same record shape instead.
Spec: references/snapshots.md
"""
import subprocess
import sys

import obs_common as oc


def python_files(root):
    out = subprocess.run(["git", "-C", root, "ls-files", "*.py"],
                         capture_output=True, text=True).stdout.splitlines()
    return [f for f in out if not f.startswith((".observability/",))]


def metrics_for(root, relpath):
    try:
        from radon.complexity import cc_visit
        from radon.metrics import mi_visit
        from radon.raw import analyze
    except ImportError:
        sys.exit("radon not installed (pip install radon) and no custom collector wired")
    src = open(f"{root}/{relpath}", encoding="utf-8", errors="replace").read()
    try:
        blocks = cc_visit(src)
        raw = analyze(src)
        return {
            "cc_sum": sum(b.complexity for b in blocks),
            "cc_max": max((b.complexity for b in blocks), default=0),
            "sloc": raw.sloc,
            "lloc": raw.lloc,
            "comments": raw.comments,
            "mi": round(mi_visit(src, multi=True), 1),
        }
    except SyntaxError:
        return None


def main():
    root = oc.repo_root()
    cfg = oc.load_config(root)
    if oc.module_state(cfg, "snapshots") == "disabled":
        sys.exit("snapshots module is disabled in .observability.yml")
    sha, ts = oc.head_sha(root), oc.now_iso()
    records = []
    for f in python_files(root):
        m = metrics_for(root, f)
        if m is not None:
            records.append({"ts": ts, "sha": sha, "file": f, "metrics": m})
    path = oc.artifact_path(root, cfg, "snapshots.jsonl")
    oc.append_jsonl(path, records)
    print(f"snapshot: {len(records)} file records appended at {sha[:8]} -> {path}")


if __name__ == "__main__":
    main()
