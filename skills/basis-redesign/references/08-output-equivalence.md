# Stage 08 — Output equivalence

Contents: [Entry and exit](#entry-and-exit) · [Step 1 — Pin the baseline](#step-1--pin-the-baseline) · [Step 2 — Declare the canonicalization](#step-2--declare-the-canonicalization) · [Step 3 — Run the comparison](#step-3--run-the-comparison) · [Step 4 — The verdict rule](#step-4--the-verdict-rule) · [Step 5 — Finality](#step-5--finality) · [Known traps](#known-traps) · [Diverging output](#diverging-output)

This stage is where a verdict becomes final or does not. It runs the declared oracle over the
whole corpus and asks one question: do the candidate's outputs equal the baseline's, except
exactly where the user approved a break? Nothing earlier in the run substitutes for it.

## Entry and exit

- **Entry:** a realized candidate (stage 07); the oracle and the pinned baseline declared, or
  `oracle: none` declared (stage 01), in which case no comparison runs and Step 5 applies.
- **Exit:** per candidate, an executed verdict (`passed` or `failed`) with its evidence, or the
  gate status `output-unverified` (always the result when `oracle: none`). No user checkpoint.

The comparison is a differential run in the sense of [PARITY.md](../../prototype/PARITY.md).
**Name the authority:** the baseline generator, at the pinned commit, is ground truth. **Drive
the real code on both sides:** the baseline's own generator, and the candidate's real front end
feeding the unchanged IR and backend. Never compare against a re-implementation or a paraphrase
of either, and feed the real corpus, not convenient fixtures.

## Step 1 — Pin the baseline

1. Check out the Run Declaration's pinned baseline commit into a clean worktree. Record the
   commit hash.
2. **Rebuild the baseline generator from that commit**: do not reuse an installed or cached
   build of unknown origin. Record the build command and the build's exit status.
3. Generate the baseline outputs: the **old-format corpus** through the baseline generator.
   Keep them as the reference set; do not regenerate them during the run.

## Step 2 — Declare the canonicalization

At `equivalence_level: byte`, there is none. At `normalized`, list every normalization from the
Run Declaration, each as a rule with its reason (for example, ids derived from file paths that
differ between a baseline checkout and a candidate checkout). At `behavioral`, name the
observed behavior and how it is observed.

Apply the **same** canonicalization to both sides, as a program, never by hand. Normalization
can erase a real difference, so:

- Count, per file and per rule, how many substitutions each side needed. Differing counts are a
  finding even if the normalized outputs then match.
- Run a **negative control**: damage one candidate output in a way the declared level must
  catch (drop a line, change a value) and confirm the comparison fails. A comparison that
  cannot fail proves nothing.
- Report the number of files that differ **before** normalization alongside the number after.

## Step 3 — Run the comparison

Compare two sets of outputs:

| Side | Pipeline |
|---|---|
| Baseline | old-format corpus -> baseline generator |
| Candidate | translated corpus -> candidate front end -> unchanged IR -> backend, **plus** each prior-version file the candidate still accepts, passed through unchanged |

Cover the **full** capability-baseline corpus. Do not sample. Assign every corpus file exactly
one outcome:

| Outcome | Meaning |
|---|---|
| `identical` | Equal after the declared canonicalization |
| `differs` | The candidate produced output, and it is not equal |
| `rejected` | The candidate refused the input |
| `baseline-rejected` | The baseline generator itself refused it; it is not part of the capability baseline, so list it and exclude it |

The file counts of the four outcomes must sum to the corpus size on each side; a mismatch means
a file was lost, not compared.

Prior-version formats are compared too: a candidate that accepts a prior-version file must
produce the baseline's output for it. Where the compatibility contract says a prior version is
no longer accepted, that is a `break` and its files must be on the approved list.

## Step 4 — The verdict rule

Let **D** be the set of files whose outcome is `differs` or `rejected`, and **B** the union of
the approved-break lists for this candidate: removal breaks approved at stage 05 and
intake-tightening breaks approved at stage 06. A candidate **passes only when D equals B
exactly.** Derived artifacts regenerated in the candidate copy (see
[Known traps](#known-traps)) are excluded from D and listed separately.

- A file in D but not in B is an unapproved difference. **Revert the verdict**: the removal or
  redesign it rests on is not final, the candidate's gate status is `failed`, and the work
  returns to stage 05 (the mapping or lowering) or stage 06 (the check) to be repaired or the
  construct kept. Do not edit the oracle, the canonicalization or the expected outputs to fit
  the result.
- A file in B but not in D means an approved break did not occur: the approvals do not describe
  the candidate. Report it and obtain corrected approvals; do not pass on a partial match.
- Differences on the approved list are expected and are reported as such, with the reason each
  file differs or is rejected.

## Step 5 — Finality

A verdict is final only when the oracle **executed and passed** under the declared
`equivalence_strength`.

- Executed and D equals B: `passed`. Under `hard` this is the only way a verdict becomes
  final; under `advisory` it is also required, and it is the only thing that removes the
  `output-unverified` label.
- Executed and D differs from B: `failed`.
- The oracle did not execute (declared `none`, cannot be run, or not reached), or the verdict
  rests on a composition that is still `unproven`: **`output-unverified`**. It is reported with
  that label, never as final, whatever the advisory setting.
- A candidate handed off at stage 07 is `pending`; this stage does not run on it.

## Known traps

- **Normalizing both sides can hide content loss.** If both outputs are transformed, content
  dropped by the transformation disappears from both. The counts, the byte-level comparison and
  the negative control from Step 2 exist for this; use all three.
- **Inputs that use newly added constructs cannot be compared with the old baseline.** The
  baseline generator cannot read them. Exclude them from this comparison and **list** them; they
  are not evidence of equivalence. An `additive` construct is verified at stage 09 by stripping
  it from a document and reproducing the old output.
- **Flaky oracle members.** A timing-sensitive or transport-dependent member can fail without
  the candidate being at fault. Run the suite sequentially and compare against the baseline's
  own failing set, measured the same way. Record each flake as a flake; it counts neither as a
  candidate failure nor as a pass. The verdict can be `passed` only when the baseline shows the
  same flake set and every other member passes; otherwise it is `output-unverified`.
- **Derived artifacts pinned by a source hash.** Evidence manifests and oracle records bound
  to the bytes of a spec are expected to change when a source is rewritten. They are not
  approved breaks: regenerate them with the project's own command in the candidate copy, exclude
  them from D, and list them in the realization record separately from the approved-break list.

## Diverging output

When D differs from B, locate the stage that diverges before touching anything, as PARITY.md's
bisecting step prescribes: compare the front end's IR output for one differing file against the
IR the baseline front end produces for the old file. If the IRs differ, the lowering is at
fault. If they are identical, the backend is unchanged, so suspect the environment or the
canonicalization: rerun the baseline twice to check it is deterministic, and recheck the
normalization rules. Record the first stage at which the two sides disagree for that file, and
return the candidate to stages 05-07 or fix the canonicalization declaration with the user.
