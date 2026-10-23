#!/usr/bin/env python3
"""labels module (rung 7): derive audited per-file outcome labels from evidence.

Pure consumer. Every label carries an evidence pointer. Spec: references/labels.md
"""
import re
import subprocess
import sys
from datetime import datetime, timedelta

import obs_common as oc

FIX_RE = re.compile(r"^fix[(!:]")
ORIGIN_RE = re.compile(r"^Defect-Origin:\s*([0-9a-f]{7,40})", re.M | re.I)


def commit_stream(root):
    fmt = "%x1e%H%x00%cI%x00%s%x00%b"
    out = subprocess.run(["git", "-C", root, "log", f"--format={fmt}", "--name-only"],
                         capture_output=True, text=True).stdout
    for chunk in out.split("\x1e"):
        if not chunk.strip():
            continue
        head, _, files = chunk.partition("\n\n")
        parts = head.split("\x00")
        sha, ts, subject = parts[0].strip(), parts[1], parts[2]
        body = parts[3] if len(parts) > 3 else ""
        flist = [f for f in files.strip().splitlines() if f.strip()]
        yield {"sha": sha, "ts": ts, "subject": subject, "body": body, "files": flist}


def main():
    root = oc.repo_root()
    cfg = oc.load_config(root)
    if oc.module_state(cfg, "labels") == "disabled":
        sys.exit("labels module is disabled in .observability.yml")
    windows = [int(w) for w in cfg["modules"].get("labels", {}).get("windows", [90])]
    art_dir = str(cfg["artifacts_dir"])
    commits = list(commit_stream(root))

    evidence = []  # (ts, file, evidence_type, evidence_id)
    for c in commits:
        src = [f for f in c["files"] if not f.startswith(art_dir + "/")]
        m = ORIGIN_RE.search(c["body"])
        if m:
            for f in src:
                evidence.append((c["ts"], f, "defect_origin_trailer", c["sha"]))
        if FIX_RE.match(c["subject"]) and 0 < len([f for f in src if not f.startswith(("test", "docs"))]) <= 5:
            for f in src:
                evidence.append((c["ts"], f, "fix_commit_scoped", c["sha"]))
    for r in oc.read_jsonl(oc.artifact_path(root, cfg, "errors.jsonl")):
        evidence.append((r["ts"], r["file"], "runtime_fingerprint", r["fingerprint"]))

    snaps = oc.read_jsonl(oc.artifact_path(root, cfg, "snapshots.jsonl"))
    points = sorted({(r["sha"], r["ts"]) for r in snaps})
    if not points:
        sys.exit("no snapshot points to label — install rung 1 first")
    files = sorted({r["file"] for r in snaps})

    records = []
    for sha, ts in points:
        t0 = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        for w in windows:
            t1 = (t0 + timedelta(days=w)).isoformat()
            for f in files:
                hits = [e for e in evidence if e[1] == f and ts < e[0] <= t1]
                rec = {"as_of_sha": sha, "as_of_ts": ts, "file": f,
                       "label": f"bugfix_{w}d", "window_days": w, "value": bool(hits)}
                if hits:
                    rec["evidence_type"], rec["evidence_id"] = hits[0][2], hits[0][3]
                records.append(rec)
    path = oc.artifact_path(root, cfg, "labels.jsonl")
    open(path, "w").close()  # deterministic regeneration, not append
    oc.append_jsonl(path, records)
    pos = sum(1 for r in records if r["value"])
    print(f"labels: {len(records)} rows ({pos} positive) from {len(evidence)} evidence items -> {path}")


if __name__ == "__main__":
    main()
