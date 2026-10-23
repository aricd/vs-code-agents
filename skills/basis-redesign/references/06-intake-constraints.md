# Stage 06 — Intake constraints

Contents: [Entry and exit](#entry-and-exit) · [Step 1 — Enforcement inventory](#step-1--enforcement-inventory) · [Step 2 — Forward admission ladder](#step-2--forward-admission-ladder) · [Step 3 — Place the check at intake](#step-3--place-the-check-at-intake) · [Step 4 — Apply to each candidate](#step-4--apply-to-each-candidate) · [Step 5 — Classify and approve](#step-5--classify-and-approve) · [Step 6 — Hand the changes on](#step-6--hand-the-changes-on)

Constraints that are enforced late, or only written in documentation, let an invalid document
travel through the pipeline before anything rejects it. This stage finds those rules and moves
them to intake. It runs **before** realization, so its changes are built (stage 07) and gated
(stages 08-09) together with the candidate they belong to, instead of being bolted on after the
gate has already passed.

## Entry and exit

- **Entry:** gating candidates are named (stage 05), or the run is a constraint-only `compress`
  run.
- **Exit:** an enforcement inventory; a set of admitted constraint changes per gating
  candidate, each classed `break` or `additive`; the user's approval of every `break` with its
  affected-file list. An empty change set is a valid exit; say so in the report.

## Step 1 — Enforcement inventory

List every rule that a valid document must satisfy and record where it is enforced today. Read
the rule's behavior from the running code, not from its documentation.

| Rule | Stated in | Enforced at | Evidence |
|---|---|---|---|
| One line per rule | Document, grammar, test name | `parse`, `IR`, `type check`, `codegen`, `compile`, `runtime`, or `not enforced` | A command and its output: a corpus file that triggers the rule, and the stage at which it failed |

- Include rules that are **documented but not enforced**; they are the cheapest to get wrong,
  because users rely on the documentation.
- A rule enforced at several stages is recorded at each, so that moving it can remove the
  duplicates.
- Compile and runtime failures are not rejection at intake. A document that "fails" only when
  the generated code is built or run was accepted by the vocabulary.

## Step 2 — Forward admission ladder

A candidate constraint comes from a user request, from a rule in the inventory that is enforced
late, or from a documented-but-unenforced rule. Each passes the forward ladder of
[`lean-design`](../../lean-design/SKILL.md), applied to the vocabulary, with evidence that comes
from running, not from reasoning:

1. **Need.** Show a document that is accepted today and should not be, or a failure that shows
   up late. The evidence is an executed run: a validator output or a test that fails, which a
   reviewer can repeat. No executed evidence means no admission.
2. **Compose.** Try to state the constraint with constructs the candidate already has (an
   existing type, a range, an enumerated value). If it composes, admit it in that form and add
   no construct.
3. **Extend or add.** If it does not compose, decide whether to extend an existing construct
   (a new optional attribute) or add a new one. Compare the two with a
   [`deep-modules`](../../deep-modules/SKILL.md) scorecard; the shape that makes callers know
   less wins. Lint any file holding a scorecard with `scripts/validate-scorecard.ps1`.

A constraint stopping at any rung is recorded with the rung and the reason, not dropped
silently.

## Step 3 — Place the check at intake

Put each admitted check at the **earliest stage at which the information needed to decide it
exists**. A rule decidable from one document's text belongs in `parse`; one that needs the whole
document graph belongs at the first stage that holds it. Moving a check earlier is the goal; a
check that stays late because the earlier stage lacks the information is recorded with that
reason.

This applies the intake principle of [`functional-core`](../../functional-core/SKILL.md)
("parse, don't validate" in its Operating rules): turn raw input into a shape in which an
invalid state cannot be written, so later stages need not defend against it. Prefer the grammar
or schema over a separate validator pass, and prefer one check at intake over repeated checks
downstream; remove the duplicates only when the new check demonstrably covers them.

## Step 4 — Apply to each candidate

Apply the admitted changes to **each** gating candidate, separately. A candidate with a new
grammar needs the constraint expressed in that grammar, which can differ from the way the
current vocabulary would express it. A constraint-only candidate applies the changes to the
current vocabulary. Keep each candidate's change set in its own list; stage 07 builds it with
the candidate and stage 08 compares the candidate's outputs with the change set in place.

## Step 5 — Classify and approve

Run the new check over the **whole capability-baseline corpus**, including every file written
in a prior version that must remain accepted, and classify each change:

| Change | Outcome | Rule |
|---|---|---|
| Enforcing a rule that is not checked today | `break` | The files the check now rejects are the affected-file list; user approval names them. Applies to documented-but-unenforced rules too |
| A check moved earlier that rejects exactly the same inputs as before | Not a change in accepted inputs | Prove it: the rejected set is identical on the whole corpus. If it differs at all, it is tightening and a `break` |
| A new opt-in constraint | `additive` | Absent from a document, behavior and output are unchanged; show that stripping it from a document that uses it reproduces the old output |

Obtain the approval for each `break` **here**, before stage 08, with the affected-file list in
the approval. Record each approval with the construct, the affected files, the approving user's
words and the date. A break the user has declined by standing instruction (for example "never
break prior files") is recorded as `declined`, citing that instruction, with no per-break
approval request; the change is not built and its construct stays. A tightening that rejects no corpus file is still a `break`: state that no
corpus file is affected and what inputs outside the corpus it would reject. An approval
obtained after stage 08 does not count.

## Step 6 — Hand the changes on

Write one record per gating candidate: its admitted changes, each with its outcome, its
enforcement stage before and after, its executed evidence, and its approved-break list. The
record flows to stages 07-09 with the candidate. Stage 07 builds the changes, stage 08 allows
only the listed files to differ or be rejected, and stage 09 confirms that the realized changes
match the approvals. A change that was approved here but not built is reported as not realized;
one that was built but not approved reverts the verdict.
