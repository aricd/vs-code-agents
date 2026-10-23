---
class_id: FM-T-OPENQGATE
guarantee: G-T-OPENQGATE
status: observed
provisional: true
---

# FM-T-OPENQGATE

## Mode: FM-T-OPENQGATE.ID-COLLAPSE

**Mechanism.** `Test-OpenQuestions` in `scripts/validate-plan-template.ps1` matches OPENQ IDs via the regex `OPENQ-\d+`, which stops at the first non-digit character, so every composite `OPENQ-<origin-id>-<local-seq>` entry (structured-labeling REQ-005) sharing an origin-id collapses to one identical matched string after `Select-Object -Unique`. When a document's collapsed group contains at least one `[RESOLVED]`/`[OPEN ...]`-marked entry, the whole group reads as accounted-for, so a genuinely unmarked sibling entry from the same origin-id is never flagged by the `HARD GATE FAILURE: Unresolved OPENQ items` check. The same collapse can also throw a non-terminating `PropertyNotFoundException` on the following warning-count line (`$allOpenqIds.Count - $resolvedOpenqIds.Count`) whenever `Select-Object -Unique` returns a bare scalar `System.String` instead of an array (confirmed: bare strings have no `.Count` property on PowerShell 7.6.3).

**Oracle.** `--` (provisional; no oracle wired yet).

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | escaped 2026-08-31 (Plan 27 QA) | -- | Real: `pwsh scripts/validate-plan-template.ps1 -FilePath .agent-output/planning/027-live-access-and-citation-fidelity-ask-mechanisms-plan.md` throws `PropertyNotFoundException` at line 295 (`$allOpenqIds`/`$resolvedOpenqIds` both collapse to scalar `"OPENQ-27"` across the plan's 6 composite `OPENQ-27-*` entries). Synthetic (isolates the gate-bypass, not just the exception): a 3-line document with `OPENQ-27-1 [OPEN]`, `OPENQ-27-2 [RESOLVED]`, `OPENQ-27-3` (no marker at all) run through the same logic yields `blockingUnresolved.Count = 0` (should be 1). Full evidence and commands in `.agent-output/qa/027-live-access-and-citation-fidelity-ask-mechanisms-qa.md`. |
| .002 | observed | escaped 2026-09-01 (Plan 030 Critic review) | -- | Real: `pwsh scripts/validate-plan-template.ps1 -FilePath .agent-output/planning/030-executive-summary-deferred-items-plan.md` throws `PropertyNotFoundException` -- observed at line 295 during Plan 030's Critic review; independently re-reproduced by QA 2026-09-01 at line 296 on the current (post-H-003-fix) script, the one-line shift caused by TASK-009's added regex-tolerance comments, not a different defect. Same mechanism as `.001`: Plan 030's Traceability Map carries exactly one composite `OPENQ-30-1` entry, so `$allOpenqIds`/`$resolvedOpenqIds` both collapse to the bare scalar `"OPENQ-30"` via `Select-Object -Unique`, which lacks a `.Count` property. Non-terminating (the script still completes and emits `PASS: Plan template validation successful`); does not block validation output or mask the Traceability Map warnings TASK-009/010 (H-003) added. Full evidence and commands in `.agent-output/qa/030-executive-summary-deferred-items-qa.md`. |
| .003 | observed | Plan 033 (verification-discipline-hardening) plan authoring, 2026-09-02, pinned on the mechanism 2026-09-20 (Planner `RC-16` correction, Implementer `TASK-013`) | -- | Real, executed against Plan 033 rev 2: `[regex]::Matches($planText,'OPENQ-\d+')` collapses `OPENQ-033-1a` and `OPENQ-033-1b` to the single tracked ID `OPENQ-033`, which then appears in **both** the resolved set and the open set simultaneously -- impossible for one question, proving the collapse directly (distinct IDs: `OPENQ-033`; RESOLVED: `OPENQ-033`; OPEN: `OPENQ-033`). Pinned on the mechanism per the plan's own authoritative FM Exposure wording, correcting an earlier framing (withdrawn) that had inferred absence-of-mechanism from a zero-warning run against a single signal -- the same `GROUNDGATE-003`-shaped error this class of finding exists to catch. |

## Mode: FM-T-OPENQGATE.MARKER-BLEED

**Mechanism.** The resolved-marker regex `OPENQ-\d+[^\[]*\[(RESOLVED|CLOSED)` in `Test-OpenQuestions` uses an unbounded greedy `[^\[]*`, which spans forward past table rows, list items, and section boundaries until it reaches the _first_ `[` character anywhere later in the document -- not the end of the sentence/line/table-cell containing the ID it started from. When an earlier, unrelated bare `OPENQ-*` mention precedes a later, correctly-marked `OPENQ-*` entry with no `[` in between, the greedy match spans across both, and the credit-assignment step (`if ($_.Value -match 'OPENQ-\d+') { $Matches[0] }`) attributes the marker to whichever ID started the match, stealing credit from the ID actually adjacent to the bracket. The same unboundedness structurally permits the inverse and more severe direction -- a genuinely unresolved ID borrowing credit from a distant, unrelated ID's marker, producing a false PASS that defeats the hard gate's purpose -- which was not separately reproduced with real content this session.

**Oracle.** `--` (provisional; no oracle wired yet).

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | escaped 2026-09-15 (Plan 339 re-validation, example-workspace project) | -- | Real: `pwsh scripts/validate-plan-template.ps1 -FilePath ExampleService/.agent-output/planning/339-task-compact-etl-spec-schema-plan-v2.md` (example-workspace project) reported `HARD GATE FAILURE: Unresolved OPENQ items: OPENQ-327` even though `OPENQ-327-4` (a citation of a different, already-resolved plan's open question, embedded in prose) carried an explicit `[RESOLVED, Plan 327]` marker immediately adjacent to it. Root cause isolated by direct PowerShell repro: an earlier bare mention of `OPENQ-339-1` roughly 1,800 characters upstream (itself later marked `[RESOLVED]` in its own Open Questions section) let the greedy `[^\[]*` span forward past a table and a section boundary to reach `OPENQ-327-4`'s bracket first, so `OPENQ-339` was credited (correctly, coincidentally) while `OPENQ-327`'s own adjacent marker was consumed by the wrong match and never credited to it. Synthetic (isolates the mechanism, confirmed via `[regex]::Matches`): a document containing `OPENQ-1-1` (bare, no bracket within 200+ chars) followed later by `OPENQ-2-2 [RESOLVED]` yields a single greedy match spanning both, crediting only `OPENQ-1`; `OPENQ-2`'s own adjacent marker is never independently matched. |
