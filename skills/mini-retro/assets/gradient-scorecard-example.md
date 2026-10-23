---
ID: EXAMPLE
Origin: EXAMPLE
UUID: e0a1d7c4
Status: Active
Type: mini-retro-example
Plan_Reference: .agent-output/planning/006-depth-lean-remediation.md
Date: 2026-07-07
Owner_Role: Planner
Gate: satisfied
Authorship: first-hand
Policy: tier1-defaults-only
---

# Mini-Retro EXAMPLE: Gradient (1–10) Effectiveness Scorecard

> **ILLUSTRATIVE ONLY.** This is a retained walk-through artifact, not a record of a real
> completed run. It demonstrates a **quantitative gradient** overlay for the mini-retro,
> using a past plan as a plausible subject. The scores are **fabricated to show the
> method**; they are not an actual post-execution assessment.

**Canonical rubric source.** The 20-question prompts, 1–10 calibration anchors, sensitivity
rule, finding rule, first-run convention, and roll-up format are defined in:
[`../references/gradient-scorecard.md`](../references/gradient-scorecard.md).
This example uses `Q1..Q20` row identifiers; consult the rubric for the full aspect prompt
text. The anchors and rules are not duplicated here.

## Why a gradient (rationale)

The Tier-1 question bank answers each dimension categorically (`a` = nothing notable …
`d` = specific failure). That is excellent for **producing findings**, but it is a blunt
instrument for **measuring a trend**: an agent that improved from "barely acceptable" to
"solidly good" still records the same non-finding `a`. A 1–10 gradient per aspect:

- **Adds sensitivity.** A move from 6 → 8 is visible and comparable across runs.
- **Enables trend tracking.** Each aspect carries a `prior` score and a `Δ` so the corpus
  becomes a longitudinal signal ("is the Implementer getting more effective over time?").
- **Complements, does not replace, findings.** The categorical scheme still fires findings;
  the gradient just quantifies *how well* each aspect performed. Any aspect scoring **≤ 6**
  (or Δ ≤ −2 vs. prior) MUST spawn a tagged finding, so low scores stay actionable.

## Context

- **Plan:** 006 — Depth & Lean Remediation of the vsc-agents Plugin
- **Delegation chain:** Planner → Architect → Critic → Implementer (Phases 1–5) → Code Reviewer → QA → UAT → DevOps
- **Pre-release gate:** UAT — satisfied
- **Effective policy source:** tier1-defaults-only

## Effective Policy In Force

| Dimension | Requirement | Source | Notes |
|-----------|-------------|--------|-------|
| agents | required | tier1 | |
| skills | required | tier1 | |
| process | required | tier1 | |
| policy-fit | required | tier1 | |
| failure-mode-analysis | optional | tier1 | FM Exposure `none` (meta-repo tooling/docs) |
| gradient-scorecard | optional | tier1 | ON by default; walk-through demonstrated below |
| improvement | required | tier1 | |

## Standard categorical answers (unchanged — still the finding driver)

| Dimension | Answer | Rationale / evidence |
|-----------|--------|----------------------|
| agents | a | All invoked agents earned their place; Architect's F1–F8 conditions materially de-risked scope. |
| skills | a | deep-modules / lean-design / structured-labeling / no-silent-assumptions loaded at the right hooks. |
| process | b | One avoidable friction: the smoke-test ordinal check initially mis-flagged multi-list agent files (see F-1). |
| policy-fit | a | Tier-1 defaults fit this meta-repo change; no Tier-2 additions needed. |
| failure-mode-analysis | a | Correctly declared `none`; the plan mints the oracle rather than consuming a registry. |
| improvement | free-text | Gradient scorecard (this example) is itself the proposed net improvement. |

## Gradient Scorecard — 20 aspects (1–10)

Aspect prompts are in [`../references/gradient-scorecard.md`](../references/gradient-scorecard.md).
Grouped: **repo/system** (Q1–Q4), **agents** (Q5–Q12), **skills** (Q13–Q16),
**interworking** (Q17–Q20). Each row: score, prior, Δ, and a one-line rationale.
Rows scoring ≤ 6 or Δ ≤ −2 spawn a finding (see below).

### Group A — Repo / system effectiveness (Q1–Q4)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q1 | 8 | 7 | +1 | Chain ran end-to-end; only one gate re-run. |
| Q2 | 8 | 8 | 0 | Structured-labeling kept the large plan auditable. |
| Q3 | 7 | 6 | +1 | ADR-003 was easy to cite for the fold-in decision. |
| Q4 | 9 | 6 | +3 | The new smoke-test checks caught the seeded fixtures exactly. |

