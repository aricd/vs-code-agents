---
ID: 3
Origin: 3
UUID: 9c3a7b1e
Status: Committed
UAT_Approved: true
UAT_Approved_Date: 2026-02-08
DevOps_Committed: true
DevOps_Committed_Date: 2026-02-08
---

# Plan: Unified Labeled Planning + No-Silent-Assumptions + Executive Summary + Approval Workflow

Epic Alignment: Planning governance / clarity / reduced over-scoping
Supersedes: Plan 001, Plan 002
Target Release: Unassigned

## Changelog
| Date | Agent | Change | Notes |
|---|---|---|---|
| 2026-02-08 | Planner | Created | Consolidates and supersedes 001/002 |
| 2026-02-08 | Planner | Updated | Resolved OPENQ-001/002 defaults |
| 2026-02-08 | Planner | Updated | Resolve Critic blockers (coverage + validation) |
| 2026-02-08 | Implementer | Updated | Phase 2 complete (tasks 005-007) |
| 2026-02-08 | Implementer | Updated | Phase 3 complete (tasks 008-010) |
| 2026-02-08 | Implementer | Updated | Phase 4 complete (tasks 011, 012, 015) |
| 2026-02-08 | Implementer | Updated | Phase 5 complete (tasks 013-014) |
| 2026-02-08 | Code Reviewer | Code Review REJECTED | Missing implementation doc; Plan 003 fails own validation (see code-review/003-*-code-review.md) |
| 2026-02-08 | Code Reviewer | Code Review APPROVED | All critical findings resolved; implementation meets quality standards; ready for QA |
| 2026-02-08 | QA | QA Complete | TEST-001..TEST-004 executed; no critical blockers; approved for UAT |
| 2026-02-08 | DevOps | Updated | UAT approved for release |
| 2026-02-08 | DevOps | Document closed | Status: Committed; Git SHA: 96c6465 |

## Value Statement and Business Objective
As a user collaborating with VS Code agents, I want every planning-related artifact (plans, critiques, analysis, QA, UAT, DevOps notes) to use a rigid, labeled template with explicit assumptions/contracts and a consistent approval workflow that includes an executive summary at approval time, so that scope stays correct, alternatives are visible, and I can approve work confidently without hidden constraints.

## Objective
Deliver repo-wide conventions and agent instructions such that:
- All agents that write to `agent-output/` produce artifacts using **structured labels** (REQ-*, CON-*, TASK-*, ALT-*, etc.) with deterministic numbering rules.
- The Planner prevents silent scope/contract assumptions by integrating `no-silent-assumptions.software-planning` (only when ambiguity exists), using batch questions with defaults.
- A reusable **Executive Summary** skill exists and is invoked at final plan approval time (and when the user “approves early”), summarizing plan scope/status/assumptions/alternatives without copying the full plan.
- Approval is tracked in plan frontmatter/metadata; approval remains **implicit** (conversation can continue) but is always accompanied by an explicit approval prompt.
- Critic validates template compliance (including allowed exceptions like USER-TASK-*) before recommending implementation.

## Non-Goals / Out of Scope
- No migration of existing plans (001/002 remain as historical artifacts in `closed/`).
- No changes to VS Code/Copilot product behavior outside repository agent definitions + skills.
- No implementation code inside planning documents.

## Decisions (Recorded)
- Template strictness: **Rigid** and **fixed ordering**.
- Labels: Use **all** prefixes from awesome-copilot’s implementation-plan template **and** all prefixes from `no-silent-assumptions.software-planning`.
- Phases and tasks: Use GOAL-* for phases; TASK-* for tasks (TASK numbering is global across phases).
- Task representation: Use **tables** with statuses + completion dates.
- Numbering: Independent numbering per section (REQ-001 restarts separate from ALT-001, etc.); TASK-NNN is global.
- Alternatives: Include full rationale; consider execution implications.
- User approval: Implicit, but always ask an explicit approval question at the end of the executive summary.
- Exceptions: “No task should require human interpretation” is the default goal; allow **USER-TASK-*** only with justification and Critic approval; must be highlighted before user approval.
- Coexistence: Keep `plan-status-reporting` (multi-plan, evidence-based) and add `executive-summary` (single-plan, approval-oriented).
- Validation: Enforce template/labels via (a) an authoritative skill checklist and (b) a lightweight repo script runnable by Code Reviewer/QA/Planner.

