# Stage 09 — Compatibility

Contents: [Entry and exit](#entry-and-exit) · [Version notions](#version-notions) · [Format pairs](#format-pairs) · [Outcomes](#outcomes) · [Classifying each change](#classifying-each-change) · [Confirming the approvals](#confirming-the-approvals) · [Per-notion result](#per-notion-result)

Stage 08 shows that outputs are equal. This stage shows that the **accepted language** is what
the user declared: every prior version the contract names still parses, and every change that
narrows or alters what is accepted was approved. The two can disagree -- a candidate can keep
every output identical while quietly rejecting an input nobody listed.

## Entry and exit

- **Entry:** the stage-08 verdict for the candidate.
- **Exit:** one outcome per change, per version notion; a confirmation that the realized
  changes match the approvals obtained at stages 05 and 06. No user checkpoint; a mismatch goes
  back to the stage that obtained the approval.

## Version notions

The Run Declaration names each way the vocabulary is versioned (a schema version, a format
edition, a grammar release). Check **each notion separately**, in its own pass over the corpus
files written in each of its versions, because a candidate can honor one notion and break
another.

For each notion and version the contract requires: run the candidate's front end over that
version's corpus files and record, per file, whether it was accepted and whether its output
equals the baseline's (from stage 08). "Accepted" means the file parses **and** yields the same
output, as stage 01 defined it. A version with no corpus files cannot be shown compatible;
report it as `unverified: no corpus`, not as compatible. Such a version does not block a
`passed` verdict for the versions that do have files; it is listed in the report.

## Format pairs

Two surface syntaxes that mean the same construct are **one construct with several surface
forms**, not two constructs. Record each such construct with its forms (the form each version
uses). The catalog's granularity rule already gives them one entry when their atomic behaviors
match; here the forms are listed so that dropping one is visible as dropping a form, not as
removing a construct.

A candidate may keep every form, keep one form as the primary and the others as accepted
surface forms (`demote`), or drop a form (`break`). Dropping a form is never free, even though
the construct still exists: inputs written in that form are rejected.

## Outcomes

Every change the candidate makes to the accepted language gets **exactly one** outcome:

| Outcome | Definition | Proof |
|---|---|---|
| `demote` | Removed from the core but kept as a surface form that lowers into the remaining set. Compatibility is preserved | Stage 08 passes on every corpus file using that form; show the file count |
| `break` | Any change that rejects a previously accepted input or changes its output: dropping a surface form, removing a Dead construct, tightening validation at intake | The user's approval, listing the affected corpus files, obtained **before stage 08** (stage 05 for removals, stage 06 for intake tightening) |
| `additive` | An opt-in addition. When it is absent, behavior is unchanged | Executed: strip the addition from a document that uses it and reproduce the old output; run the unmodified corpus through the candidate with the addition available and confirm no change |

## Classifying each change

Work from the candidate's realized change list (not from the plan), and apply the first row
that fits:

| The change | Outcome |
|---|---|
| Rejects an input accepted before, or changes the output of one | `break` |
| Removes a `Dead` construct | `break` -- even with no corpus use, the accepted language shrinks; state which inputs outside the corpus are now rejected |
| Tightens validation, including enforcing a rule that was documented but not enforced | `break` |
| Removes a construct from the core and keeps its input form | `demote` |
| Adds a construct or option that no existing document needs to use | `additive` |

Do not reclassify a failing change to get a pass: an unapproved rejection stays a `break`
without approval and reverts the verdict.

## Confirming the approvals

Build two lists and compare them:

1. **Realized:** every file the candidate rejects or whose output changes, from the stage-08
   record, plus every dropped surface form and removed Dead construct. Regenerated derived
   artifacts (stage 08, Known traps) are not in this list; they are listed separately.
2. **Approved:** the approval records from stage 05 (removals) and stage 06 (intake
   tightening), with their affected-file lists.

They must match **exactly**. A realized change with no approval reverts the verdict (stage 08
already does this for corpus files; here it also covers forms and constructs the corpus does not
exercise). An approval with no realized change means the approval described something that was
not built: report it and have the approving stage correct it.

## Per-notion result

Report, per version notion: each required version; the files checked; accepted-and-equal,
rejected-and-approved, and rejected-unapproved counts; and the outcomes of the changes that
touch it. The candidate's compatibility status is **passed** only when every required version
that has corpus files, in every notion, is accepted-and-equal or rejected-and-approved, with no
unapproved rejection. Versions with no corpus are listed as `unverified` and do not block
`passed`. Also report the
adoption cost measured at stage 07 (tests or tools that read the prior-form files directly) as
information; it is not a gate.
