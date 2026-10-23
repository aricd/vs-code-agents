# Metric Budget — schema and workflow reference

A **metric budget** is a planning-time artifact that turns code-health expectations
into a mechanical gate the Implementer iterates against and the Code Reviewer
independently re-verifies. It is consumed by `crest_metrics.py --diff-base <ref>
--budget <path>`.

## Why a diff-scoped gate (not the repo-wide ratchet)

The repo-wide ratchet (`--check crest_baseline.json`) has a known failure mode:
the **worst-offender shield**. If the repo's `cc_max` is 18, a new CC-15 function
sails through — it never moves the repo maximum. And one bad new module barely
moves repo-wide `plr_deep` in a large tree. The diff gate removes the shield by
measuring the whole tree twice (base ref vs working tree) and scoping the
judgment:

| Change type | Rule | Rationale |
|---|---|---|
| Modified `.py` files | **Ratchet** — no firm file-level proxy may worsen vs the same files at the base ref | Guards against erosion without forcing unplanned refactors of legacy code |
| New `.py` files | **Absolute bands** from `new_code_bands` | New code has no "before" to ratchet against |
| Graph proxies (`import_cycles`, `dead_export_count`) | Ratchet **tree-wide** | Meaningless when measured on an isolated region — a lone region makes every export look dead |

Renames are treated as modified pairs (old content vs new). Untracked files count
as new. A dirty working tree is expected — this gate is the implementer's inner
loop, not a provenance snapshot.

Exit codes: `0` = pass, `1` = firm violation, `2` = usage/precondition error.

## File location convention

```
.agent-output/metrics/<plan-id>-metric-budget.yaml
```

Authored by the **Planner** when issuing the work-order. The budget file (and the
work-order itself) MUST be listed in the work-order's `scope.blocked_files` — the
executor iterates against the budget, never edits it.

## Schema (restricted YAML — parsed stdlib-only)

Grammar limits: 2-space indentation, full-line comments only, inline `[a, b]`
lists. `parse_budget_text()` rejects anything else with a line number.

```yaml
version: 1                      # required, integer
plan: "031"                     # plan id this budget belongs to
effect_policy_version: v1       # optional pin; gate exits 2 on mismatch
                                # (detects stale budgets / swapped policies)

# Optional: remove keys from the ratchet for this work-order. Every entry
# needs a rationale in the plan. Common: dead_export_count when a phase
# deliberately ships an API ahead of its consumers.
ratchet_exempt_keys: [dead_export_count]

# Absolute bands for NEW files (firm — gate fails on breach).
# Direction-aware: "lower" metrics use <=, "higher" metrics use >=.
new_code_bands:
  cc_max: 10
  nd_max: 4
  flc_max_ll: 60
  functions_over_100ll: 0
  params_over_6_count: 0
  plr_deep: 0.5

# Reported but never gating.
advisory_bands:
  annotation_coverage: 0.9

# Per-path escape hatches (fnmatch globs; match src-relative or
# repo-relative form). 'reason' is mandatory — unjustified exemptions
# fail budget validation.
exemptions:
  - path: src/adapters/*_shell.py
    keys: [plr_deep, plr_own]
    reason: declared I/O shell modules — effects are their job (functional-core escape hatch)
```

Metric keys and directions are the canonical ones from the `code-metrics` skill
(`METRIC_DIRECTIONS` in `crest_metrics.py`). Unknown keys fail validation.

## Work-order gate pattern

Add one gate to the work-order (`python` is already in the gate-script command
allowlist; no runner changes needed):

```yaml
gates:
  - id: "GATE-004"
    name: "metric_budget"
    description: "Diff-scoped metric gate: ratchet on modified files, bands on new files."
    command: "python skills/functional-core/tools/crest_metrics.py --src <src-root> --diff-base <base-ref> --budget .agent-output/metrics/<plan-id>-metric-budget.yaml --diff-report .agent-output/metrics/<plan-id>-diff-report.json"
    status: not-run
    result: null
```

`<base-ref>` should be the commit the implementation branched from (record the
SHA, not a moving branch name, when the phase is long-lived).

## Roles

**Planner** authors the budget: default is ratchet-everything plus the project's
standard `new_code_bands` profile; tighten, loosen, or exempt per phase with
rationale recorded in the plan. If a touched module is already a hotspot the
plan scopes for refactor, express the improvement as a checklist criterion — the
ratchet only guarantees "no worse".

**Implementer** runs the gate via `run-work-order-gates` in the normal
pre-COMPLETE self-check loop and iterates until exit 0. On a failing key, load
the `code-metrics` skill for the key's meaning and the owning rubric
(`functional-core` / `deep-modules` / lean-design) for the fix pattern. The
implementer never edits the budget, the effect policy, the baseline, or the
work-order gate command — a needed exemption is a blocker for the Planner.

**Code Reviewer** is the independent hard gate. Trust nothing recorded:

1. Re-run the exact `metric_budget` gate command from a clean checkout of the
   implementer's result. Compare the fresh `--diff-report` JSON against the
   recorded one (result, violations, `budget_sha256_16`).
2. Check the diff for touches to the bypass surface: the budget file, the
   work-order (gate command or `allowed_files` widened to include either),
   `effect_policy.json`, `crest_baseline.json`, or `crest_metrics.py` itself.
   Any such touch without explicit Planner sign-off in the plan = REJECTED.
3. A `--src` narrower than the plan's touched packages is also a bypass —
   verify the gate command's `--src` covers every modified source root.

## Beyond gating — using the diff report

The `--diff-report` JSON (before/after region vectors, per-new-file vectors) is
durable evidence for the implementation doc, trend input for mini-retros
(budgets systematically too loose? always exempted?), and — combined with churn
from `defect-observability` — the hotspot ranking that decides which refactors
earn plan slots at all.