## Required Label Prefixes (Repo Standard)
**Plan artifacts MUST use these when applicable**:
- Requirements/constraints: REQ-*, SEC-*, CON-*, GUD-*, PAT-*
- Contracts/compatibility: CONTRACT-* (Proposed), BACKCOMPAT-*
- Planning structure: GOAL-*, TASK-*, USER-TASK-*
- Testing: TEST-SCOPE-* (approach), TEST-* (executable test procedures)
- Traceability: FILE-*, DEP-*
- Alternatives and risk: ALT-*, RISK-*, ASSUMPTION-*, OPENQ-*

### Prefix Definitions (Normative)
- REQ-* = functional or non-functional requirement that must be met
- SEC-* = security requirement (authn/z, data handling, threat posture, etc.)
- CON-* = constraint (hard limitation: tech, time, compatibility, policy)
- GUD-* = guideline (preferred practice; deviation allowed with justification)
- PAT-* = required pattern (architectural/structural pattern to follow)
- CONTRACT-* (Proposed) = provisional interface/boundary contract used to prevent silent assumptions
- BACKCOMPAT-* = explicit backwards compatibility posture/decision (even if “not required”)
- TEST-SCOPE-* = testing depth posture (unit/integration/e2e) and expectations
- TEST-* = executable tests to be created/run (procedures, files, suites)
- USER-TASK-* = intentional human action required (exception class; must be justified and approved)
- OPENQ-* = explicitly unanswered question; must be listed before handoff
- FILE-* = file(s) expected to change, create, or be validated
- DEP-* = dependency this plan consumes (existing external thing); use CONTRACT-* only for interfaces this plan proposes/creates
- ALT-* = alternative approach(es) considered, including rationale and execution implications
- RISK-* = risks and mitigations
- ASSUMPTION-* = explicit assumptions (must not be buried in prose)

## Standard Task Statuses
Allowed values (case-insensitive, normalized in summaries):
- not-started
- in-progress
- complete
- blocked
- deferred

Canonical written form in artifacts: **lowercase hyphenated** exactly as listed above.

## Plan Template (Rigid; Fixed Ordering)
The Planner’s plan output MUST follow this section order:
1. Value Statement and Business Objective
2. Objective
3. Requirements & Constraints (REQ/SEC/CON/GUD/PAT)
4. CONTRACT-* (only if relevant; otherwise state “None”)
5. BACKCOMPAT-* (always present; explicit decision)
6. TEST-SCOPE-* (always present; unit required; integration/e2e default-able)
7. Implementation Plan
   - Implementation Phase N header
   - GOAL-NNN (exactly one GOAL per phase; 1:1 mapping)
   - TASK table (TASK-NNN… global numbering)
   - USER-TASK table (only if justified)
8. Alternatives (ALT-*) (only if requested or ambiguity warrants; otherwise “None”)
9. Dependencies (DEP-*)
10. Files (FILE-*)
11. Tests (TEST-*)
12. Risks (RISK-*)
13. Assumptions (ASSUMPTION-*)
14. Open Questions (OPENQ-*)
15. Approval & Sign-off (User/Critic/Architect/Roadmap as applicable)
16. Traceability Map (recommended)

### Traceability Map Format (When Present)
Use a simple table compatible with `plan-status-reporting` verification:

| Phase / Milestone | Expected Files/Globs / Symbols |
|---:|---|
| GOAL-NNN / TASK-NNN | `path/to/expected/files/**` |

## Agent Coverage (Authoritative Mapping)
All agents that write artifacts to `agent-output/` MUST adopt the rigid template + labels appropriate to their domain:
- planner → `agent-output/planning/`
- critic → `agent-output/critiques/`
- analyst → `agent-output/analysis/`
- implementer → `agent-output/implementation/`
- code-reviewer → `agent-output/code-review/`
- qa → `agent-output/qa/`
- uat → `agent-output/uat/`
- devops → `agent-output/deployment/`
- security → `agent-output/security/`
- roadmap → `agent-output/roadmap/`
- retrospective → `agent-output/retrospective/`
- pi → `agent-output/pi/` (if used in this repo)

If a domain folder does not exist yet, the owning agent creates it when first needed (and still follows labeling rules).

## Validation & Enforcement (Where It Lives)
Template/label compliance is enforced in two places:
1) **Skill-level checklist (authoritative)**: a `structured-labeling` skill defines:
  - required prefixes + definitions
  - section ordering
  - status enum
  - USER-TASK exception rules
  - executive-summary required fields
