<!-- scorecard-lint: skip -- specification document: defines/discusses the scorecard format rather than instantiating it -->

Contents: [Required seed output schema](#required-seed-output-schema-each-seed-must-produce-all-of-these) · [Seed definitions](#seed-definitions) · [Round 1](#round-1-4--2) · [Round 2](#round-2-2--1--final) · [Vocabulary target](#vocabulary-target)

## Stage 3 — Brainstorming Tournament (4 → 2 → 1)

Run a 4-seed tournament to find the minimal OBS. Delegate each seed to the Analyst as a
subagent **sequentially** (not in parallel — Round 1 requires both of a pair before scoring,
and sequential execution bounds peak context).

**Context strategy:** Each seed delegation MUST include the **Stage 1 summary block**
(`=== STAGE 1 RESULTS ===`) and the **confirmed scope decisions** as its sole interface source.
Seeds MUST NOT re-enumerate the service interface — they reason from the summary only.

Document the tournament in `.agent-output/analysis/<ID>-<service>-obs-tournament.md`.

### Required seed output schema (each seed MUST produce all of these)

```
Seed N: <Strategy Name>

Primitives (<N>):
  [primitive name] — [one-line non-derivability claim]
  ...

Verb coverage (100% required):
  [verb] → [primitive] → [composition expression]
  ...

Mapping (vocabulary targets only; omit for service targets):
  [old construct] → [new primitive or composition] — [kept | folded | removed | added]
  ...

ISC line-items:   [numbered list per the N-variant counting convention]
ILC:              [numbered list]
RCK:              [numbered list]
CHEC:             [numbered list]
IC total:         <number> (band: <low>–<high>)
CA:               <number>  (change amplification: fields added to the substrate)
CCT:              <number>  (common-case tax: items paid on every call)
Lean rung:        [highest rung each primitive earns + one-line justification]
Orthogonality:    [one paragraph per primitive proving non-derivability]
```

A seed that does not produce this schema cannot advance in the tournament.

### Seed definitions

**Seed 1 — Radical Compression**
Prove the absolute floor. Partition all in-scope verbs by independence axis
(write / read-back / render). Collapse everything derivable. Target N=2;
accept N=3 only if independence is provable. **If N=1 is provable (a single primitive
covers all verbs and all render paths), declare it and score it — do not force a higher N.**
Prove non-derivability for each retained primitive.

**Seed 2 — Verb Cluster**
Group in-scope verbs by caller intent (lifecycle / state queries / scene ops / …).
**Start over-decomposed: assign one primitive per cluster before any collapsing.**
Then eliminate non-orthogonal clusters by proving derivability. The deliberate
high-IC start ensures Round 1 contrasts with Seed 1's floor-first approach.

**Seed 3 — Data-Shape First**
Start from the substrate data model (canonical objects from Stage 1). Design the
patch/query schema first, then derive the minimum entry points needed to cover all
in-scope verbs through that schema. Null-sentinel discriminators (create/update/delete
via `oid | null` + `delete` tombstone) collapse multiple wire topics into one input type.
Optimize for CA = 1 (adding a new field touches exactly one schema site).

**Seed 4 — Render-Explicit**
Treat each confirmed render axis as a first-class concern. For each render path from
Stage 1c: is it derivable from the write/read axes? (If the rendering service subscribes
only to its own scene topic, it is NOT derivable — independent axis.) Build the OBS
around the confirmed render-independence result, then find the minimal write/read
primitives for the non-render verbs.

### Round 1 (4 → 2)

Compare Seed 1 vs Seed 2 → pick the winner.
Compare Seed 3 vs Seed 4 → pick the winner.

| Criterion | Role |
|---|---|
| IC (lower wins) | Primary |
| 100% verb coverage | Gate (must pass to advance) |
| Orthogonality proof quality | Tiebreaker |
| CA (lower wins) | Tiebreaker |
| CCT (lower wins) | Tiebreaker |
| Lean rung (higher = leaner) | Tiebreaker |

### Round 2 (2 → 1 — Final)

Compare the two Round 1 winners under the same rubric.

**Always present the Round 2 result to the user before proceeding to Stage 4.** Show:
- The winning OBS: primitives, IC, 3 key design decisions
- The runner-up: primitives, IC, what it trades off
- Your recommendation with a one-sentence rationale

Ask: **"Does this look right, or would you like to adjust before I write the final report?"**
Wait for an explicit answer. On approval, proceed to Stage 4.

---

### Vocabulary target

The tournament mechanics are unchanged: four seeds delegated sequentially, the same Stage 1
summary block and confirmed scope decisions as their sole interface source, the same schema, the
same Round 1 and Round 2 rubric. Document it in
`.agent-output/analysis/<ID>-<vocabulary>-obs-tournament.md`. The following change.

**Verb coverage.** "100% verb coverage" means 100% coverage of the capability baseline — the
operations the vocabulary's corpus and confirmed scope decisions require an author to be able to
express. Under a `basis-redesign` hand-off, that is the Run Declaration's capability baseline.
Each baseline operation maps to a primitive and a composition expression, as before.

**Mapping field.** Every seed also fills the `Mapping` field of the schema: for each construct of
the existing vocabulary, the new primitive or composition that replaces it, marked `kept`,
`folded` (expressed through other primitives), `removed` (no replacement; only legitimate for
constructs with no corpus use) or `added`. Note each mapping that would reject input the existing
vocabulary accepted.

**Seeds 1 and 2** apply unchanged, with the render axis dropped from Seed 1's partition (render
is N/A) and "caller intent" read as the author's intent.

**Seed 3 — Compatibility-Minimal** replaces Data-Shape First. Start from the existing
vocabulary and its corpus. Choose the basis and mapping that minimize the number of existing
constructs whose mapping rejects previously accepted input; every other consideration breaks
ties. Prove non-derivability for each retained primitive and list each remaining break.

**Seed 4 — Intake-Validating** replaces Render-Explicit. Start from what a document may mean,
and push every constraint that can be decided from the document alone into the vocabulary's
grammar, so that invalid documents are rejected at intake rather than later. Build the basis
around that, then find the minimal primitives for the remaining constructs. Report which
constraints moved into the grammar and which mappings they make breaking.

**Round 2 output.** Return the two finalists — winner and runner-up — each with its `Mapping`
field and its scorecard (IC, CA, CCT, lean rung, the orthogonality argument), in addition to the
items listed above. Present them to the user as above. When the tournament was entered from
`basis-redesign`, hand the finalists back to it once the user has seen them; it decides which
finalists go on to its gates, and Stage 4 runs for the finalist the user selects.
