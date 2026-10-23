# Mini-Retro Question Bank (Tier 1 baseline)

This is the **durable, cross-project** baseline. Tier-2 project policy (`policy.yaml`) overlays this set — enabling, suppressing, requiring, or extending dimensions. The mini-retro self-assesses the **effective** set (Tier 1 ⊕ Tier 2), not this set verbatim.

These are **reflection prompts the orchestrator answers about its own experience of the chain** — not questions put to the user; the skill never prompts the user. Every dimension is **default-able**: a dimension with nothing notable is recorded at its default (a-option) and produces no finding. Answer from first-hand recall, corroborated by execution evidence.

## Resolution model (deterministic)

A Tier-1 dimension is included in the effective asked-set by these rules:

| Tier-1 `requirement` | `default-asked` marker | Included by default? | How to change |
|---------------------|------------------------|----------------------|---------------|
| `required` | (not applicable) | **Always** | Tier-2 `disable` removes it; `require` is redundant |
| `optional` | `default-asked: true` | **Yes** — asked unless Tier-2 `disable`s it | Tier-2 `disable` (alias `suppress`) opts out; `require` strengthens |
| `optional` | `default-asked: false` (or marker absent) | **No** — not asked unless Tier-2 `enable`s it | Tier-2 `enable` adds it to the asked-set |

**`enable` on an `optional, default-asked: true` dimension is an idempotent no-op** — the
dimension is already asked; no change results.

**`disable` (alias `suppress`)** is the **existing** opt-out keyword. For an ON-by-default
dimension it removes the dimension from the effective asked-set for that project. `disable`
and `require` are mutually exclusive per dimension-id; `disable` dominates (removal makes
`require` moot).

Dimensions whose entries carry no explicit `default-asked` marker are treated as
`default-asked: false` — they require a Tier-2 `enable` or `require` to appear in the
effective asked-set.

## Dimensions

Each dimension has a stable `id` (so Tier-2 can reference it), a default `requirement`
(`required` = absence is a defect; `optional` = asked but absence is fine), an optional
`default-asked` marker, and the question.

### A. Agents — `agents` (required)

> Did every invoked agent earn its place, and did each fulfill its role?
- a) Yes — all necessary and effective *(default)*
- b) An agent added little value / was redundant — name it
- c) A needed role was missing or invoked too late — name it
- d) An agent's role definition was unclear or mismatched in practice — name it

Pre-fill from: delegation chain in the execution-state file; count of round-trips per agent.

### B. Skills — `skills` (required)

> Were the right skills loaded at the right time?
- a) Yes *(default)*
- b) A skill misfired, conflicted, or was noise — name it
- c) A missing skill would have helped (reusable gap) — describe it
- d) A skill was loaded but its guidance was ignored/contradicted — name it

Pre-fill from: skills referenced in planning/implementation artifacts.

### C. Process / workflow — `process` (required)

> Did the workflow sequencing, gating, and handoffs fit this work?
- a) Yes *(default)*
- b) Excessive back-and-forth / rework — where?
- c) A gate was skipped, added, or mis-ordered — which?
- d) A blocker was escalated too late or unnecessarily — which?

Pre-fill from: blocker/escalation entries, phase durations, rework markers in changelogs.

### D. Policy fit — `policy-fit` (required)

> Did the **effective** project policy (Tier 1 ⊕ Tier 2) match what this work actually needed?
- a) Yes *(default)*
- b) Something REQUIRED added no value here — candidate to relax in Tier 2
- c) Something ABSENT should have been required — candidate to add in Tier 2 / promote to Tier 1
- d) A Tier-2 project rule was not honored during execution — which?

This is the dimension that drives the two-tier feedback loop. Always produces tagged findings when answered b/c/d.

### E. Failure-mode analysis — `failure-mode-analysis` (optional, `default-asked: true`)

> Were failure modes and per-task risk considered to the degree this project requires?
- a) Not applicable to this project *(default when Tier-2 suppresses)*
- b) Yes — handled appropriately
- c) No — and they should have been (gap)

Tier-2 `require` flips this to a checked obligation (e.g., regulated environments where Planner must delegate to Analyst for failure-mode + risk determination per task). Tier-2 `disable` (`suppress`) removes it entirely (personal projects). See memory-model.md worked example.

### F. Net improvement — `improvement` (required)

> Single most valuable change to the agent set coming out of this plan?
- Free-text. Map the answer to a tagged finding.

## Finding schema

Convert every non-default answer into a finding with these fields (see memory-model.md for tag semantics):
```yaml
- id: F-1
  dimension: skills            # which dimension produced it
  summary: "<one line>"
  detail: "<verbatim orchestrator rationale + first-hand evidence>"
  target-tier: core            # core | project
  target: structured-labeling  # agent/skill name, or "process"
  change-type: modify          # add | modify | remove | suppress
  confidence: med              # low | med | high
  fold-in: needs-bulk-review   # yes | needs-bulk-review
```

Default (a-option) answers do **not** produce findings; record them only as the dimension's recorded answer in the artifact's answers table.

## G. Gradient scorecard — `gradient-scorecard` (optional, `default-asked: true`)

A **quantitative overlay** scored alongside the categorical dimensions above. Twenty aspects
across four groups (repo/system, agents, skills, interworking), each scored **1–10** with a
`prior` and a computed `Δ`, plus a per-group and overall roll-up.

**Canonical source.** The 20 questions, calibration anchors (1–2 deficient … 9–10 exemplary),
sensitivity rule (Δ ≥ ±2 = signal; ±1 = noise unless it repeats), finding rule (aspect ≤ 6
or Δ ≤ −2 → tagged finding), first-run baseline convention (`prior = —`, Δ omitted), and
roll-up format all live exclusively in
[`references/gradient-scorecard.md`](./gradient-scorecard.md).
This entry is a pointer only — do not restate the questions here.

**Default posture.** The dimension is **optional and ON by default** (`default-asked: true`):
it ships in the Tier-1 asked-set for every consumer. A downstream project opts **out** via
the existing Tier-2 `disable` (alias `suppress`) override, which removes it from that
project's effective asked-set. Using Tier-2 `enable` on this dimension is an idempotent
no-op (it is already asked). Tier-2 `require` strengthens it: any gap (missing scorecard or
a sub-floor score without a finding) becomes a finding.

**Answer shape.** Numeric: each of the 20 aspects is scored 1–10 with `prior` and `Δ`,
recorded in a gradient section of the mini-retro artifact — distinct from the letter-option
answers table for the categorical dimensions.
