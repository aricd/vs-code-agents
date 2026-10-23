---
name: "closed-doc-duplication-guard"
description: >
  Investigate and close the document-lifecycle gap that let a bulk "sync" commit reintroduce
  already-closed .agent-output/ planning docs as stale duplicates in their active folder.
  Documents the originating incident (commit a1b2c3d in the ExampleService repo) as a
  worked reference case, then designs and implements a guard -- skill text, a detection
  script, and/or a hook -- so the next bulk catch-up commit cannot silently recreate a closed
  document. Invoke with: /closed-doc-duplication-guard, or just start the prompt.
argument-hint: "TargetRepo -- workspace-relative path to the repo whose .agent-output/ you want to audit/guard (default: this repo, vs-code-agents, plus the originating ExampleService incident)"
agent: "agent"
---

# closed-doc-duplication-guard — Prevent Closed-Document Reintroduction

> You are running the **closed-doc-duplication-guard** workflow. Its purpose is to fix a
> document-lifecycle gap at the source: nothing in this repo currently detects or blocks a
> commit that reintroduces a document into `.agent-output/<domain>/` that already exists,
> identically or near-identically, in `.agent-output/<domain>/closed/`.
>
> This prompt is a **reference/kickoff document**, not a plan -- it exists so whoever picks
> up this work does not have to re-derive the incident or re-discover why the existing
> safeguards didn't catch it. Read the Incident Record and Why Existing Safeguards Missed It
> in full before proposing a fix.

---

## Incident Record (worked reference case)

**Repo**: `ExampleService` (a sibling repo consuming this agent/skill set, not this repo
itself). **Discovered**: 2026-09-16, during a routine "what's the status of plan 108?"
status check.

