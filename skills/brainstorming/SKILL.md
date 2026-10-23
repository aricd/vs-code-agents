---
name: brainstorming
description: Structured multi-round brainstorming and divergence-to-convergence orchestration for hard design, architecture, strategy, research, product, planning, or implementation problems. Use when the user asks to brainstorm, explore options, run analyst rounds, use critics or skeptics, compare approaches, expand then narrow, use binary analyst pairs, run many delegations or rounds, apply a Deep Lean lens, converge to one decision or ship-set, or produce a ranked backlog. Route away when the task is a pure numeric optimization, a simple one-shot answer, or post-decision plan alignment.
---

# Brainstorming

Run a scalable structured session: expand the option space, preserve useful diversity, falsify premature consensus, then converge to a user-ratifiable output. Compose existing design rubrics instead of restating them: load `../design-rubrics/SKILL.md` to route design-quality questions, keep `../lean-design/SKILL.md` as the ambient minimum-that-works bound, and load `../deep-modules/SKILL.md` for interface or boundary comparisons.

The default lens is **Deep Lean**: prefer the smallest move that preserves the most future power behind the cleanest interface.

## First Response

Start by turning the user's request into a runnable session contract:

```
ROLE: <expertise needed>
OBJECTIVE: <specific decision, ship-set, backlog, or research map>
APPROACH: <topology + rounds + delegation plan + lens>
OUTPUT: <artifact shape>
```

If the user did not specify parameters, choose reasonable defaults and proceed. Ask only for information that changes safety, scope, or the collapse target.

## Required Session Contract

Declare these before delegating or analyzing:

| Parameter | Values | Default |
|---|---|---|
| `collapse_target` | `one-decision`, `ship-set`, `ranked-backlog`, `research-map` | `one-decision` |
| `topology` | `linear-cycles`, `binary-bracket`, `tournament-bracket`, `delphi-blind`, `tiered-adversarial`, `campaign`, `direct` | choose from target and difficulty |
| `rounds` | any positive integer, including very large user-requested counts | `3-4` |
| `delegations` | any user-requested count; no hard cap imposed by this skill | scale to value/risk |
| `roles` | analyst, critic, skeptic, synthesizer, empiricist, domain specialist | topology-specific |
| `visibility` | `blind`, `build-on-prior`, `ledger`, `cross-exam`, `mixed` | `build-on-prior` |
| `lens` | `deep-lean`, `deep-modules`, `lean-design`, domain-specific, metric/evidence | `deep-lean` |
| `scorecard_axes` | countable axes used for convergence | derived from lens |
| `checkpoint_interval` | rounds between progress/convergence checks | every 2-5 rounds for long runs |
| `stop_condition` | user stop, convergence, diminishing returns, budget, metric target | convergence or user stop |
| `artifact_mode` | final memo, append-only ledger, per-round files, bracket tree | topology-specific |
| `session_identity` | shared `ID`/`Origin`/`UUID` + per-delegate filenames | allocated once at Frame (see Session Identity) |

No delegation or round limit is imposed by the skill. For long sessions, require checkpointing and compact artifacts so scale produces insight instead of an unreadable pile.

## Session Identity -- one ID, orchestrator-assigned filenames

A session is **one work chain** under the `document-lifecycle` skill, which owns this rule
(§ID Assignment Rules, "Orchestrated sessions"). The orchestrator:

1. Allocates the session ID **exactly once** at Frame: read `.agent-output/.next-id`, use it,
   increment, write back. Mint one 8-char UUID. No delegate ever touches `.next-id`.
2. Supplies to **every** delegate at creation/initialization: the shared `ID`/`Origin`/`UUID`
   and an **exact output filename** (the Delegation Prompt template carries both fields).
3. Assigns filenames that cannot collide across parallel delegates sharing the ID:
   `NNN-<session-slug>-<round|tier>-<role><seat>.md` (e.g., `081-obs-facade-t0-analyst-3.md`,
   `081-obs-facade-t1-critic-A.md`). The orchestrator owns the seat map; two delegates never
   receive the same filename.

