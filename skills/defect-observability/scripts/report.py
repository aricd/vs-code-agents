#!/usr/bin/env python3
"""reports module (rung 3): render artifacts into an actionability report.

Degrades gracefully: renders from whatever sensors exist, states what's missing.
Spec: references/reports.md
"""
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import obs_common as oc


def pct_rank(values, v):
    if not values:
        return 0.0
    return round(100.0 * sum(1 for x in values if x <= v) / len(values), 1)


def main():
    root = oc.repo_root()
    cfg = oc.load_config(root)
    top_k = int(cfg["modules"].get("reports", {}).get("top_k", 20))
    snaps = oc.read_jsonl(oc.artifact_path(root, cfg, "snapshots.jsonl"))
    churn = oc.read_jsonl(oc.artifact_path(root, cfg, "churn.jsonl"))
    errors = oc.read_jsonl(oc.artifact_path(root, cfg, "errors.jsonl"))
    muts = oc.read_jsonl(oc.artifact_path(root, cfg, "mutation.jsonl"))

    latest = {}
    for r in snaps:
        if r["file"] not in latest or r["ts"] > latest[r["file"]]["ts"]:
            latest[r["file"]] = r
    cutoff = (datetime.now(timezone.utc) - timedelta(days=90)).strftime("%Y-%m-%dT%H:%M:%SZ")
    churn90 = defaultdict(int)
    for r in churn:
        if r["ts"] >= cutoff and r.get("commit_type") not in ("style",):
            churn90[r["file"]] += (r.get("added") or 0) + (r.get("deleted") or 0)
    err_fps = defaultdict(set)
    for r in errors:
        err_fps[r["file"]].add(r["fingerprint"])
    kill = {r["file"]: r for r in sorted(muts, key=lambda x: x["ts"])}

    rows = []
    files = set(latest) | set(churn90)
    ccs = [latest[f]["metrics"].get("cc_sum", 0) for f in latest]
    chs = list(churn90.values()) or [0]
    for f in files:
        cc = latest.get(f, {}).get("metrics", {}).get("cc_sum")
        sloc = latest.get(f, {}).get("metrics", {}).get("sloc", 0)
        ch = churn90.get(f, 0)
        basis = cc if cc is not None else sloc
        score = (basis or 0) * max(ch, 1)
        driver = "complexity" if cc and pct_rank(ccs, cc) >= 90 else \
                 "churn" if pct_rank(chs, ch) >= 90 else \
                 "runtime failures" if err_fps.get(f) else "size"
        action = "no action — stable legacy" if ch == 0 else \
                 "add tests" if (kill.get(f, {}).get("kill_rate", 1) < 0.6 or err_fps.get(f)) else \
                 "split / simplify" if driver == "complexity" else "watch"
        rows.append((score, f, cc, sloc, ch, driver, action))
    rows.sort(reverse=True)

    L = ["# Code Health Report", f"Generated {oc.now_iso()} at {oc.head_sha(root)[:8]}", ""]
    L += [f"## Top {top_k} risk files", "",
          "| # | file | cc_sum | sloc | churn 90d | dominant driver | implied action |",
          "|---|------|--------|------|-----------|-----------------|----------------|"]
    for i, (s, f, cc, sloc, ch, driver, action) in enumerate(rows[:top_k], 1):
        L.append(f"| {i} | {f} | {cc if cc is not None else '—'} | {sloc} | {ch} | {driver} | {action} |")
    if err_fps:
        L += ["", "## Runtime failures", ""]
        for f, fps in sorted(err_fps.items(), key=lambda kv: -len(kv[1]))[:10]:
            L.append(f"- {f}: {len(fps)} distinct fingerprints")
    if kill:
        L += ["", "## Unverified complexity (mutation)", ""]
        for f, r in sorted(kill.items(), key=lambda kv: kv[1].get("kill_rate", 1))[:10]:
            L.append(f"- {f}: kill rate {r.get('kill_rate')}")
    L += ["", "## Data Coverage", ""]
    for name, data, unit in (("snapshots", snaps, "records"), ("churn", churn, "records"),
                             ("runtime_attr", errors, "events"), ("mutation", muts, "records")):
        state = oc.module_state(cfg, name if name != "runtime_attr" else "runtime_attr")
        note = f"{len(data)} {unit}" if data else "NO DATA"
        L.append(f"- {name} [{state}]: {note}")
    if not churn:
        L.append("- WARNING: no churn data — ranking falls back to size only")
    path = oc.artifact_path(root, cfg, "report.md")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"report: {len(rows)} files ranked -> {path}")


if __name__ == "__main__":
    main()