**What happened**: Commit `a1b2c3d` ("chore(agent-output): Sync plan artifacts across
multiple ETL/MCP plans", 2026-09-08) was a bulk catch-up commit spanning plans 101, 104, 108,
114, 117, 119, 122, 126, 133, 134, 140-148, 170-175. For at least 8 of those plans (**108,
117, 119, 122, 126, 133, 134, 175**), the commit **created fresh copies** of planning docs
(and, for plan 117, its `execution-state.yaml` too) directly in `.agent-output/planning/` --
even though every one of those plans had **already been closed** (`Status: Committed`,
correctly moved to `.agent-output/planning/closed/`) in earlier commits (e.g. `c2d3e4f
refactor(docs): Close Plan 117 to closed/`, predating `a1b2c3d`).

**Verification performed before remediation** (do this again if extending the sweep):
- Hash-compared each active-folder duplicate against its `closed/` counterpart
  (`Get-FileHash`). 7 of 8 were byte-identical. Plan 117's active-folder plan doc was the one
  exception: strictly **stale**, missing the final TASK-004-closure text already present in
  the `closed/` copy -- confirming the duplicate wasn't just redundant, it was actively
  wrong if anyone read it instead of the closed copy.
- Confirmed via `git status --short` that the two frontmatter fields that should have made
  this impossible to miss were already present and correct on the duplicates:
  `Status: Committed` sitting in a file living **outside** `closed/`.

**Remediation applied** (manual, by an agent, not by tooling -- this is the gap): removed
the 9 stale duplicate files (`git rm`, scoped exactly to those 9 paths, verified via
`git diff --cached --name-status` before committing), committed **locally only** as
`f1e2d3c` on branch `feature/example-mcp`. `closed/` was left untouched as the sole
authoritative copy in every case.

---

## Why Existing Safeguards Didn't Catch It

Two mechanisms in this repo look like they should have caught this, and neither did --
understand why before designing a fix, so the new guard doesn't repeat the same shape of gap.

1. **`skills/document-lifecycle/SKILL.md` § Orphan Detection.** The "Agent Self-Check"
   procedure explicitly says: scan your domain, find any document with terminal `Status`
   sitting outside `closed/`, move it. This is EXACTLY the condition these 8 duplicates
   satisfied (`Status: Committed`, not in `closed/`). But the check is **pull-based and
   scoped to "before starting work" on a given domain** -- nobody was starting new
   Planner work in `.agent-output/planning/` in the window between `a1b2c3d` landing and
   this discovery, so the self-check never fired. Roadmap's periodic Orphan Sweep is the
   other pull-based backstop and has the same problem: it runs on a cadence, not on commit.

2. **`scripts/check-plan-mirrors.ps1`.** This script's name suggests it might be relevant --
   it isn't, for a specific reason worth preserving: it detects a **different** defect
   (a review-fix landing in one mirror of an *active* plan -- e.g. the plan doc -- and not
   another -- e.g. the execution-state -- while the plan is still open). It has no concept
   of `closed/` at all and does not run against a closed plan. Do not extend this script for
   the new guard; it solves an orthogonal problem and conflating the two will make both
   checks harder to reason about (see `deep-modules`/`lean-design` skills on not widening an
   interface to cover an unrelated capability).

3. **No push-based guard exists.** Nothing in `hooks/hooks.json` fires on a file being
   added/created under `.agent-output/<domain>/` to check whether an identically-named file
   already exists in that domain's `closed/` subfolder. The `PostToolUse` hook wired to
   `validate-plan-template.ps1` is the closest existing pattern -- it fires on
   `edit_file|create_file|replace_string_in_file` against `.agent-output/planning/.*\.md$` --
   but it validates template *shape*, not closed-duplicate collision.

**Root-cause framing**: the system has orphan *detection* but not orphan *prevention*, and
the detection it has is scheduled/manual rather than triggered by the exact event
(file creation/re-creation) that causes the defect. A bulk commit that adds many files in one
shot is precisely the scenario where a human is least likely to notice one of them collides
with something already closed.

---

## Task

### Stage 0 — Confirm scope

Ask (if not already answered by the invoking context): which repo(s) should this guard be
built for -- just this repo's own `.agent-output/` (if it uses the same skill set on itself),
the originating `ExampleService` repo, or the general-purpose skill/script shipped from
here to every consuming repo? Default assumption: build the guard **in this repo**
(`vs-code-agents`) since `document-lifecycle`, `scripts/`, and `hooks/` are all owned here and
distributed outward -- a fix here benefits every consuming repo, including
`ExampleService`.

### Stage 1 — Design the guard

Two complementary layers, both grounded in the Incident Record above:

1. **Skill text.** Add an explicit **Duplicate Detection** sub-check to
   `skills/document-lifecycle/SKILL.md`'s Orphan Detection section, distinct from the
   existing "terminal status sitting outside `closed/`" check: *a file (by basename) present
   in BOTH `<domain>/` and `<domain>/closed/` simultaneously is always an error, regardless
   of the outer file's Status field* -- the outer copy is either identical (redundant) or
   diverged (actively misleading, as plan 117's was). State the resolution rule: `closed/`
   always wins; the active-folder copy is removed, never merged, unless a diff shows the
   active copy carries information the closed copy lacks (in which case: HARD STOP, this is
   not a mechanical fix, escalate).

2. **Detection script + hook.** A new script (mirror the `check-plan-mirrors.ps1`
   conventions: `#Requires -Version 7.0`, `Set-StrictMode -Version Latest`, a `.ps1`/`.sh`
   twin, clear PASS/FAIL exit codes) that:
   - Enumerates every file under each `.agent-output/<domain>/closed/`.
   - Checks whether a file of the same basename exists in the parent `<domain>/`.
   - Reports every collision found; exits non-zero if any exist.
   - Runs across ALL domains that use a `closed/` subfolder (`planning/`, `analysis/`,
     `qa/`, `uat/`, `critiques/`, `code-review/`, etc. -- confirm the full list against
     `document-lifecycle`'s Agent Responsibilities table rather than assuming `planning/`
     is the only one affected).

   Wire it as a hook in `hooks/hooks.json` -- decide (this is a real open question, not a
   foregone conclusion) whether it should fire on `PostToolUse` (after any `create_file`
   targeting `.agent-output/**`, mirroring the existing `validate-plan-template` wiring) or
   as a session-start sweep (mirroring `test-execution-privilege.ps1`'s `SessionStart`
   wiring) -- `PostToolUse` catches the defect at the moment of creation (closer to the
   actual failure mode: a bulk multi-file commit), `SessionStart` catches it regardless of
   how the duplicate arrived (including a bulk sync commit made by a process/session this
   hook set never observed). Recommend evaluating both; a `SessionStart` sweep is the
   stronger backstop given this incident was caused by exactly the kind of external/bulk
   change a per-edit hook would never see.

### Stage 2 — Implement

Follow whichever design Stage 1 lands on. Do not skip the `.sh` twin if `.ps1` is built (this
repo ships both per existing convention -- see every `scripts/*.ps1` having a matching `.sh`).

### Stage 3 — Open question: strengthen the Close Procedure itself

`document-lifecycle`'s Close Procedure step 4 currently says `mv
.agent-output/<domain>/NNN-name.md .agent-output/<domain>/closed/` -- a plain filesystem
move. Consider (do not assume the answer) whether mandating `git mv` explicitly in that step
description would help: a tracked rename is unambiguous in `git log --follow` and in a
`git status` diff in a way that a `mv` + separate `git add`/`git rm` is not, which may make a
future bulk-sync commit's author (or reviewer) more likely to notice "this file already has
a history at a different path" before blindly re-adding it. This is a process/tooling
question, not something to silently decide -- surface it for explicit resolution.

### Stage 4 — Backfill sweep

Once the script exists, run it against every repo known to consume this skill set (at
minimum: this repo, and `ExampleService`) to confirm no other instance of this defect
survives undetected. The Incident Record's remediation only covered the 8 plans named in
`a1b2c3d`'s own commit message -- it did not verify the other domains
(`analysis/`, `qa/`, `uat/`, `critiques/`, `code-review/`) for the same shape of duplication,
and did not check other repos at all.

---

## Evidence Appendix (do not re-derive -- cite directly)

- **Commit**: `a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0`,
  `chore(agent-output): Sync plan artifacts across multiple ETL/MCP plans`, 2026-09-08,
  repo `ExampleService`. `git show --stat a1b2c3d -- <path>` on either duplicate confirms
  it as a pure addition (e.g. plan 117's two files: `220 insertions(+)` / `116
  insertions(+)`, zero deletions -- a fresh create, not a modify).
- **Affected plans**: 108, 117, 119, 122, 126, 133, 134, 175 (all `Status: Committed` in both
  copies at time of discovery).
- **Remediation commit**: `f1e2d3c`, branch `feature/example-mcp`, repo `ExampleService`,
  local-only (confirmed via `git log --oneline -1 origin/HEAD` pointing to an unrelated,
  much older commit). Scope: exactly 9 file deletions, hash-verified safe beforehand,
  `git diff --cached --name-status` re-checked immediately before commit to exclude
  unrelated concurrently-pending changes in the same working tree (plans 101/102/190 had
  their own, unrelated in-flight edits at the time -- these were deliberately left untouched).
- **Relevant existing artifacts**: `skills/document-lifecycle/SKILL.md` (Orphan Detection,
  Close Procedure, Agent Responsibilities table); `scripts/check-plan-mirrors.ps1` (the
  orthogonal check, for contrast); `hooks/hooks.json` (existing `PostToolUse` /
  `SessionStart` wiring patterns to mirror).
