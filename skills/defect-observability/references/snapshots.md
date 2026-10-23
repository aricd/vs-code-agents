# Module: snapshots (rung 1)

**Purpose.** Point-in-time per-file metrics become trend data only if captured at a
consistent cadence tied to commit SHAs. This sensor appends one record per source file at
every merge to the default branch.

**Artifact.** `{artifacts_dir}/snapshots.jsonl`, append-only. One record per file per run:

```json
{"ts": "2026-07-03T14:00:00Z", "sha": "3bc3de78", "file": "src/pkg/mod.py",
 "metrics": {"cc_sum": 31, "cc_max": 12, "sloc": 240, "lloc": 180, "mi": 61.2}}
```

Rules: `metrics` keys are whatever the repo's metric tool emits — semantics are the metric
tool's business (functional-core / radon / eslint-complexity), not this module's. Keys must
be stable across runs; add keys freely, never repurpose one. `sha` is the exact commit
measured. Timestamps UTC ISO-8601.

**Install.** (1) Pick the metric source: an existing collector (e.g. `crest_metrics.py`)
adapted to also append this schema, or the reference `scripts/snapshot.py` (uses radon if
importable). (2) Hook it to the merge cadence: the `ci` module's workflow when present,
otherwise a `make snapshot`-style target run at plan/feature completion. (3) Run once and
verify a record landed.

**Broken means.** No record whose `ts` is within `freshness_days`, or the artifact is
missing. `check_sensors` enforces this only at load-bearing.

**Promotion criteria.** Suggest load-bearing once snapshots exist at ≥3 distinct cadence
points and something (a report, a human) has read them.

**Portability.** Any language: the schema is the contract. JS/TS: complexity from
eslint/plato; Go: gocyclo; JVM: PMD/detekt. Emit the same record shape.
