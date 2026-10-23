# Gradient scorecard as an optional, ON-by-default mini-retro dimension

## Status

accepted

## Context

The mini-retro skill evaluates each completed execution chain against an effective policy assembled from two tiers: a Tier-1 baseline (cross-project, durable) and an optional Tier-2 project policy (project-scoped). The Tier-1 baseline dimensions answer categorically (`a/b/c/d`) — excellent for producing findings but a blunt instrument for measuring a trend. An agent that improved from "barely acceptable" to "solidly good" still records the same non-finding `a` answer.

A worked example demonstrated a 20-question 1–10 gradient overlay: four groups (repo/system Q1–Q4, agents Q5–Q12, skills Q13–Q16, agent↔skill interworking Q17–Q20), each aspect scored with a `prior` and a computed `Δ`, a calibration anchor table, a sensitivity rule (Δ ≥ ±2 = signal; ±1 = noise unless it repeats across ≥ 2 runs), and a finding rule (aspect ≤ 6 or Δ ≤ −2 → tagged finding). That example made clear that the gradient complements, rather than replaces, the categorical scheme.

The question was: at what scope should the gradient ship?

- **Option A (project-scoped only):** embed the rubric as a Tier-2 project-question and require opt-in per project. Leaner blast, but shoehorns a numeric answer shape into the project-question mechanism, leaves the template without a gradient section, and loses the cross-project reusability and calibration consistency benefit.
- **Option B (ON-by-default Tier-1 optional dimension — chosen):** promote the gradient to a first-class, reusable Tier-1 optional dimension, ship it in the default asked-set for every consumer, and let downstream projects opt **out** via the existing Tier-2 `disable` (alias of `suppress`) override.

This ADR captures the Option B decision and its ON-by-default posture.

## Decision

**Adopt the 20-question 1–10 gradient scorecard as an optional, ON-by-default Tier-1 mini-retro dimension (`gradient-scorecard`).**

Key elements of this decision:

1. **Single canonical owner.** The 20 questions, calibration anchors, sensitivity rule, finding rule, first-run convention, and roll-up format live exclusively in `skills/mini-retro/references/gradient-scorecard.md`. No other file duplicates this content; question-bank, template, schema, SKILL, and per-project artifacts reference it via `Q1..Q20` identifiers.

2. **ON by default for every consumer.** `gradient-scorecard` is registered in the Tier-1 question bank with `requirement: optional, default-asked: true`. Every consumer's default asked-set includes it without any Tier-2 action.

3. **Deterministic resolution model.** A Tier-1-optional dimension is asked **iff** `default-asked: true`. `enable` on an already-`default-asked: true` dimension is an idempotent no-op. This rule is recorded consistently in `question-bank.md`, `memory-model.md`, and `project-policy.schema.md`.

4. **Clean opt-out via existing `disable` keyword.** `disable` (alias `suppress`) is the pre-existing override that removes a dimension from the effective asked-set. It is not a new keyword; this plan documents its application to `gradient-scorecard`. A downstream project that does not want the 20-question scoring opts out with a single Tier-2 line: `dimensions.gradient-scorecard: disable`.

5. **Numeric answer shape.** Gradient answers are 20 × (score, prior, Δ, rationale), plus a group and overall roll-up — distinct from the letter-option `a/b/c/d` answers of the categorical dimensions. The schema documents this distinction.

6. **Non-blocking content.** The gradient section, like all mini-retro content, never blocks the pipeline. Only the _existence_ of the artifact before the DevOps handoff is an enforcement gate. `require` flags gaps but does not block the chain.

7. **This repo opts in at `require`.** The vsc-agents repo's own Tier-2 `policy.yaml` sets `dimensions.gradient-scorecard: { override: require, practice: gradient-scorecard }` with a practices entry pointing at the rubric, so every plan wrap-up here runs the 20 questions and any gap becomes a finding.

## Considered Options

**Option A — Project-scoped only (no Tier-1 change).** Rejected: loses reusability, forces numeric answers into the project-question mechanism (wrong shape), and provides no cross-project calibration benefit.

**Option B — OFF by default, opt-in via `enable`.** Considered and rejected in favor of ON-by-default: the trend-signal benefit outweighs the per-run scoring cost, and the `disable` opt-out preserves downstream autonomy without requiring active activation per project.

## Consequences

### Positive

- Every plan wrap-up (across all consumers) yields a calibrated, trend-trackable effectiveness signal by default — no one has to remember to add it.
- Calibration anchors ship with the rubric, making scores comparable across runs and teams.
- The `disable` one-line opt-out means no consumer is forced to keep it.
- The change is additive: existing `a/b/c/d` categorical dimensions and prior mini-retro artifacts are unaffected (BACKCOMPAT).

### Negative

- Consumers who did not previously use the gradient now have a 20-question section in their default asked-set. They must actively `disable` if they do not want it. This is an intentional, announced behavior change (CHANGELOG).
- First-run has no `prior` baseline; sensitivity (trend signal) does not engage until run 2. Mitigated by the rubric's first-run convention (`prior = —`, Δ omitted).
- Calibration drift risk: scores are only comparable if every author uses the same anchors. Mitigated by shipping the anchor table in the single-owner rubric reference; all paths to the scorecard link back to it.

## Related ADRs

- [ADR-013](ADR-013-retrospective-agent-removal.md): Establishes `mini-retro` as the sole retrospective mechanism (folding in the removed Retrospective agent's charter) that this ADR extends with the gradient-scorecard dimension.
