# Stage 02 — Catalog

Contents: [Entry and exit](#entry-and-exit) · [Catalog record](#catalog-record) · [Granularity rule](#granularity-rule) · [Atomic behaviors](#atomic-behaviors) · [Corpus use](#corpus-use) · [Pilot, projection and budget](#pilot-projection-and-budget) · [Batching and merging by uid](#batching-and-merging-by-uid)

This stage lists every construct in scope, at one stated grain, with the behaviors a
replacement would have to reproduce. Stage 03 judges each entry; the catalog decides what
"each" means, so a grain mistake here is repeated in every later verdict.

## Entry and exit

- **Entry:** the Run Declaration is confirmed.
- **Exit:** a uid-keyed catalog covering every in-scope layer; atomic behaviors per construct,
  including ordering, atomicity and failure semantics; corpus-use counts; a pilot result and a
  projected delegation count; the user's confirmation of the budget.

## Catalog record

One record per construct. Fields:

| Field | Content |
|---|---|
| `uid` | Content-addressed: `<layer>:<kind>:<qualified name>`, plus `#<variant>` for a variant entry. Stable across passes and batches |
| `layer` | One of the in-scope layers from the Run Declaration |
| `kind` | Keyword, node type, operator, directive, builtin, policy, and so on |
| `location` | File and line of the definition, and of the IR node and code generator that handle it |
| `group` | For a variant entry, the `uid` of the construct it varies |
| `atomic_behaviors` | The list defined under [Atomic behaviors](#atomic-behaviors) |
| `corpus_uses` | Count over the capability-baseline corpus, with the query that produced it |
| `cited_need` | A document, requirement or consumer that says the construct must exist, or `none` |

A **cited need** states that the construct must exist for a reason other than its own
existence. The construct's own unit test is not a cited need, and neither is a marker-level
registry row that merely lists it; record those as `none`.

## Granularity rule

This rule is the same counting convention the `obs-create` skill uses for interface surface.
Its Key definitions count an interface surface as entry points plus named types plus
**N-variant union members** plus return shapes, and score an N-variant discriminated union as N
items and an `x | null` sentinel as one
([`obs-create` Key definitions](../../obs-create/SKILL.md#key-definitions)). Applied to a
vocabulary:

> A construct is catalogued as one entry per **separately selectable behavior**. A selector
> with N variants that behave differently yields N entries (one per variant, each carrying the
> selector as `group`). A selector whose variants differ only in a data value, and an optional
> element that is present or absent, yield one entry.

The test for "behave differently" is the atomic-behavior list: two variants are separate
entries if their lists differ in any item, including ordering, atomicity or failure semantics.
Differing only in a literal, a name or a number is not a difference, with one exception: when a
value's literal form can collide with a literal an author can write (a sentinel or default that
a document may also contain), the variants stay separate entries, because a lowering that
swaps the value for the sentinel cannot tell the two apart.

**Worked example 1 — a variant selector.** An `emit` node takes `kind: file | table | message`.
File emission writes to disk and fails on a missing directory; table emission appends rows
atomically; message emission is fire-and-forget. Three different behavior lists, so three
entries: `grammar:node:emit#file`, `emit#table`, `emit#message`, each with `group:
grammar:node:emit`. Counting `emit` as one entry would let a composition that reproduces only
the file case look like a replacement for all of `emit`.

**Worked example 2 — a value, not a variant.** A `retry` node takes `count: 1..9` and an
optional `backoff: number | null`. Every count behaves identically with a different number, and
an absent backoff is one extra behavior of the same node, not a second construct. One entry:
`grammar:node:retry`, with the optional backoff listed as one atomic behavior.

**Worked example 3 — a variant that looks like a value.** A `timeout` node takes `on_expiry:
"skip" | "abort"`. Skipping continues the run; aborting rolls back the open transaction. The
failure semantics differ, so two entries, even though the selector is a string.

### Reconciling grain disagreements

Two passes, two batches or two agents may split the same construct differently. Resolve by the
test above, never by taking the middle:

1. List the atomic behaviors of the coarse entry. If every variant of the finer split shares
   one list, merge to the coarse entry.
2. If any variant's list differs from a sibling's, keep the fine split. The coarse entry
   survives as the `group` of its variants and is not catalogued separately.
3. If the disagreement turns on a behavior only one pass observed, verify that behavior at the
   definition site and record the verification in `atomic_behaviors`.
4. Record `grain_note: <which passes disagreed, and the deciding behavior>` on the entry.

## Atomic behaviors

An atomic behavior is one observable effect of a construct that a replacement must reproduce.
List behaviors in four classes:

| Class | What to record |
|---|---|
| `functional` | What the construct produces or changes |
| `ordering` | What must happen before or after it, and whether order among several uses matters |
| `atomicity` | What is all-or-nothing, and what happens to partial effects |
| `failure` | What happens on invalid input, on a missing dependency, and on a runtime error |

The list is the **joint coverage checklist**. Stage 03 accepts a composition for a construct
only if one composition satisfies *every* item on that construct's list together. Covering
the items piecemeal with different compositions is not a composition; a construct whose
behaviors are only covered separately is not Exchangeable. Keep each item checkable: it must be
possible to say, for a candidate composition, "this item holds" with a pointer to the evidence.

## Corpus use

Count each construct's uses over the capability-baseline corpus with a stated query (a
grammar-aware search where one exists; a text search only when it cannot miss uses, with the
text pattern recorded). A count of zero is a fact stage 03 needs for the `Dead` disposition; a
count obtained by a query that could miss uses is recorded as `unreliable` and never reported
as zero.

## Pilot, projection and budget

Do not run the full catalog and ladder first. Scale is estimated from a pilot, then confirmed.

1. **Choose one construct family** — a set of closely related constructs of one layer, large
   enough to include a variant selector and a likely composition.
2. **Run stages 02 and 03 on that family only.** The pilot is the one place stage 03 runs
   before the budget is confirmed; the budget is confirmed after the pilot, not before. Count
   the delegations used (the passes used, when nested delegation is unavailable; see
   [03-necessity-ladder.md](03-necessity-ladder.md#independent-passes)).
3. **Project the full run.** Report: catalog size (known or estimated), delegations per
   construct from the pilot, batches (see [batching](#batching-and-merging-by-uid)), the extra
   merge and cross-batch review delegations, and the resulting total, each with its basis.
   Without nested delegation, count and budget in passes, not delegations.
4. **Ask the user to confirm the budget.** If the projection exceeds the declared budget,
   propose a larger budget, or narrower scope (fewer layers, fewer families), and let the user
   choose. Do not trim scope silently to fit.

A pilot that found the grain wrong is rerun on the corrected grain before projecting.

## Batching and merging by uid

Batch the catalog and the later ladder passes as
[`deep-modules-interface-cost-audit` Step 2](../../deep-modules-interface-cost-audit/SKILL.md#step-2--determine-batching-from-the-confirmed-file-count)
describes: about 18 items per batch, along a seam that exists in the vocabulary (a layer, a
construct family), not by name order. State the total delegation count against the budget
before starting.

Merge batch outputs by `uid`. When two records share a uid, union their `atomic_behaviors` and
keep both `corpus_uses` queries; when the counts differ, rerun the narrower query before use. When a uid is missing in one batch but the
`location` matches a record in another, treat the match as the same construct, record the uid
mismatch, and reconcile by the grain rule above. A construct that appears in two batches with
different `layer` values is a layer-table question: return to stage 01.
