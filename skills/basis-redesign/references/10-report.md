# Stage 10 — Report

Contents: [Entry and exit](#entry-and-exit) · [Report sections](#report-sections) · [Construct table](#construct-table) · [Gating candidates](#gating-candidates) · [Unproven constructs](#unproven-constructs) · [Closing line for snapshot runs](#closing-line-for-snapshot-runs) · [Rules for the report](#rules-for-the-report)

The report is the one artifact the user keeps. It states what was found, what was built, and how
far each claim was proven, with enough evidence that a reviewer can repeat it. It carries no
claim stronger than the stage that produced it.

## Entry and exit

- **Entry:** every stage the run goal requires is done: `snapshot` needs stages 01-04;
  `compress` and `redesign` need the gate stages for every candidate that was realized.
- **Exit:** the report, read by the user.

Write it where the user asked; without a stated location, alongside the run's other analysis
documents.

## Report sections

1. **Declaration.** The confirmed Run Declaration, with each defaulted field marked `default`,
   and the layers excluded from scope.
2. **Construct table** (below).
3. **Tied bases.** Every inclusion-minimal basis from stage 04, per component, with
   cardinality shown as information, any `output-unverified` mark, and the scorecard or user
   choice that picked among them.
4. **Gating candidates** (below).
5. **Unproven constructs** (below).
6. **Open items.** Approvals still needed, components over the exhaustive limit, versions
   without corpus (`unverified`), and any question left open at a checkpoint.

## Construct table

One row for **every** in-scope construct, in catalog order:

| Column | Content |
|---|---|
| Construct | The uid |
| Disposition | `Dead`, `Exchangeable`, `Unproven`, `Fold-in candidate` or `Essential` |
| Rung | The resolving rung |
| Overlay flags | `guardrail` and `keep` values, with their citations |
| Evidence | The evidence ids: the compositions tried, the corpus query, the scorecard |
| Oracle result | The executed result for the composition or the candidate that rests on it: `passed`, `failed`, `unproven`, or `n/a` |
| Compatibility outcome | `demote`, `break` or `additive` for any change touching the construct; `none` when untouched |

A row with an empty cell is incomplete; write `n/a` with a reason.

## Gating candidates

One subsection per gating candidate: the compression candidate, each redesign finalist, and the
constraint-only candidate when that is the run. Candidates left out at stage 05 are listed as
`not gated`, with their mappings.

Each subsection holds:

- the candidate's **mapping**, old -> new for every construct;
- its **stage-06 changes**, each with outcome and enforcement stage before and after;
- the **approved-break list**, with the approval's wording and date;
- the stage-08 result: the counts of `identical`, `differs` and `rejected` files, and whether D
  equalled the approved list;
- the stage-09 result per version notion, with the adoption cost (tests or tools that read the
  prior-form files directly) as information, not as a gate;
- the **gate status**, one of:

| Status | Meaning |
|---|---|
| `passed` | The oracle executed, and D equalled the approved list, and compatibility is confirmed for every version that has corpus files (unverified versions are listed) |
| `failed` | The oracle executed and the verdict reverted; say at which stage the divergence lies |
| `pending` | Handed off at stage 07; stages 08-09 did not run |
| `output-unverified` | The oracle did not execute and pass, or the candidate rests on an `unproven` composition; never final |

Only `passed` is reported as a finished result. Never write "passed" for a gate that did not
execute.

## Unproven constructs

List each `Unproven` construct separately, labeled **"redundancy unproven -- execute to
resolve"**, with the composition that was found, why it has not passed (not yet executed, or
awaiting an oracle) and the command that would execute it. State which bases and candidates rest
on it. Do not fold these into the `Essential` list.

## Closing line for snapshot runs

When `run_goal` is `snapshot`, the report has no gating candidates, and its last line is:

> snapshot, not mandate

A snapshot lists what the analysis found; it proposes nothing as required, and it removes
nothing.

## Rules for the report

- Report the strength the run used. A result obtained under `advisory` says so wherever it
  appears, and an `output-unverified` result is never summarized as a finding that holds.
- Cite what was executed with its command and output; a claim that rests only on reasoning is
  marked `reasoned`, not `executed`.
- Keep scorecards in the report only as citations to where they were run; do not recompute
  them.