Every session artifact -- analyst reports, critic findings, checkpoints, the convergence memo --
carries the same `ID`/`Origin`/`UUID` header. Downstream consumers (a plan created from the
session) inherit the chain identity per `document-lifecycle`.

## Topology Router

Choose the smallest topology that fits the user's value/risk:

| Situation | Use | Collapse target |
|---|---|---|
| One hard design fork, medium blast radius | `linear-cycles` | `one-decision` |
| Very hard problem where local synthesis should happen before global synthesis | `binary-bracket` | `one-decision` or `ship-set` |
| Very hard problem, want fixed pairwise elimination with divergence re-injected each tier | `tournament-bracket` | `one-decision` or `ship-set` |
| Need independent views without consensus contamination | `delphi-blind` | `one-decision`, `ship-set`, or `research-map` |
| Huge entangled architecture problem | `tiered-adversarial` | `ship-set` |
| "Where does this hurt?" or broad opportunity discovery | `campaign` | `ranked-backlog` |
| User wants quick ideation, low risk | `direct` | `research-map` or lightweight decision |

Read `references/topologies.md` when setting up anything beyond `direct` or when the user asks for binary pairs, many rounds, many delegations, or a campaign.

## Load-Bearing Rules

Keep these in every non-trivial session:

1. Separate expansion from convergence. The convergence phase does no new design.
2. Include a skeptic or falsification slot empowered to reject the frontrunner.
3. Declare the collapse target up front. A backlog is not a decision.
4. Keep a `LOCKED` / `OPEN` ledger; split open questions into blockers and nice-to-know. On the blocker row, further split by **resolution owner** — self-resolvable (measure/inspect/prototype; = Stage-0 Outcome-1/2) vs user-judgment (preference/priority/risk/scope; = Stage-0 Outcome-3). Self-resolvable blockers are discharged before the gate, not surfaced to the user.
5. Use a countable or evidence-based convergence basis, not taste.
6. Bind the result to the next gate: user decision, plan, implementation, experiment, or follow-on session.
7. Prefer a phased recommendation with a zero-risk or low-risk first step.
8. Track outcomes when known: `Outcome: shipped (<commit>) | reversed | superseded | abandoned | unknown`.

## Deep Lean Lens

When `lens: deep-lean`, evaluate candidates through both minimum-viable action and interface depth:

- `Need`: does this need to exist now?
- `ExistingSeam`: can an existing boundary/tool/artifact carry it?
- `InterfaceCost`: count caller-handled errors, information leakage, interface surface, and required caller knowledge when comparing surfaces.
- `CallerBurden`: what must future users know, sequence, configure, or recover from?
- `Reversibility`: can the first step be undone or extended without regret?
- `Optionality`: does the design preserve future routes without adding speculative surface now?
- `ImplementationMass`: what code/process/artifact mass is introduced?
- `FailureContainment`: where do errors land and who must handle them?
- `ZeroRiskFirstStep`: what can ship or be decided safely first?

For interface decisions, load `../deep-modules/SKILL.md` and use its scorecard. For build-vs-skip or scope trimming, load `../lean-design/SKILL.md`. For mixed design-quality questions, load `../design-rubrics/SKILL.md` first.

## Session Protocol