2) **Repo validation script (pragmatic gate)**: a lightweight script (PowerShell-first) that checks:
  - required sections present in the correct order
  - required prefixes exist when sections are present
  - no unresolved OPENQ-* in hard-gated domains at handoff points

The script is intended for Code Reviewer/QA/Planner to run before approving handoffs; it is not a substitute for Critic judgment.

## Executive Summary (Approval-Time; Chat Output)
At final approval time, the acting agent MUST:
1) Output any prior status updates (as today)
2) Output an Executive Summary (markdown) referencing the active plan
3) End with an explicit approval prompt: “The plan is ready for approval. Do you approve?”

The Executive Summary MUST include:
- Plan identity: ID, title, last-updated, current Status
- Scope snapshot: REQ/SEC/CON items (default: list up to 10; if more, show first 10 + “see plan for full list”)
- Phases overview: for each phase, show phase name + GOAL-* + phase status
  - If phase not-started or complete: list only phase + status
  - If phase started: list tasks in order with TASK-* + status
- USER-TASK-*: list prominently if any exist, with justification summary; MUST be shown before the approval prompt
- Assumptions: list ASSUMPTION-* (at least titles); highlight high-risk ones
- Alternatives: list ALT-* with 1–3 sentence rationale each
- Risks: include top RISK-* with ⚠️ marker
- Open questions: list any OPENQ-* remaining; if blocking, say “BLOCKING”

It MUST NOT:
- Copy the entire plan verbatim
- Introduce new requirements
- Hide USER-TASK-* items

### Relationship to plan-status-reporting
- `executive-summary` is single-plan, approval-oriented, and plan-centric.
- `plan-status-reporting` is cross-plan, evidence-based, and execution-oriented.
Both remain; neither replaces the other.

## Scope Change Conversation (Planner Behavior)
When a user requests additional work while an active plan exists, Planner MUST ask:
- “I can add these items to the current plan (default), or create a new plan. Which do you prefer?”
Planner proceeds with the default only if the user says “defaults”/equivalent or does not object.

## Work Plan (Mega-Plan)

## Phase Gates (Keep One Mega-Plan, Still Verify Incrementally)
- Gate A (after Phase 1): Critic confirms labeling/template adoption path is coherent before proceeding broadly.
- Gate B (after Phase 3): Confirm executive summary + approval flow works end-to-end in at least one dry-run.
- Gate C (after Phase 5): Confirm execution-state + plan-status-reporting remain consistent.

### Phase 1 — Establish repo-wide labeling + templates
GOAL-001: Define and adopt rigid labeled templates across all planning-related artifacts.

| Task | Description | Status | Owner | Date |
|---|---|---|---|---|
| TASK-001 | Create a new skill `structured-labeling` defining required prefixes + definitions, numbering rules, required section ordering, USER-TASK policy, and allowed statuses (authoritative) | not-started | implementer | |
| TASK-002 | Update Planner plan template to the rigid ordering above and require label usage + validation before handoff | not-started | implementer | |
| TASK-003 | Update all agents that write to `agent-output/` to reference the labeling standard and to emit labeled artifacts in their domain (planning/critiques/analysis/implementation/code-review/qa/uat/deployment/security/roadmap/retrospective/pi) | not-started | implementer | |
| TASK-004 | Update `document-lifecycle` skill to require a “Template/Labels Compliance” clause for agent-output artifacts (without changing ID protocol) | not-started | implementer | |

### Phase 2 — No-silent-assumptions integration (planner-first; consumable by all)
GOAL-002: Prevent hidden scope/contract assumptions while keeping UX low-friction.

| Task | Description | Status | Owner | Date |
|---|---|---|---|---|
| TASK-005 | Ensure Planner loads `no-silent-assumptions.software-planning` when planning; only triggers OPENQ batch questions when ambiguity detected; adopt the batch question UX + "Open Questions: defaults" response format verbatim from the skill | complete | implementer | 2026-02-08 |
| TASK-006 | Add explicit prompts for performance posture + backwards compatibility importance (example: save-file compatibility) to avoid over-engineering | complete | implementer | 2026-02-08 |
| TASK-007 | Require explicit BACKCOMPAT decision and CONTRACT proposals only when public interfaces/boundaries exist | complete | implementer | 2026-02-08 |

### Phase 3 — Executive Summary skill + approval workflow
GOAL-003: Add approval-time executive summary and consistent sign-off tracking.

