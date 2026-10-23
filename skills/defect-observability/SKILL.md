---
name: defect-observability
description: Install and maintain low-burden, opt-in defect observability in a repository — CI sensor pipelines, metric snapshots, churn collection, runtime error attribution, mutation testing, and outcome-label derivation, governed by a .observability.yml settings file. ALWAYS apply this skill when the user asks to set up CI with metrics, add code-health or defect observability, instrument error/defect attribution, generate hotspot or code-health reports, add mutation testing, derive defect labels, or mentions .observability.yml — AND whenever editing any repository that contains a .observability.yml file, even if the task seems unrelated, because load-bearing sensors must survive the change. Language-independent specs with a Python reference implementation.
metadata:
  version: "1.0"
---

# Defect Observability

Most repos cannot answer "which files keep breaking?" because nobody was recording when it
mattered. A defect-prediction probe on a real 5-month-old repo found: no CI (every merge a
permanently lost row of test data), 4 metric snapshots all from the same month (no trend),
bug labels at ~50% precision, and too few clean outcomes to train anything. None of that is
recoverable after the fact. This skill exists to start the recorders **now**, cheaply, so
that in a year the repo has a dataset instead of regrets.

**The contract:** sensors in, append-only local artifacts out.

- `.observability.yml` at the repo root declares which sensor modules exist and how much
  weight each carries. Its presence is what puts this skill in maintenance mode.
- `.observability/` holds the artifacts — plain append-only JSONL, one file per sensor.
  No server, no database, no third-party service. Greppable, diffable, language-neutral.
- Everything downstream (reports today, predictive models later) is a *consumer* of the
  artifacts, never a sensor. Model training is explicitly out of scope here.

## Module registry — the adoption ladder

Seven modules, ordered cheapest-first. Each is independently opt-in; the order is a default
recommendation, not a dependency chain (real dependencies are noted).

| Rung | Module | Emits | Install cost | Depends on |
|---|---|---|---|---|
| 1 | `snapshots` | per-file metric records per merge | 1 script + 1 hook | metric tool (radon or equivalent) |
| 2 | `churn` | per-commit per-file line deltas | 1 script | git history |
| 3 | `reports` | hotspot/actionability markdown | 1 script | snapshots + churn |
| 4 | `ci` | test/coverage events, artifact freshness gate | 1 workflow file | a test command |
| 5 | `runtime_attr` | runtime failures attributed to file/function | ~50 lines in the app | a failure boundary |
| 6 | `mutation` | surviving-mutant records for hotspot files | 1 script + scheduler | tests + rung 3 |
| 7 | `labels` | per-file outcome labels from all evidence | 1 script | any of: trailers / ci / runtime_attr |

Module specs live in `references/<module>.md` — **read the reference file only for the
module you are installing or repairing**, not all seven. Each spec is normative: exact
record schema, artifact path, what "broken" means, promotion criteria, portability notes.

## The settings file

```yaml
version: 1
artifacts_dir: .observability
default_branch: main
freshness_days: 35          # load-bearing artifact staler than this = broken
modules:
  snapshots:    { state: advisory, cadence: merge }
  churn:        { state: advisory }
  reports:      { state: disabled, top_k: 20 }
  ci:           { state: disabled }
  runtime_attr: { state: disabled, boundaries: [] }
  mutation:     { state: disabled, top_k: 10, cadence: monthly }
  labels:       { state: disabled, windows: [90] }
```

States are strings — `disabled | advisory | load-bearing` (never bare `off`/`on`, which
YAML coerces to booleans).

- **disabled** — module doesn't exist for this repo. Zero cost, zero mention.
- **advisory** — the sensor runs; if it's missing or stale, reports carry a warning line
  and nothing else happens. Every module **enters** at advisory.
- **load-bearing** — the repo has promoted this sensor to a commitment: `check_sensors`
  fails CI when its artifact is missing or staler than `freshness_days`.

**Promotion is the maintainer's act, never the skill's.** Suggest promotion only when a
module has run cleanly for a stated period and someone actually consumed its output. This
mirrors the requirements-enforcement maturity ladder: sensors get promoted the way
guarantees get ratified. Demotion back to advisory is always acceptable and never shameful
— an honest advisory sensor beats a lying load-bearing one.

## Two mandates

**Setup mode** — "add observability", "set up CI with metrics", "instrument error
attribution": read `.observability.yml` (create it from `assets/observability.yml` if
absent), find the lowest worthwhile disabled rung (or the rung the user named), and install
**that one module only**: read its reference file, implement the sensor from the spec (use
`scripts/` as the reference implementation for Python; translate the spec, not the code,
for other languages), run it once, and verify a record actually lands in the artifact
before declaring success. One rung per session — a sensor that has never been observed
emitting is not installed, it's decoration. Never enable a module at load-bearing.

**Maintenance mode** — any edit to a repo containing `.observability.yml`: before
finishing, check whether the change breaks a non-disabled sensor (removed a CI step,
bypassed a declared failure boundary, renamed an artifact path, added a handler outside the
`runtime_attr` wrapper). For **load-bearing** modules, fix it as part of the change and say
so in one sentence — same tone as splitting a mega-commit: not silent compliance, not a
lecture. For **advisory** modules, a one-line note is enough. Adding a new failure-boundary
handler in a repo with `runtime_attr` enabled? Wrap it — that is part of writing the
handler, not an extra favor.

## Burden rules — why maintainers tolerate this

1. Rung 1 costs one file and one hook. Nothing ever blocks anyone until *they* promote a
   module to load-bearing.
2. Reports degrade gracefully: render from whatever sensors exist, and state what's
   missing in a Data Coverage section rather than refusing or guessing.
3. Artifacts are boring files in the repo. Deleting `.observability/` and the YAML is a
   complete, clean uninstall.
4. Sensor code never changes program behavior: recorders swallow their own errors
   (a broken sensor must never break the app), and mutation runs happen on schedules, not
   in anyone's inner loop.

## Delegation boundaries

- **Commit hygiene** (types, trailers, `Defect-Origin:`, splitting) → the
  `git-commit-message` skill. The `labels` module *consumes* that history; it never
  restates the rules.
- **Metric semantics** (what CC/PLR/LL mean, thresholds, purity) → `functional-core` /
  `deep-modules`. The `snapshots` module records whatever the repo's metric tool emits;
  it does not define metrics.
- **Escape attribution and the guarantee ledger** → `requirements-enforcement`. A
  `runtime_attr` event is evidence an escape occurred; offer it to the ledger, don't
  duplicate the ledger.
- **Build sequencing** for the observability work itself → tracer-bullets: the one-rung
  rule above is that skill's discipline applied here.

## Reference implementation

`scripts/` contains the Python implementation of every module spec: `snapshot.py`,
`churn.py`, `report.py`, `record_failure.py` (importable, with `@observe_boundary`),
`mutation_targets.py`, `derive_labels.py`, and `check_sensors.py` (the load-bearing gate;
CI calls this). `assets/observability.yml` is the config template;
`assets/ci-workflow.yml` is a GitHub Actions starting point. For non-Python repos or
non-GitHub CI, implement from the reference file's schema and Broken-means sections —
record shapes and artifact paths are the portable contract; the code is not.