1. **Frame.** State the session contract, known constraints, collapse target, lens, and artifact mode. Allocate the session identity (one ID/UUID via `document-lifecycle`; see Session Identity) before any delegation.
2. **Foundation.** Create or identify the shared substrate: problem statement, constraints, current evidence, terms, and prior decisions.
3. **Expand.** Generate structurally different options and orthogonal axes. Avoid variations on one idea until at least two radically different shapes exist.
4. **Develop.** Assign analysts to deepen different families, assumptions, risks, or evidence paths.
5. **Falsify.** Run a skeptic/critic pass that attacks the frontrunner, checks missing categories, and tries to prove the consensus wrong.
6. **Prune.** Kill, merge, or promote options using the lens. Record why each non-survivor was rejected.
7. **Converge.** Produce the scorecard/evidence basis, decision ledger, residual OPENQs, and phased recommendation. Do not introduce new designs here.
**7a — Discharge (Stage-0 re-triage).** Before emitting a `GO-with-OPENQs`, route every OPEN **blocker** through the Stage-0 Routing Gate — see [`../no-silent-assumptions-software-planning/SKILL.md#inherited-openqs`](../no-silent-assumptions-software-planning/SKILL.md#inherited-openqs). Self-resolvable blockers (Outcome-1/2) are discharged — or attempted-and-blocked — before the gate; only Outcome-3 blockers may appear in a surfaced `GO-with-OPENQs`. This step scopes to **blockers** only; nice-to-know OPENQs keep their safe default and stay deferred.
8. **Gate.** State GO / NO-GO / GO-with-OPENQs and the required next action. **Trigger brainstorm-retro:** load `../mini-retro/SKILL.md` §Brainstorming Session Retrospective and write `.agent-output/mini-retro/<session-id>-brainstorm-retro.md` before the next handoff. This is the brainstorming analogue of the pre-DevOps mini-retro trigger — first-hand, no user prompt, authored at the session's natural conclusion boundary.

Use `references/artifact-templates.md` for ledgers, scorecards, critic prompts, and final outputs.

**Rubric preflight (deep-lean / deep-modules / lean-design lens).** When the session contract
declares `lens: deep-lean`, `deep-modules`, or `lean-design`, run the
[Rubric Preflight Checklist](../design-rubrics/SKILL.md#rubric-preflight-checklist):
- **P1** at step 4 (Develop) — before any analyst delegation
- **P3** at step 7 (Converge) — before publishing the scorecard or verdict

For single-actor sessions (no analyst delegation), collapse to the terse form:
`Preflight: gate ✓ zone ✓ conventions ✓(block internalized) | scores itemized + direction-audited | firewall ✓`

## Scaling Rules

For large sessions:

- Accept user-requested scale, including 100 rounds or unbounded delegations.
- Add checkpoints every 5-10 rounds or sooner when synthesis artifacts become hard to inspect.
- Carry forward a compact state: surviving options, killed options, locked decisions, open questions, evidence gaps, and next-round assignments.
- Use tree or bracket artifacts for many delegations; avoid one final synthesizer reading hundreds of raw outputs without intermediate consolidation.
- Watch for diminishing returns: if two checkpoints add no new option families, no changed rankings, and no new falsifications, recommend convergence while allowing the user to continue.

## Anti-Patterns

- Backlog masquerading as a decision: label it as `ranked-backlog` and require a follow-on decision pass.
- Premature consensus: never skip the skeptic slot on important work.
- Fan-out without collapse: parallel analyses must rejoin through a synthesizer or critic.
- Iteration without a stop condition: declare the target, checkpoint interval, and convergence signal.
- Taste-based convergence: use counts, evidence, rubrics, measurements, or explicit tradeoffs.
- Skill overlap: route pure metric tuning to an optimization skill; route a small A-vs-B interface verdict directly to `deep-modules`; route post-decision alignment to a planning/alignment skill.
- Self-resolvable OPENQ surfaced as a gate decision: routing an Outcome-1/2 blocker to the user as if it required their judgment instead of discharging it via Analyst or collapsing it to an `ASSUMPTION-*`.

## Output

For lightweight work, answer inline. For substantial sessions, emit:

```
Session Contract
Topology and Parameters
Expansion Summary
Critic / Skeptic Findings
Convergence Scorecard
LOCKED / OPEN Ledger
Recommendation
Zero-Risk First Step
Next Gate
Outcome: unknown
```