| Task | Description | Status | Owner | Date |
|---|---|---|---|---|
| TASK-008 | Create new skill folder `vs-code-agents/skills/executive-summary/` with a reusable skill that generates the required summary from the active plan | complete | implementer | 2026-02-08 |
| TASK-009 | Update Planner to invoke the executive summary at final approval time, and also if user "approves early" | complete | implementer | 2026-02-08 |
| TASK-010 | Add plan frontmatter fields for approval tracking while keeping ID/Origin/UUID/Status unchanged; document canonical approval field schema + which agent populates each in `structured-labeling` (e.g., User_Approved*, Critic_Approved*, UAT_Approved*, DevOps_Committed*, etc.) | complete | implementer | 2026-02-08 |

### Phase 4 — Validation gates, exception handling, and tooling
GOAL-004: Ensure deterministic plans with controlled exceptions and automated compliance verification.

| Task | Description | Status | Owner | Date |
|---|---|---|---|---|
| TASK-011 | Update Critic to validate: template ordering, required sections present, labels used, USER-TASK justification, OPENQ handling, and approve/reject accordingly | complete | implementer | 2026-02-08 |
| TASK-012 | Require Implementer/QA/UAT/Code Reviewer to reference TASK-* and TEST-* IDs in their artifacts and in execution-state updates | complete | implementer | 2026-02-08 |
| TASK-015 | Add a repo validation script (PowerShell-first) to check plan/summary template ordering, label prefixes, and unresolved OPENQ rules; integrate into Code Reviewer and QA guidance as a pre-handoff gate | complete | implementer | 2026-02-08 |

### Phase 5 — Execution state enhancements (consistency)
GOAL-005: Enhance execution-state schema to track phase/task status consistently with the new labels.

| Task | Description | Status | Owner | Date |
|---|---|---|---|---|
| TASK-013 | Extend execution-state schema to include phases (GOAL-*) and tasks (TASK-*), plus links to artifacts; keep it YAML-first and deterministic | complete | implementer | 2026-02-08 |
| TASK-014 | Align plan-status-reporting to recognize the new approval tracking + traceability map patterns where available (without losing evidence-based rules) | complete | implementer | 2026-02-08 |

## Dependencies
- DEP-001: The `no-silent-assumptions.software-planning` skill remains authoritative and should not be duplicated.
- DEP-002: Existing execution-orchestration schema can be extended; avoid breaking consumers.

## Tests
- TEST-001: Run validation script against Plan 003 itself — must produce PASS (exit code 0)
- TEST-002: Verify structured-labeling skill loads correctly in Planner/Critic/Code Reviewer
- TEST-003: Verify executive-summary skill loads correctly in Planner
- TEST-004: Verify execution-state.schema.md and plan-status-reporting/SKILL.md remain consistent (field names, status enums align)

## Risks
- RISK-001: Rigid templates increase friction initially → mitigate with clear examples + auto-validation + defaults.
- RISK-002: Over-labeling leads to noisy docs → mitigate by “when applicable” rule and concise descriptions.
- RISK-003: Agents diverge on statuses → mitigate by a single authoritative status enum.
- RISK-004: Mid-implementation friction or workflow breakage → mitigate by phase gates and keeping Phase 1+3 as the minimal end-to-end MVP before broadening.

## Assumptions
- ASSUMPTION-001: Agents can be updated to “load a skill by name” via their agent definition text.
- ASSUMPTION-002: Users prefer one mega-plan over multiple; scope changes are managed via the scope-change conversation.

## Open Questions
- OPENQ-001 [RESOLVED]: In executive summaries, should REQ/SEC/CON lists be fully enumerated or capped? → Default: cap at 10; if more, show first 10 + “see plan”.
- OPENQ-002 [RESOLVED]: For approval tracking, should we store approvals only in plan frontmatter, or also in a dedicated “Approval & Sign-off” section? → Default: both.

## Acceptance Criteria (Plan-Level)
- All relevant agent definitions reference the structured labeling standard and use labeled templates for their `agent-output/` artifacts.
- Planner produces plans in the rigid template and uses no-silent-assumptions questioning only when ambiguity exists.
- Executive summary skill exists and is used at final approval time, listing phases/tasks/assumptions/alternatives and highlighting USER-TASK-*.
- Critic validates template compliance and USER-TASK exceptions before implementation approval.
- Execution-state schema and plan-status-reporting remain compatible and become more consistent with new labels.

## Handoff
- REQUIRED: Submit this plan to Critic for review.
- After Critic approval: proceed to Implementer.
