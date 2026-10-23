---
Session_ID: <session-id> # e.g. 064
Type: brainstorm-retro
Date: <YYYY-MM-DD>
Owner_Role: Planner # orchestrating agent that ran the session
Authorship: first-hand # first-hand | reconstructed (lower fidelity) | resumed (partway handoff -- part first-hand, part reconstructed)
Challenge_Category: <category> # e.g. api-to-hardware-simulator | data-pipeline | ui-surface | protocol-adapter | docs-structure
Verdict: <GO | NO-GO | GO-with-OPENQs>
---

# Brainstorming Session Retrospective — <session-id>

First-hand record of the orchestrating agent's experience running this brainstorming session. Authored by the orchestrator at the Gate step (Session Protocol step 8) — never a user survey. Goal: improve the brainstorming skill, agent set, and process. Findings use the mini-retro finding schema and accumulate in the same bulk-review corpus.

## Part 0 — Session Fingerprint

```
session-id:
challenge-category:    # e.g. api-to-hardware-simulator | data-pipeline | ui-surface | protocol-adapter | docs-structure
challenge-framing:     # gap-closure | greenfield | refactor | reconciliation | discovery
collapse-target:       # one-decision | ship-set | ranked-backlog | research-map
topology:              # tournament-bracket | binary-bracket | linear-cycles | delphi-blind | tiered-adversarial | campaign | direct
lens:                  # deep-lean | deep-modules | lean-design | domain | metric
seeds:                 # count of radically-different starting designs
rounds-planned:
rounds-actual:         # if > planned, bs-divergence must be non-default
critic-passes:         # count of independent critic re-scores
acceptance-basis:      # what made "done" checkable — e.g. "6-gap table + IC comparison + named constraints"
constraints-named:     # count of pre-declared constraint IDs (CON-*, SEC-*, NS-*, FRAME-*)
winner:                # design name
winner-provenance:     # solo | synthesis | fold-in-composite (how many losing seeds contributed ideas)
outcome:               # shipped (<commit>) | reversed | superseded | abandoned | unknown  (update later)
authorship:            # first-hand | reconstructed | resumed
```

---

## Part 1 — Structural Alignment — `bs-framing` (required)

> Was the framing sufficient that effort _obviously_ moved toward the goal — could every analyst tell, without asking, whether their output advanced the collapse target?

- a) Yes — no mid-session reframing needed _(default)_
- b) Framing gap surfaced mid-session — a goal, constraint, or convention had to be added/clarified after work started.
- c) An analyst produced work that did not advance the collapse target (wrong problem, wrong lens, wrong granularity).
- d) The collapse target itself shifted (e.g. one-decision became ranked-backlog).

**Answer:** <!-- a / b / c / d -->

**Rationale/evidence:** <!-- verbatim — include round number, artifact name, or clarification added -->

**Countable proxies:** mid-session clarification count; wasted-artifact count; reframe round number.

---

## Part 2 — Scoring Integrity — `bs-scoring` (required when lens uses a countable rubric)

> Did self-reported scores survive independent re-scoring, and were the counting conventions fixed _before_ scoring began?

- a) Yes — self-reports within noise of critic scores; no convention changed mid-session _(default)_
- b) Systematic self-report bias — critic corrections moved scores in one direction.
- c) A counting convention was clarified or invented **after** scoring had begun (retroactive re-scoring required).
- d) A convention was applied inconsistently across rounds/seeds.

**Answer:** <!-- a / b / c / d -->

**Rationale/evidence:** <!-- for b: record mean |self − critic| and direction; for c/d: name the convention -->

**Countable proxies:** per-seed |self-reported − critic-verified| delta; count of conventions introduced after round 1; count of designs re-scored retroactively.

---

## Part 3 — Divergence and Convergence Mechanics — `bs-divergence` (required)

> Did expansion produce genuinely different shapes, and did convergence mechanics (fold-ins, eliminations, synthesis) add value?

- a) Yes — seeds structurally distinct; fold-ins net-positive; convergence introduced no new design _(default)_
- b) Seeds were variations on one idea.
- c) A mandated fold-in **hurt** the receiving design (raised its cost).
- d) Convergence did new design work (violates Load-Bearing Rule 1).
- e) A winning idea came from outside the seed set (the frame itself was wrong — reframe was found late or by accident).

**Answer:** <!-- a / b / c / d / e -->

