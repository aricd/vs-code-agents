---
name: plan-status-reporting
description: Deterministic, evidence-based plan status reporting in strict plain-text format. Load when asked for current plan status or progress overview across active plans.
license: MIT
metadata:
  author: aricd
  version: "1.0"
---

# Plan Status Reporting Skill

Produces a strict plain-text status report for all active plans, using only verifiable evidence from repository state and agent-output artifacts.

## Activation Triggers

Load this skill when:
- User asks for "current plan status" or "status report"
- User asks for progress overview across plans
- User wants to know which plans are in progress or blocked

## Output Format (MANDATORY)

When reporting status, emit **raw plain text only**. No Markdown headings and do not wrap the report in a Markdown code fence. Use exactly this structure (including the leading `-` lines in the Evidence section):

```text
-=Current Plan Status=-
Generated: <ISO-8601 timestamp>
Repo: <repo name>  Branch: <branch>  HEAD: <short sha>
Workspace State: <clean|dirty>

[Plan <ID>] <Plan Title>
Plan Approval: Critic=<Approved|Changes Required|Unknown>  User=<Approved|Pending|Unknown>
Plan Status: <Not Started|In Progress|Blocked|UAT Approved|Committed|Released>

Milestones:
1. <Milestone text> - Status: <status>
2. <Milestone text> - Status: <status>

Evidence (must be non-comment-based):
- Implementation present: <yes/no/partial/unknown>
- Tests/linters: <pass/fail/not run/unknown> (<source>)
- Notes: <only if blocked/ambiguous>

Suggested Next 5 Steps (ordered):
1. <next action> — Agent: <planner|implementer|qa|code-reviewer|uat|devops|security|analyst|architect|critic|pi|roadmap|retrospective>
2. <next action> — Agent: <...>
3. <next action> — Agent: <...>
4. <next action> — Agent: <...>
5. <next action> — Agent: <...>
```

Repeat the per-plan block for every active plan. Do NOT include closed plans.

After the final plan block, you MUST end the report with exactly one `Suggested Next 5 Steps (ordered):` section.

### Milestone Status Values

Use exactly one of:
- `Not started`
- `Implementation started`
- `Implemented (verified)`
- `Code reviewed`
- `QA reviewed`
- `UAT approved`
- `Blocked`
- `Unknown`

---

## Evidence-Based Status Rules

### A) Determining Active Plans

A plan is **active** if ALL of the following are true:
1. It exists under `agent-output/planning/`
2. It is NOT under `agent-output/planning/closed/`
3. Its frontmatter `Status` is NOT terminal (Released, Abandoned, Deferred, Superseded)

Plans under `agent-output/planning/closed/` MUST be ignored regardless of any Status text found inside them.

If a plan file does not exist, do not invent it.

### B) Acceptable Evidence Sources (Priority Order)

1. **Repository evidence** (highest priority):
   - File existence and symbol presence
   - `git diff` / `git log` on specific files
   - Build/test command outputs (when execution is safe)

2. **Agent-output artifacts** (when present):
   - `agent-output/implementation/` for implemented work and captured test runs
   - `agent-output/code-review/` for review gate status
   - `agent-output/qa/` for QA completion evidence
   - `agent-output/uat/` for UAT approval
   - `agent-output/deployment/` for committed/released markers

3. **Plan document itself** (lowest priority):
   - Frontmatter Status field
   - Milestone checklists (only if other evidence unavailable)

### C) FORBIDDEN Evidence Sources

The following are **NOT acceptable as sole evidence** for any status claim:
- Subagent chat summaries
- "I implemented X" comments
- Status-only notes without repo/artifact verification
- Any text that is merely a claim without supporting evidence

If only forbidden evidence exists, set status to `Unknown` with a note explaining why.

### D) Test/Linter Evidence Rule

1. **If terminal execution is available and safe**: Prefer running the project's standard test/lint commands and capturing output as evidence.
2. **If execution is not appropriate**: Check `agent-output/implementation/` and/or `agent-output/qa/` for the most recent captured test/lint outputs.
3. **If neither is available**: Report `Tests/linters: not run/unknown` and state why in Notes.

### E) Verifying "Implemented (verified)" Status

