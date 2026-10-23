# Tier-2 Project Policy Schema (`policy.yaml`)

Location: `.agent-output/mini-retro/policy.yaml` in the project repo.
Purpose: record **project-specific modifications** to mini-retro behavior and to the agent/skill practices this project expects. Entirely **opt-in** — if the file is absent, the mini-retro runs on Tier-1 defaults.

Tier 2 **always wins over Tier 1** within this project's scope (see memory-model.md).

## Top-level keys

```yaml
# .agent-output/mini-retro/policy.yaml
version: 1                      # schema version (integer, required)

profile: regulated              # optional free-text label: e.g. personal | standard | regulated
                                # informational only; does not change behavior by itself

final-gate: UAT                 # optional; the pre-release gate the mini-retro confirms
                                # before running. Default: UAT.

dimensions:                     # overrides to the Tier-1 question bank dimensions
  <dimension-id>: <override>    # see "Dimension overrides" below

project-questions:              # optional extra questions, project-scoped, never auto-promoted
  - id: PQ-1
    dimension: process          # which Tier-1 dimension this augments (free-text ok)
    requirement: required       # required | optional
    question: "<text>"
    default: a                  # the default option letter
    options:
      a: "<default answer>"
      b: "<alternative>"

practices:                      # optional named practices a 'require' override can cite
  <practice-id>:
    description: "<what the project mandates>"
    evidence-hint: "<where the mini-retro should look to confirm it was honored>"
```

## Dimension overrides

Each `<dimension-id>` may be set to one of the overrides below. The known Tier-1
dimension ids are: `agents`, `skills`, `process`, `policy-fit`, `failure-mode-analysis`,
`gradient-scorecard`, `improvement`. Unknown ids are recorded as a warning but do not
block the run.

| Override | Effect |
|----------|--------|
| `require` | Dimension is mandatory; the mini-retro flags any gap as a finding. May cite a `practices` entry. |
| `enable` | Adds a Tier-1-optional, `default-asked: false` dimension to the asked-set (asked, absence not a defect). For dimensions already `default-asked: true` (e.g. `gradient-scorecard`, `failure-mode-analysis`), `enable` is an idempotent no-op. |
| `disable` (alias `suppress`) | Removes the dimension entirely — not asked, absence never flagged. For ON-by-default dimensions this is the opt-out. `disable` and `require` are mutually exclusive; `disable` dominates. |
| `optional` | Asked, but absence is not a defect (the Tier-1 default for `default-asked: true` optional dimensions). |

**ON-by-default dimensions.** `gradient-scorecard` and `failure-mode-analysis` are
`optional, default-asked: true` — they are asked unless Tier-2 `disable`s them. Their
override rows under `dimensions:` follow the same schema as any other dimension:

```yaml
dimensions:
  gradient-scorecard: disable           # opt out entirely
  gradient-scorecard: require           # opt in with gap = finding (map form recommended)
  gradient-scorecard:
    override: require
    practice: gradient-scorecard        # references practices.gradient-scorecard below
```

**`gradient-scorecard` answer shape.** Numeric: 20 aspects scored 1–10 with `prior` and
`Δ`, recorded in a dedicated gradient section of the mini-retro artifact. This is distinct
from the letter-option (`a/b/c/d`) answers table used by the categorical dimensions. `require`
flags gaps defined as: missing gradient section in the artifact, or any aspect scoring ≤ 6 /
Δ ≤ −2 not accompanied by a tagged finding. Calibration anchors, sensitivity rule, finding
rule, and roll-up format are owned by
[`references/gradient-scorecard.md`](./gradient-scorecard.md).

A dimension may also be given as a map to attach a practice and rationale:

```yaml
dimensions:
  failure-mode-analysis:
    override: require
    practice: per-task-fmea       # references practices.per-task-fmea below
    rationale: "Regulated device software; per-task failure-mode + risk is mandatory."
```

## Resolution

`effective dimensions = Tier-1 baseline, with each override applied, then project-questions appended.`

The mini-retro records the resolved effective set in the artifact so the policy in force is auditable per plan.

## Validation rules

- `version` is required and must be an integer.
- Unknown `<dimension-id>` values under `dimensions` are recorded as a warning in the artifact but do not block the run. Known ids: `agents`, `skills`, `process`, `policy-fit`, `failure-mode-analysis`, `gradient-scorecard`, `improvement`.
- A `require` override that names a `practice` must have that practice defined under `practices`; otherwise the mini-retro records a warning and treats it as `require` without an evidence hint.
- The file is never edited by the mini-retro automatically; it is maintained by the project (the bulk-review fold-in step may propose edits).