**Rationale/evidence:** <!-- for b: name the collapsed families; for c: name the pair and mechanism; for d/e: describe -->

**Countable proxies:** count of losing seeds that contributed ideas to winner (fold-in yield); count of fold-ins that raised receiver's score; distinct organizing questions among seeds.

---

## Part 4 — Skill Friction and the Optional-Structure Probe — `bs-skill-friction` (required)

> Where did a skill's guidance run out, misfire, or require improvisation — and would optional structure (a checklist, preflight, template, or worked convention) have prevented it?

- a) No friction _(default)_
- b) A skill was loaded but a needed procedure wasn't in it — the orchestrator improvised.
- c) Two skills gave conflicting guidance at a decision point.
- d) A skill's guidance existed but was skipped/forgotten at the moment it applied (placement failure, not content failure).
- e) A missing skill would have helped (reusable gap).

**Answer:** <!-- a / b / c / d / e -->

**Rationale/evidence:** <!-- name the skill(s), the decision point, and what was improvised or missed -->

<!-- For every b/d answer, fill the structure probe below; otherwise remove it -->

```yaml
structure-probe:
  friction:
  proposed-structure: # preflight-checklist | scorecard-template | convention-audit | trigger-table | worked-example
  optional-or-required: # optional | required
  cost-if-adopted: # what every future session pays
  evidence: # what in THIS session it would have prevented
```

**Pattern hook:** the same friction with the same proposed-structure appearing in ≥2 sessions is the promotion signal from optional Tier-2 structure to Tier-1 skill content.

---

## Part 5 — Ambiguity Attribution — `bs-ambiguity` (required)

> Rank what actually kept (or failed to keep) the session unambiguous. Rank only factors that were present; mark absent factors `n/a`.

| Factor | Present? | Rank (1 = biggest contributor) |
| --- | --- | --- |
| Countable rubric with fixed conventions (e.g. IC proxies) |  |  |
| Checkable acceptance criteria (gap table, test IDs, verb catalog) |  |  |
| Pre-named constraints with IDs (CON-_, SEC-_, NS-\*) |  |  |
| Declared session contract (collapse target, topology, lens) |  |  |
| Independent critic/skeptic empowered to reject the frontrunner |  |  |
| Domain familiarity / prior analyses to build on |  |  |
| Objective challenge framing (problem is externally checkable) |  |  |

- a) Session was low-ambiguity; top factor ranked _(default when ambiguity was low)_
- b) Session was ambiguous despite these factors — which factor failed to do its job?

**Answer:** <!-- a / b -->

**Rationale/evidence:**

**Pattern hook:** after ~5 sessions, factors consistently ranked 1–2 are what "communicating intent clearly" actually consists of — fold them into the session-contract template as required fields.

---

## Part 6 — Mistake Ledger — `bs-mistakes` (required)

> Every mistake made during the session, whether or not it was caught, with its catch mechanism.

| # | Mistake | Caught by | Round caught | Cost (rounds/artifacts of rework) | Skill fold-in candidate? |
| --- | --- | --- | --- | --- | --- |
| 1 |  |  |  |  |  |

A mistake caught by a **designed mechanism** (critic pass, convention audit, gate) is evidence the mechanism works — record it as a pass, not a defect. A mistake caught by luck, by the user, or not caught until a later session is a finding.

---

## Part 7 — Net Improvement — `bs-improvement` (required, free text)

> Single most valuable change to the skill/agent set coming out of this session?

<!-- free text -->

---

## Findings

Convert every non-default answer to a finding using the mini-retro finding schema. If none, write "None — all dimensions at default."

```yaml
- id: F-1
  dimension: bs-scoring # bs-framing | bs-scoring | bs-divergence | bs-skill-friction | bs-ambiguity | bs-mistakes | bs-improvement
  summary: "<one line>"
  detail: "<verbatim rationale + first-hand evidence>"
  target-tier: core # core | project
  target: deep-modules # skill/agent name, or "process"
  change-type: modify # add | modify | remove | suppress
  confidence: med # low | med | high
  fold-in: needs-bulk-review # yes | needs-bulk-review
```

## Fold-in Candidates (quick reference)

| Finding | Dimension | Target tier | Target | Confidence | Fold-in |
| ------- | --------- | ----------- | ------ | ---------- | ------- |
| F-1     |           |             |        |            |         |
