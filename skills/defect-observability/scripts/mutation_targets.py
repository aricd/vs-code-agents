#!/usr/bin/env python3
"""mutation module (rung 6): target top-K hotspot files; run mutmut if available.

Never repo-wide, never in the inner loop. Spec: references/mutation.md
"""
import shutil
import subprocess
import sys

import obs_common as oc


def targets(root, cfg, k):
    snaps = oc.read_jsonl(oc.artifact_path(root, cfg, "snapshots.jsonl"))
    churn = oc.read_jsonl(oc.artifact_path(root, cfg, "churn.jsonl"))
    latest = {}
    for r in snaps:
        if r["file"] not in latest or r["ts"] > latest[r["file"]]["ts"]:
            latest[r["file"]] = r
    ch = {}
    for r in churn:
        ch[r["file"]] = ch.get(r["file"], 0) + (r.get("added") or 0) + (r.get("deleted") or 0)
    scored = sorted(latest, key=lambda f: -(latest[f]["metrics"].get("cc_sum", 0) * max(ch.get(f, 0), 1)))
    return scored[:k]


def main():
    root = oc.repo_root()
    cfg = oc.load_config(root)
    if oc.module_state(cfg, "mutation") == "disabled":
        sys.exit("mutation module is disabled in .observability.yml")
    k = int(cfg["modules"].get("mutation", {}).get("top_k", 10))
    files = targets(root, cfg, k)
    if not files:
        sys.exit("no snapshot data to rank targets — install rung 1 first")
    print("targets:", *files, sep="\n  ")
    if shutil.which("mutmut") is None:
        print("mutmut not installed — emitted target list only (records not appended)")
        return
    sha, ts, records = oc.head_sha(root), oc.now_iso(), []
    for f in files:
        subprocess.run(["mutmut", "run", "--paths-to-mutate", f], cwd=root,
                       capture_output=True, text=True)
        res = subprocess.run(["mutmut", "results"], cwd=root, capture_output=True, text=True).stdout
        killed = res.count("killed") or sum(1 for l in res.splitlines() if "killed" in l)
        survived = res.count("survived")
        total = killed + survived
        records.append({"ts": ts, "sha": sha, "file": f, "mutants": total,
                        "killed": killed, "survived": survived,
                        "kill_rate": round(killed / total, 3) if total else None,
                        "tool": "mutmut"})
    oc.append_jsonl(oc.artifact_path(root, cfg, "mutation.jsonl"), records)
    print(f"mutation: {len(records)} file records appended")


if __name__ == "__main__":
    main()