### Group B — Agents (Q5–Q12)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q5 | 8 | 7 | +1 | Tracer-bullet ordering (defects → oracle → refactors) held. |
| Q6 | 9 | 8 | +1 | Architectural conditions were high-signal; ADR stubs pre-drafted. |
| Q7 | 8 | 8 | 0 | Per-list scoping catch prevented a false-positive oracle. |
| Q8 | 7 | 5 | +2 | Clean phase-by-phase execution; no out-of-scope diff this time. |
| Q9 | 8 | 6 | +2 | Wrote a standalone artifact this run (closes a prior gap). |
| Q10 | 8 | 7 | +1 | Ran both bash + pwsh smoke paths; fixtures exercised. |
| Q11 | 7 | 7 | 0 | Confirmed skill-count and line-count reduction targets met. |
| Q12 | 8 | 8 | 0 | Mini-retro rode the release commit; no separate step needed. |

### Group C — Skills (Q13–Q16)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q13 | 8 | 7 | +1 | deep-modules-orchestration fired at the contract boundary. |
| Q14 | 8 | 7 | +1 | lean-design guardrails directly shaped the cuts. |
| Q15 | 7 | 6 | +1 | Consolidations closed two overlaps; no new gap surfaced. |
| Q16 | 8 | 8 | 0 | Single-owner discipline avoided contradictory triggers. |

### Group D — Agent ↔ skill interworking (Q17–Q20)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q17 | 8 | 6 | +2 | Delegation contract carried scope cleanly through 5 phases. |
| Q18 | 8 | 8 | 0 | Architect/Critic/CodeReview/QA/UAT each caught different things. |
| Q19 | 6 | 4 | +2 | Improved after a coupling task, but some trigger restatements remain. |
| Q20 | 8 | 6 | +2 | Multiple prior findings demonstrably closed this run. |

### Roll-up (sensitivity view)

| Group | Mean (this run) | Mean (prior) | Δ |
|-------|:---------------:|:------------:|:--:|
| Repo / system (Q1–Q4) | 8.0 | 6.75 | +1.25 |
| Agents (Q5–Q12) | 7.9 | 7.0 | +0.9 |
| Skills (Q13–Q16) | 7.75 | 7.0 | +0.75 |
| Interworking (Q17–Q20) | 7.5 | 6.0 | +1.5 |
| **Overall (20 aspects)** | **7.80** | **6.75** | **+1.05** |

Interpretation: the two aspects worth attention are **Q19 (agent↔skill coupling = 6)** —
still above the finding floor but the lowest score and a known residual — and the strong
positive **Δ on Q4/Q8/Q9/Q17/Q20**, which are the aspects prior mini-retro findings targeted.
The gradient makes that closure *visible as a number*, which the categorical `a` could not.

## Findings

Aspects scoring ≤ 6 or with Δ ≤ −2 become findings (plus the standard categorical non-defaults).

```yaml
- id: F-1
  dimension: process
  summary: "Smoke-test ordinal check initially mis-flagged legitimate multi-list agent files"
  detail: >-
    The categorical process answer was 'b'. The duplicate-ordinal check fired on
    valid agent files containing several ordered lists that each restart at '1.'. Fixed by strict
    per-list scoping plus a negative-guard fixture. Recorded for the corpus.
  target-tier: core
  target: process
  change-type: modify
  confidence: med
  fold-in: needs-bulk-review

- id: F-2
  dimension: gradient-scorecard
  summary: "Q19 agent-skill coupling scored lowest (6): some trigger restatements remain"
  detail: >-
    Lowest gradient aspect this run. A coupling task reduced trigger restatement but a few
    load-directives still duplicate a skill description's own trigger table. Not a regression
    (delta +2 vs prior 4), but the absolute score flags it as the next coupling target.
    This finding exists ONLY because the gradient surfaced it -- the categorical skills/process
    answers were 'a'/'b' and would not have isolated this specific residual.
  target-tier: core
  target: planner
  change-type: modify
  confidence: med
  fold-in: needs-bulk-review

- id: F-3
  dimension: improvement
  summary: "Adopt the 1-10 gradient scorecard as an optional, ON-by-default Tier-1 mini-retro overlay"
  detail: >-
    This example demonstrates that a per-aspect gradient with prior/delta tracking adds
    run-over-run sensitivity the categorical scheme lacks, while keeping findings actionable
    via the <=6 / delta<=-2 floor. Candidate to add to references/question-bank.md as an
    OPTIONAL, ON-by-default dimension so projects that want trend metrics get them
    automatically, with a clean disable opt-out for those that do not.
    Anchors + sensitivity rule are the proposed spec in references/gradient-scorecard.md.
  target-tier: core
  target: mini-retro
  change-type: add
  confidence: med
  fold-in: needs-bulk-review
```

## Warnings

- **Illustrative scores.** The numeric values here are fabricated for demonstration and MUST NOT
  be read as a real assessment of any plan's chain.
- **Calibration risk.** Gradient scores are only comparable if every author uses the same anchors
  (see [`../references/gradient-scorecard.md`](../references/gradient-scorecard.md)).

## Fold-in Candidates (quick reference)

| Finding | Target tier | Target | Confidence | Fold-in |
|---------|-------------|--------|------------|---------|
| F-1 | core | process | med | needs-bulk-review |
| F-2 | core | planner | med | needs-bulk-review |
| F-3 | core | mini-retro | med | needs-bulk-review |
