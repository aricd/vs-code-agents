---
name: basis-redesign
description: >-
  Re-imagines or compresses an existing DSL, grammar, schema or API vocabulary while keeping
  generated output identical and prior schema versions accepted. Use to redesign or simplify a
  DSL, prove which constructs are redundant, find a minimal basis, or move validation to intake.
  Runs staged, evidence-gated work: scope and run declaration, catalog, fixed-reference necessity
  ladder, joint removal, re-imagining, intake constraints, realization, output-equivalence and
  compatibility gates, report. Designing a new basis for a service, without these gates, is
  obs-create's job.
metadata:
  version: "2.0"
---

# Basis Redesign

Drives one program over an existing vocabulary -- a DSL, grammar, schema or API surface: discover
its intent, function and scope; prove which constructs are redundant; re-imagine how the intent is
accomplished; build the redesign; gate it on identical output and on compatibility with prior
schema versions; and add constraints validated at intake. This file holds the rules that hold in
every stage, the stage map, and an index of every file a run reads. Each stage's procedure lives
in its own file under `references/`; concepts owned by other skills are linked, never restated.
All paths below are relative to this skill's directory.

## Must-hold rules (every stage, every run)

- **(a) Fixed reference set.** When testing whether construct X is composable from the others,
  test against the **fixed original full set minus X** -- never a working set from which other
  "redundant" constructs were already removed. A shrinking reference set is order-dependent:
  constructs that cover each other can each look removable alone, yet removing more than one of
  them loses coverage. Removing several constructs together is decided only at stage 04.
- **(b) Output equivalence governs finality, at the declared strength.** Under
  `equivalence_strength: hard` (the default), no removal or redesign verdict is final until the
  declared oracle has executed and passed (stage 08), and stage 04 admits only compositions whose
  oracle status is `passed`. Under `advisory`, stage 04 also admits `unproven` compositions; any
  verdict whose stage-08 oracle has not executed and passed, or that rests on an `unproven`
  composition, is recorded as `output-unverified` and is never reported as final. Script output
  is a candidate set, never a verdict.
- **(c) The declared compatibility contract is binding** (stage 09). Every change gets exactly
  one outcome: `demote`, `break` or `additive`. A `break` needs explicit user approval that lists
  the affected corpus files, obtained **before stage 08** -- at stage 05 for removals, at stage
  06 for intake tightening.
- **(d) Exactly one disposition per construct, by precedence** (stage 03): `Dead`, then
  `Exchangeable`, then `Unproven`, then `Fold-in candidate`, then `Essential` -- the first that
  matches wins. A composition that was found but has not passed yields `Unproven`, never
  `Essential`. The overlay flags `guardrail` and `keep` are recorded separately; they are not
  dispositions.
- **(e) Composition is judged only under the declared composition relation** (stage 01).
  Host-language escape hatches do not count unless the run declaration says they do.
- **(f) A `snapshot` run never mandates removal.** Only `compress` and `redesign` runs produce
  gated verdicts.
- **(g) Guarantee guardrail.** A construct flagged guardrail-held is in every candidate remaining
  set and is never removed or altered by any verdict without explicit user approval that names
  the guarantee.

## Stage map

**Run goal**, declared at stage 01: `snapshot` runs stages 01-04 and 10; `compress` runs every
stage except the stage-05 tournament; `redesign` runs every stage.

**Run Declaration** -- defined in stage 01, confirmed by the user, consumed by stages 02-10. Its
fields: `run_goal` (must declare); the capability-baseline corpus; the vocabulary layers in
scope; the version notion(s) and compatibility contract; `equivalence_level` (`byte`,
`normalized` with the normalizations listed, or `behavioral`); `equivalence_strength` (`hard` by
default, or `advisory`); the oracle and its pinned baseline commit; the rung-2 check (the oracle
by default, or a declared semantic check when the oracle compares bytes); the composition relation
(escape hatches excluded by default); `transitive` (must declare); `realization_mode` (`in-run`
by default, or `hand-off`); `finalists_to_gate` (default 1; the compression candidate counts
toward it); and the budget. A stage may not start while any field it consumes is undeclared.

| Stage | File | Entry criterion | Exit criterion | User checkpoint |
|---|---|---|---|---|
| 01 Intent and scope | [references/01-intent-scope.md](references/01-intent-scope.md) | Target vocabulary named; the user's criterion quoted verbatim | Intent, function and scope brief; vocabulary-layer table with one in/out decision per layer; Run Declaration complete | Confirms the Run Declaration before stage 02 |
| 02 Catalog | [references/02-catalog.md](references/02-catalog.md) | Run Declaration confirmed | Uid-keyed catalog; atomic behaviors (including ordering, atomicity and failure semantics) at the stated granularity; pilot run and projected delegation count | Confirms the budget after the pilot |
| 03 Necessity ladder | [references/03-necessity-ladder.md](references/03-necessity-ladder.md) | Catalog complete; budget confirmed (the pilot family runs first) | Blind forward and reverse passes reconciled; one disposition plus overlay flags per construct; ladder-verdict record written | Approves any guardrail exception, naming the guarantee |
| 04 Joint removal | [references/04-joint-removal.md](references/04-joint-removal.md), [scripts/joint_removal.py](scripts/joint_removal.py) | Reconciled ladder-verdict record | Every inclusion-minimal valid remaining set per component, ties included, or "joint minimality not established above N" | None |
| 05 Re-imagine | [references/05-reimagine.md](references/05-reimagine.md) | Stage-04 bases; `run_goal` is `compress` or `redesign` | Gating candidates named (compression candidate and/or tournament finalists, up to `finalists_to_gate`), each with an old -> new mapping | Chooses a basis when the scorecard does not; approves removal breaks with affected-file lists |
| 06 Intake constraints | [references/06-intake-constraints.md](references/06-intake-constraints.md) | Gating candidates named, or a constraint-only `compress` run | Enforcement inventory; admitted constraint changes applied to each candidate, each classed `break` or `additive` | Approves intake-tightening breaks with affected-file lists |
| 07 Realize | [references/07-realize.md](references/07-realize.md) | Candidates with their stage-06 changes | An executable candidate (front end plus corpus translator) per gating candidate, or a hand-off whose gate status is `pending` | None |
| 08 Output equivalence | [references/08-output-equivalence.md](references/08-output-equivalence.md) | Realized candidate; oracle and pinned baseline declared, or `oracle: none` | Executed oracle verdict (differing files exactly equal the approved-break list), or `output-unverified` under `oracle: none` | None |
| 09 Compatibility | [references/09-compatibility.md](references/09-compatibility.md) | Stage-08 verdict | One outcome per change, per version notion; realized changes match the approvals | None; a mismatch returns to the approving stage |
| 10 Report | [references/10-report.md](references/10-report.md) | Every stage the run goal requires is done | Per-construct rows, tied bases, gating candidates with gate status, the `Unproven` list | Reads the report |

