# Stage 07 — Realize

Contents: [Entry and exit](#entry-and-exit) · [Step 1 — Fix the build baseline](#step-1--fix-the-build-baseline) · [Step 2 — Lower to the unchanged IR](#step-2--lower-to-the-unchanged-ir) · [Step 3 — Translate the corpus](#step-3--translate-the-corpus) · [Step 4 — Build the stage-06 changes](#step-4--build-the-stage-06-changes) · [Step 5 — Check what was built](#step-5--check-what-was-built) · [Hand-off fallback](#hand-off-fallback)

A redesign that exists only on paper cannot be gated. This stage builds an executable candidate
for every gating candidate, so stage 08 can run the real code on both sides of the comparison.
It produces nothing final: a candidate that runs is still unproven until stage 08 says
otherwise.

## Entry and exit

- **Entry:** gating candidates with their mappings (stage 05) and their stage-06 change
  records.
- **Exit:** per gating candidate, either an executable candidate (a front end that accepts the
  new format, a corpus translator, and the stage-06 changes) or a hand-off whose gate status is
  `pending`.

Realize **every** gating candidate, including its stage-06 changes. A candidate whose
constraint changes were left out is a different candidate from the one the user approved.

Follow the build discipline of [`prototype`](../../prototype/SKILL.md), and read
[PARITY.md](../../prototype/PARITY.md) before building anything that stage 08 will compare: it
names the authority and requires driving the real code on both sides.

## Step 1 — Fix the build baseline

Build each candidate in its own git worktree or branch, started from the **pinned baseline
commit** of the Run Declaration. When the run is sandboxed and a worktree or branch would write
outside the sandbox, a tree copy of the baseline commit stands in for it. Name the worktree
(or copy) after the candidate. Candidates never share a working tree, and none is built in the
tree that holds the baseline. Record the commit each candidate started from; stage 08 rebuilds
the baseline generator from the same commit.

## Step 2 — Lower to the unchanged IR

The preferred pattern: the new input format is a front end that **lowers to the unchanged
intermediate representation**, so the code generator and everything behind it stay untouched.
Output equality then depends on the front end alone, and a difference can only come from
lowering.

- **A redesign finalist** adds a front end for its new constructs. Each new construct lowers to
  the IR nodes the old construct(s) it replaces would have produced, following its mapping.
- **A compression candidate** lowers each `demote`d construct into the remaining core: the
  surface form stays accepted, and the lowering is the composition that passed at stage 03.
  The IR needs no new nodes, because the demoted construct was shown composable from them.
- A lowering must be injective on the corpus: lowering then lifting reproduces every authored
  document, including documents that already contain the lowered form's literal or token.
  Check it over the whole corpus before stage 08, not only on files that use the construct.

Check the pattern holds instead of assuming it: after the build, the IR definitions and
everything behind them must show no diff against the baseline commit (Step 5). Do not make the
IR "slightly more convenient" for the new front end; that is a backend change and moves the
candidate to the hand-off fallback below.

## Step 3 — Translate the corpus

The corpus is translated into the new format through the **stage-05 mapping**; the translator
is part of the candidate and is built, versioned and reviewed with it.

- The translator is a program that reads the old-format corpus and writes the new-format
  corpus. Never hand-edit a translated file; a hand edit would make the equality result a
  statement about the editor.
- Every mapping entry is applied: `kept`, `folded` and `added` entries produce new-format
  text; a `removed` entry has no translation and the files that use it are exactly the approved
  break list.
- Translate the **whole** capability-baseline corpus. A file the translator cannot translate is
  recorded with the reason; it is either on the approved-break list or it is a translator
  defect, never skipped silently.
- Files in a prior-version format that the candidate still has to accept are **not** translated:
  they go to the candidate front end as they are, because accepting them unchanged is what the
  compatibility contract requires. Record which files take each route.
- Deliver the translated corpus **beside** the prior-form corpus; it never replaces it. Measure
  the adoption cost, meaning the tests or tools that read the prior-form files directly, and
  report it in stages 09 and 10 as information, not as a gate.

## Step 4 — Build the stage-06 changes

Build each admitted constraint change into the candidate's front end, at the stage chosen in
stage 06. A `break` change must reject exactly the files on its approved list; an `additive`
change must leave a document that omits it behaving exactly as before. Do not widen a change to
make a test pass.

## Step 5 — Check what was built

Before handing a candidate to stage 08, run and record:

| Check | Command evidence |
|---|---|
| Builds and starts | The build and a run on one small corpus file |
| The backend is untouched | A diff of the IR definitions and every path behind them against the pinned baseline commit; empty |
| The translator ran over the whole corpus | File counts: translated, passed through, failed with reason |
| Stage-06 changes present | Each change's check, run on one file it must reject and one it must accept |

A candidate that passes these has not passed anything that counts; the gate is stage 08.

## Hand-off fallback

Hand the candidate off to an implementation plan when either holds:

- it **cannot lower to the unchanged IR** (it needs a new IR node or a backend change), or
- the Run Declaration sets `realization_mode: hand-off`.

The hand-off contains: the candidate's mapping; the lowering rules; the translator
specification; the stage-06 change record; the approved-break list; the oracle command and the
pinned baseline; and the statement of which IR or backend change would be needed and why. It
introduces no code into the repository.

A handed-off candidate's gate status is **`pending`**: stages 08 and 09 have not run on it, and
stage 10 reports it as `pending`, never as passed and never as final. If some gating candidates
realize in the run and others are handed off, run stages 08-09 on the former and report both.