You may ONLY claim `Implemented (verified)` when you can point to at least ONE of:
- Expected files/paths exist and are relevant to the milestone
- A `git diff` / `git log` trail shows modifications consistent with the milestone
- A plan-provided traceability map exists and matches repo state

If verification is not possible, set status to `Unknown` with a short note.

### F) Generating the "Suggested Next 5 Steps" Section

The final section must be actionable and consistent with the reported statuses.

Rules:
1. Provide **exactly five** steps, numbered 1–5.
2. Each step MUST include both:
   - the task/action (reference plan ID and/or milestone when applicable)
   - the responsible agent name (lowercase, chosen from the allowed list in the output format)
3. Order steps by dependency:
   - unblock / gather evidence first
   - then implement missing work
   - then run tests/linters
   - then code review
   - then QA/UAT/release steps
4. Steps MUST be evidence-based:
   - If a plan is `Blocked` or has `Unknown` milestones due to missing traceability/evidence, include an early step to resolve that (e.g., add traceability map, locate files, run safe checks) before suggesting implementation.
   - Do not propose steps that assume unverified implementation is complete.
5. If there are fewer than five meaningful actions, fill remaining slots with explicit admin/coordination actions (e.g., "Confirm priorities with user", "Await user approval") rather than inventing technical work.

---

## Traceability Map (Recommended)

For easier verification, plans SHOULD include a traceability map linking milestones to expected file paths or symbols:

```text
## Traceability Map
| Milestone | Expected Files/Globs |
|-----------|---------------------|
| 1. Create service | `src/services/auth/*.ts` |
| 2. Add tests | `tests/auth/*.test.ts` |
```

If a plan lacks a traceability map, do NOT guess file locations. Report `Unknown` if verification is impossible.

---

## Worked Example

The following demonstrates the exact output format (values are illustrative):

```text
-=Current Plan Status=-
Generated: 2026-02-04T15:21:33Z
Repo: vs-code-agents  Branch: main  HEAD: a1b2c3d
Workspace State: dirty

[Plan 008] Plan Status Reporting Skill (Plain Text)
Plan Approval: Critic=Approved  User=Approved
Plan Status: In Progress

Milestones:
1. Create skill: vs-code-agents/skills/plan-status-reporting/SKILL.md - Status: Implementation started
2. Integrate skill into Planner agent: vs-code-agents/planner.agent.md - Status: Not started
3. Document skill in USING-AGENTS.md - Status: Not started
4. Update CHANGELOG.md - Status: Not started

Evidence (must be non-comment-based):
- Implementation present: partial
- Tests/linters: not run (no captured outputs found)
- Notes: Plan is drafted; no repo changes applied yet

Suggested Next 5 Steps (ordered):
1. Verify active plans and current git state (collect branch/sha/dirty) — Agent: analyst
2. Implement Milestone 2 for Plan 008 (integrate skill into planner agent) — Agent: implementer
3. Run the project’s standard tests/linters and capture outputs — Agent: qa
4. Perform code review against Plan 008 acceptance criteria — Agent: code-reviewer
5. Update docs/CHANGELOG for Plan 008 and request user confirmation — Agent: planner
```

---

## Handling Missing Evidence

When evidence is incomplete or unavailable:

1. **Missing agent-output folders**: Acceptable. Report what you can verify from repo state.
2. **Missing traceability in plan**: Set milestone status to `Unknown` rather than guessing.
3. **No test outputs anywhere**: Report `Tests/linters: not run/unknown (no captured outputs found)`.
4. **Conflicting evidence**: Prefer repository evidence over artifact text; note the conflict.

---

## Quick Reference

### Generating a Status Report

1. List files in `agent-output/planning/` (exclude `closed/`)
2. For each plan file:
   a. Check frontmatter Status is not terminal
   b. Extract plan ID and title
   c. Look for matching implementation/QA/UAT docs by ID
   d. Verify milestone status against repo evidence
3. Run `git status` and `git rev-parse --short HEAD` for workspace info
4. Output in strict plain-text format (no Markdown)
5. End with `Suggested Next 5 Steps (ordered):` containing exactly five agent-owned actions

### Evidence Checklist

Before claiming a status, verify:
- [ ] Evidence comes from repo state or agent-output artifacts
- [ ] No status is based solely on chat/comment claims
- [ ] `Unknown` is used when verification is impossible
- [ ] Test/linter source is documented (terminal run or artifact reference)