Irredundant bases can differ in cardinality (`{NAND}` versus `{AND, NOT}`). Cardinality is
informational: stage 04 reports every tied basis, and choosing among them belongs to stage 05,
with a `deep-modules` scorecard, or to the user.

## File index

Every file a run reads, in this skill or another. Stage files are linked in the stage map above;
read each one on entering its stage.

| File | Read when |
|---|---|
| [scripts/joint_removal.py](scripts/joint_removal.py) | Stage 04: run on the reconciled ladder-verdict record (path relative to this skill) |
| [../literal-intent-fidelity/SKILL.md](../literal-intent-fidelity/SKILL.md) | Stage 01: its Criterion Ledger (quote, test, proxy) is normative for scope and layer decisions |
| [../obs-create/SKILL.md](../obs-create/SKILL.md) | Stage 02: its Key definitions are the source of the granularity rule; stage 05: its vocabulary-target mode |
| [../deep-modules-interface-cost-audit/SKILL.md](../deep-modules-interface-cost-audit/SKILL.md) | Stage 02: batching (Step 2); stage 03: dual-pass, critique and reconciliation mechanics, with its Reconciliation Guardrail (Step 3) |
| [../requirements-enforcement/SKILL.md](../requirements-enforcement/SKILL.md) | Stage 03: sourcing the guarantees behind the `guardrail` flag, with their maturity |
| [../lean-design/SKILL.md](../lean-design/SKILL.md) | Stages 03 and 06: the rung ladder and the guardrail classes |
| [../deep-modules/SKILL.md](../deep-modules/SKILL.md) | Stages 03, 05 and 06: the scorecard for keep-vs-fold, basis selection and extend-vs-add |
| [../obs-create/references/stage-3-tournament.md](../obs-create/references/stage-3-tournament.md) | Stage 05, `redesign` runs: the tournament that receives the hand-off payload |
| [../obs-create/references/stage-1-interface-analysis.md](../obs-create/references/stage-1-interface-analysis.md) | Stage 05, `redesign` runs: the vocabulary results block the hand-off payload is rendered into |
| [../brainstorming/SKILL.md](../brainstorming/SKILL.md) | Stage 05, only when broader divergence is requested |
| [../functional-core/SKILL.md](../functional-core/SKILL.md) | Stage 06: the intake principle ("parse, don't validate", Operating rules) |
| [../prototype/SKILL.md](../prototype/SKILL.md) | Stage 07: build discipline for the realized candidate |
| [../prototype/PARITY.md](../prototype/PARITY.md) | Stages 07 and 08: name the authority; drive the real code on both sides |
| [../../scripts/validate-scorecard.ps1](../../scripts/validate-scorecard.ps1) | Stages 03 and 06: lint any file that holds a `deep-modules` scorecard |

## Relationships

- **`obs-create`** designs a new orthogonal basis, for a service or a vocabulary, without
  equivalence or compatibility gates. Stage 05 sends its tournament a hand-off payload (vocabulary
  layers, catalog, dispositions with overlay flags, stage-04 bases, confirmed scope decisions,
  capability baseline) and receives the winner and runner-up, each with an old -> new construct
  mapping and its tournament scorecard. Renaming that tournament file, or changing either
  payload, is a breaking change for both skills.
- **`brainstorming`** supplies generic divergence at stage 05 when requested; this skill does
  not restate it.
- **`deep-modules-interface-cost-audit`** answers a different question -- interface cost of what
  exists, not redundancy of what exists. Run both when both matter; stages 02-03 reuse its
  batching and dual-pass mechanics.
- **`lean-design`** is the forward build gate. Stage 03 asks its admission question in reverse --
  can an existing construct be removed? -- and keeps the executed-evidence bar: a composition
  supports removal only after it executes under the declared oracle and passes. Stage 06 runs the
  forward admission ladder for new constraint constructs.
- **`deep-modules`** owns the CHEC/ILC/ISC/RCK scorecard used wherever two shapes are compared.
- **`requirements-enforcement`** owns guarantees; the `guardrail` flag cites them.
- **`literal-intent-fidelity`** owns the scope discipline stage 01 applies.
- **`functional-core`** owns the intake principle stage 06 applies.
- **`prototype`** and its `PARITY.md` own build and differential-harness discipline for stages
  07-08.

These sibling links assume the whole `skills/` tree is deployed together; an upload of this skill
on its own breaks them.
