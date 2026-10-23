# Module: reports (rung 3)

**Purpose.** Sensors nobody reads die. This module renders the artifacts into a short
actionability report so the data earns its keep from week one — and it is the graceful-
degradation showcase: it renders from whatever sensors exist.

**Artifact.** `{artifacts_dir}/report.md` (regenerated, not append-only — the one
exception, since inputs are the durable record).

**Required sections, in order:**

1. **Top-K risk files** — rank by hotspot score (latest `cc_sum` × churn over the largest
   configured window; SLOC × churn when complexity is absent). Columns: rank, file, the
   raw signals, **dominant driver** (named: "churn", "size", "complexity", "runtime
   failures"), and **implied action** ("add tests", "split", "no action — stable legacy").
   A ranked list without the action column is a list people learn to ignore.
2. **Movers** — files whose complexity or churn percentile rose most since the previous
   report.
3. **Runtime failures** (only if `runtime_attr` has records) — top files by distinct
   fingerprints.
4. **Unverified complexity** (only if `mutation` has records) — high complexity × low
   kill-rate.
5. **Data Coverage** — always last, always present: which sensors contributed, record
   counts, time spans, and one line per advisory sensor that is missing or stale. Never
   silently render a report from thin data.

Use repo-relative percentiles, never universal thresholds. Every claim must be
recomputable from the artifacts — no editorializing beyond the driver/action columns.

**Install.** `scripts/report.py`. Run at snapshot cadence or on demand.

**Broken means.** Report generation exits nonzero, or report older than `freshness_days`.
