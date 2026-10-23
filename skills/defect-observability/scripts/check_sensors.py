#!/usr/bin/env python3
"""The load-bearing gate. CI calls this; exit 1 iff a load-bearing sensor is broken.

Advisory sensors produce warnings only. Spec: SKILL.md + references/ci.md
"""
import os
import sys
from datetime import datetime, timedelta, timezone

import obs_common as oc

ARTIFACTS = {
    "snapshots": "snapshots.jsonl",
    "churn": "churn.jsonl",
    "ci": "ci_events.jsonl",
    "mutation": "mutation.jsonl",
    "reports": "report.md",
}


def last_ts(path):
    recs = oc.read_jsonl(path)
    return max((r.get("ts", "") for r in recs), default=None) if recs else None


def main():
    root = oc.repo_root()
    cfg = oc.load_config(root)
    fresh = timedelta(days=int(cfg["freshness_days"]))
    now = datetime.now(timezone.utc)
    failures, warnings = [], []

    for name, mod in cfg["modules"].items():
        state = str(mod.get("state", "disabled"))
        if state == "disabled":
            continue
        problem = None
        if name == "runtime_attr":
            missing = []
            for b in mod.get("boundaries", []) or []:
                hits = os.popen(
                    f"git -C {root} grep -l 'observe_boundary(\"{b}\")\\|boundary=\"{b}\"' -- '*.py' '*.js' '*.ts' '*.go' 2>/dev/null"
                ).read().strip()
                if not hits:
                    missing.append(b)
            if missing:
                problem = f"declared boundaries not wired: {missing}"
        elif name == "labels":
            pass  # not staleness-checked (windows must close first)
        else:
            path = oc.artifact_path(root, cfg, ARTIFACTS[name])
            if name == "reports":
                if not os.path.exists(path):
                    problem = "report.md missing"
                elif datetime.fromtimestamp(os.path.getmtime(path), timezone.utc) < now - fresh:
                    problem = "report.md stale"
            else:
                ts = last_ts(path)
                if ts is None:
                    problem = f"{ARTIFACTS[name]} missing or empty"
                elif name != "mutation" and datetime.fromisoformat(ts.replace("Z", "+00:00")) < now - fresh:
                    problem = f"last record {ts} older than freshness_days={cfg['freshness_days']}"
        if problem:
            (failures if state == "load-bearing" else warnings).append(f"{name}: {problem}")

    for w in warnings:
        print(f"WARNING (advisory): {w}")
    for f in failures:
        print(f"FAILURE (load-bearing): {f}")
    if failures:
        sys.exit(1)
    print(f"check_sensors: OK ({len(warnings)} advisory warnings)")


if __name__ == "__main__":
    main()
