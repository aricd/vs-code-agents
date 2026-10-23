# Stage 05 — Re-imagine and select candidates

Contents: [Entry and exit](#entry-and-exit) · [Step 1 — Choose the compression basis](#step-1--choose-the-compression-basis) · [Step 2 — The compression candidate](#step-2--the-compression-candidate) · [Step 3 — The tournament (`redesign` only)](#step-3--the-tournament-redesign-only) · [Step 4 — Name the gating candidates](#step-4--name-the-gating-candidates) · [Step 5 — User checkpoint](#step-5--user-checkpoint) · [Payloads](#payloads)

Stages 01-04 established what the vocabulary is and which constructs can leave together. This
stage decides what the run will actually build and gate. Everything stage 07 realizes and
stages 08-09 gate is named here, together with the mapping from old constructs to new ones.

## Entry and exit

- **Entry:** the stage-04 bases exist; `run_goal` is `compress` or `redesign`. A `snapshot` run
  never enters this stage.
- **Exit:** a list of **gating candidates**, at most `finalists_to_gate`, each with an
  old -> new mapping and its approved-break list (possibly empty). Every candidate then passes
  through stages 06-09 with its mapping.

## Step 1 — Choose the compression basis

Stage 04 reports every inclusion-minimal basis per component. Pick one basis per component; the
combination is the **compression basis**.

1. One basis in a component: take it.
2. Several tied bases: compare them with a [`deep-modules`](../../deep-modules/SKILL.md)
   scorecard, one shape per basis, scoring what a corpus author must know to use the result.
   Cardinality alone never decides; a larger basis can be the shallower interface. If the
   scorecard does not separate them, ask the user at the checkpoint and show both.
3. A basis marked `output_unverified` is eligible only under `advisory`, and everything built
   on it stays `output-unverified` until stage 08 executes and passes.
4. Constructs that are `Fold-in candidate` are not in any stage-04 removal set. Fold one only
   when its neighbor's fold was checked at stage 03 and the user agrees; a fold is recorded as
   a mapping entry, not as a removal.

A component whose message says "joint minimality not established above N" offers no basis to
choose; its constructs stay in every candidate unless the user narrows the scope and stage 04
is rerun.

## Step 2 — The compression candidate

The compression candidate is the current vocabulary with the removed constructs **demoted**:
each removed construct leaves the core and stays acceptable as a surface form that lowers into
the remaining core, using the passed composition from stage 03. Compatibility is preserved, and
stage 08 verifies it. A `demote` whose mapping is a lowering is accepted only after the
lowering is shown injective on the corpus: lowering then lifting reproduces every authored
document, including documents that already contain the lowered form's literal or token.

For every removed construct, decide with the user whether it is a `demote` (default) or a
`break` (the surface form is dropped, so inputs using it are rejected):

| Removed construct | Default outcome | Approval needed here |
|---|---|---|
| Used in the corpus, composition passed | `demote` | None |
| Used in the corpus, user wants it gone | `break` | Yes: the affected corpus files, listed by path |
| `Dead` (no corpus use, no cited need) | `break` -- removing it changes the accepted language | Yes: state that no corpus file is affected and what input outside the corpus would now be rejected |

Record each approval with the construct, the affected files, the approving user's words and the
date. A break the user has declined by standing instruction is recorded as `declined` (see
[06-intake-constraints.md](06-intake-constraints.md#step-5--classify-and-approve)); it is not
built, its construct stays, and no per-break approval is requested. **An approval obtained after
stage 08 does not count.** Stage 08 compares the differing files with this list exactly, so an
unlisted difference reverts the verdict.

The compression candidate's mapping marks a `demote` as `folded` (the surface form still lowers
into the remaining core) and an approved `break` as `removed`, whether or not the construct is
used in the corpus. The "`removed` only for a `Dead` construct" rule in Step 3 applies to
tournament finalists, not to this candidate.

### Constraint-only run

A run that adds constraints without removing anything is `run_goal: compress` with an **empty
removal set**. Skip Steps 1 and 3: the compression candidate is the current vocabulary plus the
stage-06 changes, with an empty mapping (every construct kept). It is the only gating candidate
and it still goes through stages 06-09.

## Step 3 — The tournament (`redesign` only)

Skip this step for `run_goal: compress`.

The tournament is not run here. Send the payload described under
[Payloads](#payloads) to the vocabulary-target mode of
[`obs-create`](../../obs-create/SKILL.md), whose tournament procedure is in
[stage-3-tournament.md](../../obs-create/references/stage-3-tournament.md); read its
"Vocabulary target" section before sending. `obs-create` runs all of its Stages 0-4 on this
hand-off, in this order:

1. **Stage 0** — vocabulary mode, with the vocabulary name and source location from the payload.
2. **Stage 1** — the payload is the results block; it is not re-enumerated, but the user is
   shown it and asked to confirm it.
3. **Stage 2** — the scope decisions confirmed at stages 01-03 are presented, and the user is
   asked only whether any changed.
4. **Stage 3** — the tournament. Its finalists, each with a mapping, come back here once the
   user has seen them. Do the checks below and Steps 4-5, up to the user checkpoint.
5. **Stage 4** — after the user selects the tournament finalist(s) to gate at the checkpoint
   (one when `finalists_to_gate` is 1, otherwise each one selected), and before stage 06
   starts, run it per selected finalist. Its report, including the grammar/IR sketch, is
   kept with the stage-05 record.

When the user asks for broader divergence than four
seeds give, also run [`brainstorming`](../../brainstorming/SKILL.md) on the same payload and
treat its candidates as additional seeds; do not run it otherwise.

Receive the finalists back and check them before accepting:

- Each finalist's mapping covers **every** in-scope construct exactly once, marked `kept`,
  `folded`, `removed` or `added`.
- `removed` appears only for a `Dead` construct (this rule is for tournament finalists; the
  compression candidate's approved breaks are covered in Step 2). A used construct marked
  `removed` is a mapping defect; send the finalist back.
- Every mapping entry that rejects input the current vocabulary accepts is a `break`. List the
  affected corpus files for each, using the capability-baseline corpus, and obtain approval as
  in Step 2.
- Every `guardrail: held` and `keep: depth` construct is present and unaltered. Altering one
  needs an explicit user approval naming the guarantee.

## Step 4 — Name the gating candidates

The pool is the compression candidate and, for `redesign`, the tournament finalists. Name at
most `finalists_to_gate`, in this order.

| `run_goal` | Order of selection |
|---|---|
| `compress` | 1. The compression candidate. 2. Any further tied basis from Step 1, in scorecard order, only when `finalists_to_gate` is above 1 and the user wants them gated |
| `redesign` | 1. The tournament winner. 2. The compression candidate, when its removal set is non-empty. 3. The runner-up |

With a budget of 1, `redesign` gates the tournament winner and `compress` gates the compression
candidate. The compression candidate counts toward the budget. A candidate left out is listed
in the report as `not gated`, with its mapping, so the choice is visible.

## Step 5 — User checkpoint

Present in one message: the compression basis and, where tied bases existed, the scorecard or
the choice asked for; each gating candidate with its mapping; every break proposed so far with
its affected-file list; and the candidates left out. Do not start stage 06 until the user has
approved the breaks and confirmed the candidate list.

## Payloads

The two payloads below are the whole contract with the tournament. Renaming the tournament
file, or changing either payload, is a breaking change for both skills.

**Sent to the tournament** -- the tournament's Stage 1 results block, built from stages 01-04.
Render the parts into the vocabulary results block of
[stage-1-interface-analysis.md](../../obs-create/references/stage-1-interface-analysis.md)
(`=== STAGE 1 RESULTS: <VocabularyName> Vocabulary Inventory ===`) as follows; the block's
`GRAMMAR RULES`, `IR NODE KINDS`, `CODEGEN TARGETS`, `HOST-LANGUAGE-DEFINED VOCABULARY` and
`CANONICAL CONSTRUCTS` sections come from the catalog, and `RENDER PATHS` stays
`N/A — vocabulary target`. The rest are appended as sections of that block:

| Part | Content | Block section |
|---|---|---|
| Vocabulary layers | The stage-01 layer table, in/out per layer | `VOCABULARY LAYERS` |
| Catalog | The stage-02 catalog: uids, atomic behaviors, corpus-use counts | The inventory sections above (one line per uid, with its layer and corpus-use count) |
| Dispositions | Each construct's disposition and both overlay flags, with the evidence ids | `DISPOSITIONS` |
| Bases | Every stage-04 basis per component, ties included, with `output_unverified` marks | `BASES` |
| Scope decisions | The decisions the user confirmed at stages 01-03, verbatim | `CONFIRMED SCOPE DECISIONS` |
| Capability baseline | The Run Declaration's capability-baseline corpus; it defines "100% coverage" for the tournament | `CAPABILITY BASELINE` |

**Received from the tournament:**

| Part | Content |
|---|---|
| Finalists | The winner and the runner-up |
| Mapping | Per finalist, old -> new for every construct, marked `kept`, `folded`, `removed` or `added`, with each input-rejecting entry noted |
| Scorecard | Per finalist, the tournament scorecard and the orthogonality argument |

Hold the received scorecards as evidence for the report; do not recompute them here.
