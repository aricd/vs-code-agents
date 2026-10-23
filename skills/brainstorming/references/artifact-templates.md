# Brainstorming Artifact Templates

Use these templates proportionately. Do not emit a full ledger for trivial work.

## Session Contract

```
ROLE: <expertise>
OBJECTIVE: <specific collapse target>
APPROACH: <topology, rounds, delegations, visibility, lens>
OUTPUT: <decision memo | ship-set | backlog | research map>

Parameters:
- collapse_target:
- topology:
- rounds:
- delegations:
- roles:
- visibility:
- lens:
- checkpoint_interval:
- stop_condition:
- artifact_mode:
```

## Foundation

```
Problem:
Known constraints:
Non-goals:
Decision owner:
Current evidence:
Relevant existing skills/rubrics:
Terms:
Prior locked decisions:
Open questions:
```

## Delegation Prompt

```
Role: <analyst | critic | skeptic | synthesizer | empiricist | domain-specialist>
Round:
Visibility: <blind | build-on-prior | ledger | cross-exam>
Lens:
Doc identity (shared, session-wide): ID=<NNN> Origin=<NNN> UUID=<8-hex>
Output file: <exact path, e.g. .agent-output/analysis/NNN-<session-slug>-<round>-<role><seat>.md>
Task:
Must produce:
- Findings
- Evidence or reasoning
- Options promoted / killed
- Risks and unknowns
- Recommendation for next round
Do not:
- Allocate a document ID or touch `.agent-output/.next-id` -- identity is supplied above
- Write to any file other than the supplied Output file
- Collapse early unless assigned convergence
- Ignore the declared lens
- Drop open questions silently
```

## Critic / Skeptic Prompt

```
Attack the current frontrunner.
Find missing option families, false equivalences, hidden caller burden, unpriced risks, and premature convergence.
State whether the artifact is GO / NO-GO / GO with OPENQs.
List what changed because of this critique.
```

## Deep Lean Scorecard

Use the relevant rows only — except `GrowthUnit` and `MarginalSurface`, which are required whenever
candidates are compared (state `GrowthUnit: none — one-off decision` when no growth axis applies;
do not simply drop the row, since an absent trajectory reads as "not evaluated", not as "flat").

```
Candidate:
Need:
ExistingSeam:
GrowthUnit:          <the countable thing the need multiplies in, + current count if known>
InterfaceCost:
MarginalSurface:     <Δ per growth unit [Observed, n=3 | Projected]> -> Slope: <flat | rising
                     (linear) | rising (steep, Nx) | compounding (driver)>
CallerBurden:
Reversibility:
Optionality:
ImplementationMass:
FailureContainment:
ZeroRiskFirstStep:
Evidence:
Verdict:             <if bases and slopes both differ, cite crossover G* vs expected horizon>
```

`InterfaceCost`, `MarginalSurface`, and `Slope` are used here with their `deep-modules` meanings —
this template does not redefine them. For interface decisions, replace or supplement this with the
full [`deep-modules`](../../deep-modules/SKILL.md) ISC / ILC / RCK / CHEC comparison and its
[Trajectory rows](../../deep-modules/SKILL.md#trajectory-rows-required-in-every-comparison-scorecard),
which own the counting convention (Observed-preferred, Projected-fallback, never blended) and the
crossover formula.

## LOCKED / OPEN Ledger

```
LOCKED:
- DEC-001: <decision> - basis: <evidence/scorecard>; owner: <who>; downstream gate: <what>

OPEN blockers:
- OPENQ-001: <question> - blocks: <decision/step>; required action: <ask user | measure | prototype | inspect>; stage0_outcome: <1-factual | 2-precedent | 3-user-decision>; discharge: <discharged-via-analyst | collapsed-to-assumption | pending | blocked-to-user>

OPEN nice-to-know:
- OPENQ-002: <question> - safe default: <default>; revisit when: <trigger>

KILLED:
- OPT-003: <option> - killed because: <reason>; revive if: <condition>
```

## Convergence Output

```
Recommendation:
Why this wins:
What was rejected:
Residual risks:
Zero-risk first step:
Phased path:
Discharged before gate (self-resolvable):
User-ratification questions (judgment only):
Next gate:
Outcome: unknown
```

## Checkpoint Summary

Use this for long runs.

```
Checkpoint after round:
New option families since last checkpoint:
Changed rankings:
Consensus falsified? <yes/no + detail>
Surviving options:
Killed options:
LOCKED decisions:
OPEN blockers:
Recommended next action: continue | pivot | converge | ask user
```
