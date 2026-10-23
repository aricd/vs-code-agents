# Gradient Scorecard — Mini-Retro Reference (Tier 1)

The **20-question gradient scorecard** is an optional, ON-by-default Tier-1 mini-retro
dimension. It adds a quantitative 1–10 per-aspect overlay to the standard categorical
self-assessment, enabling run-over-run trend tracking and sensitivity to small improvements
or regressions that the coarse categorical scheme cannot express.

**Single owner.** This file is the sole canonical source for:
- The 20 questions (four groups: repo/system, agents, skills, interworking)
- The 1–10 calibration anchors
- The sensitivity and finding rules
- The first-run convention
- The roll-up format
- The per-aspect rationale requirement

`question-bank.md`, `assets/mini-retro-template.md`, `project-policy.schema.md`, `SKILL.md`,
the standalone blank (`assets/gradient-scorecard-blank.md`), and the walk-through example
(`assets/gradient-scorecard-example.md`) all reference this file via `Q1..Q20` identifiers
and never duplicate its content.

## Calibration anchors (1–10)

| Score | Meaning |
|-------|---------|
| **1–2** | Severely deficient / blocked; required constant manual rescue or was a net drag. |
| **3–4** | Below expectations; notable rework, missed obligations, or wrong-shaped output. |
| **5–6** | Acceptable; delivered but with real friction, gaps, or avoidable round-trips. |
| **7–8** | Effective; did its job with only minor friction. |
| **9–10** | Exemplary; near-frictionless, materially raised the outcome. |
| **N/A** | Aspect not exercised this run. Excluded from group and overall means. |

**Scores are comparable across runs only when every author uses these anchors.** Do not
adjust the scale between runs.

## Sensitivity rule

- **Δ ≥ ±2 (single run):** treat as a signal worth a finding.
- **Δ of ±1:** noise unless it repeats across ≥ 2 consecutive runs.

`prior` = the score for the same aspect in the last comparable retro.

**First run:** set `prior = —`; omit Δ (baseline-establishing run; sensitivity engages
from run 2).

## Finding rule

Any aspect scoring **≤ 6** OR with **Δ ≤ −2** MUST spawn a tagged finding using the
standard mini-retro finding schema (see `references/question-bank.md` §Finding Schema).

**Finding-tag mapping by group:**

| Group | `target` value |
|-------|---------------|
| Q1–Q4 (Repo / system) | `process` |
| Q5–Q12 (Agents) | the named agent (e.g. `planner`, `implementer`, `qa`) |
| Q13–Q16 (Skills) | the named skill (e.g. `mini-retro`, `structured-labeling`) |
| Q17–Q20 (Interworking) | `process` |

Use `dimension: gradient-scorecard` for every gradient finding. The `change-type` is
typically `modify`; use `add` when the finding proposes a new agent/skill/practice.

## Roll-up format

After all 20 rows, compute a group and overall roll-up. Exclude N/A aspects from means.

| Group | Mean (this run) | Mean (prior) | Δ |
|-------|:---------------:|:------------:|:-:|
| Repo / system (Q1–Q4) | _x.x_ | _x.x_ | _±x.x_ |
| Agents (Q5–Q12) | _x.x_ | _x.x_ | _±x.x_ |
| Skills (Q13–Q16) | _x.x_ | _x.x_ | _±x.x_ |
| Interworking (Q17–Q20) | _x.x_ | _x.x_ | _±x.x_ |
| **Overall (20 aspects)** | **_x.x_** | **_x.x_** | **_±x.x_** |

First run: `prior` column = `—`; Δ column blank.

## Rationale requirement

**Every scored aspect row MUST include a one-line rationale cell.** A bare score with no
rationale is non-conforming. The rationale must cite the first-hand observation or
execution evidence that justifies the score.

## The 20 questions

Each entry states the aspect to score. Scorecards (blank or filled) reference these rows by
`Q1..Q20` identifier and do not restate the prompt text.

### Group A — Repo / system effectiveness (Q1–Q4)

| # | Aspect (how effective was…) |
|---|----------------------------|
| Q1 | …the agent+skill system overall at moving intent → committed value with minimal manual intervention? |
| Q2 | …the repo's conventions (labels, doc-lifecycle, `.agent-output/` layout) at reducing friction vs. adding ceremony? |
| Q3 | …context discovery/navigation (`CONTEXT.md`, ADRs, prior artifacts) when a decision needed grounding? |
| Q4 | …the tooling oracles (validators, smoke tests, `make verify`) at catching issues before escape? |

### Group B — Agents (Q5–Q12)

| # | Aspect (how effective was the … agent at its assigned task?) |
|---|--------------------------------------------------------------|
| Q5 | **Planner** — decomposition, sequencing, traceability |
| Q6 | **Architect** — right decisions, ADR framing |
| Q7 | **Critic** — surfaced real risks vs. noise |
| Q8 | **Implementer** — executed the assigned tasks correctly and in scope |
| Q9 | **Code Reviewer** — caught quality/scope/maintainability issues |
| Q10 | **QA** — verification coverage and rigor |
| Q11 | **UAT** — validated business value against the value statement |
| Q12 | **DevOps** — packaging/release smoothness |

### Group C — Skills (Q13–Q16)

| # | Aspect (how effective were the skills at…) |
|---|--------------------------------------------|
| Q13 | …being loaded at the *right time* (timeliness of the phase hooks)? |
| Q14 | …*materially changing* decisions (impact vs. being inert noise)? |
| Q15 | …*covering* the needs (no reusable capability gap left open)? |
| Q16 | …*non-conflict* (no skill guidance ignored or contradicted)? |

### Group D — Agent ↔ skill interworking (Q17–Q20)

| # | Aspect (how effective was the collaboration at…) |
|---|--------------------------------------------------|
| Q17 | …handoff quality between agents (context preserved, no re-derivation)? |
| Q18 | …gate effectiveness (each gate added *distinct* assurance vs. redundancy)? |
| Q19 | …agent↔skill coupling (agents deferred to skills as single owners vs. restating triggers)? |
| Q20 | …net trajectory (is the system more effective this run than the last comparable run)? |
