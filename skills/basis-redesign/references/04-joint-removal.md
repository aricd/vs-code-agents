# Stage 04 — Joint removal

Contents: [Entry and exit](#entry-and-exit) · [Why a joint search](#why-a-joint-search) · [Input record](#input-record) · [What the script derives](#what-the-script-derives) · [Validity and the closure](#validity-and-the-closure) · [Components and enumeration](#components-and-enumeration) · [Running the script](#running-the-script) · [Output](#output) · [Reading the result](#reading-the-result)

Stage 03 tests each construct against the full set. Constructs that cover each other can each
look removable alone, yet removing both loses coverage. This stage decides which constructs can
be removed **together**, by searching the whole alternatives record for every smallest set that
still reaches all that must be reached. Its output is a set of candidates; it never says a
removal is correct.

## Entry and exit

- **Entry:** the reconciled ladder-verdict record from stage 03, with any guardrail exception
  approved.
- **Exit:** for every component, every inclusion-minimal valid remaining set, ties included, or
  the message "joint minimality not established above N". No user checkpoint.

Before running, confirm the record's `transitive` and `equivalence_strength` equal the Run
Declaration's. The script cannot check that; a mismatch silently changes which results appear.

## Why a joint search

With `A` composable from `B` and `B` composable from `A`, both are `Exchangeable`, but the set
without both has lost the capability. A greedy pass that removes one after another depends on
order, and a pass that tests each against a shrinking set can end with the capability gone. This
stage works from the **fixed** alternatives in the record, so the answer does not depend on
order, and "R = nothing" is invalid because nothing is reachable from an empty start.

## Input record

The ladder-verdict record described in
[03-necessity-ladder.md](03-necessity-ladder.md#ladder-verdict-record): `schema_version` (`1`),
`in_scope`, `transitive`, `equivalence_strength`, optional `limit` (default `20`), and one entry
per construct with `uid`, `disposition`, `rung`, `overlays`, `evidence` and `alternatives`.
Every `in_scope` uid needs exactly one construct entry, every provider must be an in-scope uid,
a construct cannot provide itself, and each disposition must agree with its alternatives (for
example, `Exchangeable` needs a `passed` alternative). The script rejects a record that does
not.

Each alternative belongs to one construct and is one **AND-set**: every provider in it is
needed together. It is backed by one composition with an `evidence_id` and an `oracle_status`.
That one composition covers all of the construct's atomic behaviors together.

A removal that needs no replacement provider (deletion, refill, no-op) still needs a non-empty
AND-set, because the script rejects an empty provider set. Declare a pseudo-construct (for
example `NOOP`) in `in_scope`, with disposition `Essential` and no alternatives so it is forced
into every remaining set, and use it as the sole provider of that removal; say in the evidence
that the pseudo-construct stands for "nothing" and is not a real construct. The same record
shape expresses an oracle-blind construct (see
[03-necessity-ladder.md](03-necessity-ladder.md#the-ladder)) with `oracle_status: unproven`.
The pseudo-construct is a record device only: leave it out of the catalog, the stage-05 mapping
check and the report's construct table.

## What the script derives

None of these is part of the input.

- **Admitted alternatives.** Under `equivalence_strength: hard`, only alternatives with status
  `passed`. Under `advisory`, `passed` and `unproven`. A `failed` alternative is never admitted.
- **Forced-include set F** = `Essential` ∪ `Fold-in candidate` ∪ guardrail `held` ∪ keep
  `depth`, plus `Unproven` constructs under `hard`. A Fold-in candidate is irreproducible:
  stage 05 may fold it, but this stage never removes it. A `Dead` construct carrying a held
  guardrail or a depth keep is also forced.
- **Coverage target T** = in-scope − `Dead`. A Dead construct need not stay reachable; its
  removal changes the accepted language and is routed to stage 09. A Dead construct can still
  appear in a remaining set when an admitted alternative needs it as a provider.

## Validity and the closure

A remaining set R is **valid** if and only if F ⊆ R and the least fixpoint from R covers T.

- The **least fixpoint** starts from R and repeatedly adds any construct that has an admitted
  alternative wholly contained in the current set, until nothing is added. It starts from R, not
  from the full set; starting from the full set (a greatest fixpoint) would make the empty set
  look valid.
- With `transitive: false` the closure is **one step**: R plus every construct that has an
  admitted alternative contained in R. A construct reachable only through another composed
  construct is then not covered.

Validity is monotone: any superset of a valid set is valid. That is what makes "inclusion-minimal"
well defined and lets the search skip supersets.

## Components and enumeration

Build a graph over the in-scope constructs: connect each construct to every provider in every
admitted alternative. Each connected component is independent, so each is searched alone and
reported alone.

Per component, enumerate **every inclusion-minimal valid R**: a valid set with no valid proper
subset. Report all of them, including ties. Irredundant bases can differ in cardinality
(`{NAND}` versus `{AND, NOT}`); cardinality is shown but informational. The search is exhaustive
up to the record's `limit`, counted in constructs per component. A component with more
constructs than the limit is **not** searched and **not** truncated: the output carries the
message "joint minimality not established above N" and no bases for it. Raise `limit` and rerun
if the cost is acceptable, or narrow the scope at stage 01; do not report minimality for that
component.

## Running the script

The path is relative to the skill directory. Python 3, standard library only.

```
python scripts/joint_removal.py <ladder-verdict-record.json>
```

The file is parsed as JSON and treated as data only; nothing in it is evaluated or executed.
Exit status `0` means a result was produced (a component over the limit still exits `0`). Exit
status `2` means the input was unreadable, not valid JSON, or violated the schema; the message
on standard error names the offending record, for example
`constructs[3] (uid 'window_sum').alternatives[0].oracle_status: must be one of ...`. Fix the
record and rerun.

Tests: `python -m pytest scripts/test_joint_removal.py -q`.

## Output

JSON on standard output:

| Field | Content |
|---|---|
| `status` | Always `candidates-only` |
| `equivalence_strength`, `transitive`, `limit` | Echo of the settings used |
| `forced_include` | F, in `in_scope` order |
| `coverage_target` | T |
| `dead_routed_to_compatibility` | The Dead constructs, for stage 09 |
| `admitted_alternatives` | Each admitted alternative: `construct`, `providers`, `evidence_id`, `oracle_status` |
| `components[]` | `constructs`, `forced_include`, `minimality_established`, `message` (null unless over the limit), and `bases[]` |
| `bases[]` | `members` (the remaining set), `cardinality`, `output_unverified` |

`output_unverified` is `true` when the basis is valid only because of an `unproven` alternative:
the same set would not cover T if only `passed` alternatives counted. It can occur only under
`advisory`.

## Reading the result

- The output is a **candidate set**. Whether a removal is right is decided by the executed
  oracle at stage 08 under the declared strength, never by this stage.
- Choosing among tied bases belongs to stage 05, with a
  [`deep-modules`](../../deep-modules/SKILL.md) scorecard, or to the user. Do not choose by
  cardinality alone; a larger basis can be the shallower interface.
- A basis marked `output_unverified` may be shown, but never as final, and the report lists it
  with the `Unproven` constructs it relies on.
- Rerun the script whenever the record changes, for example when execution moves an `Unproven`
  construct to `Exchangeable`.
- A component with nothing forced and nothing to cover (for example a lone Dead construct)
  reports one empty basis: nothing needs to remain for it.
