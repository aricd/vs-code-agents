```skill
---
name: structured-labeling
description: Defines required label prefixes, numbering rules, section ordering, status enum, and approval tracking for all agent-output artifacts. Authoritative source for plan template compliance.
license: MIT
metadata:
  author: groupzer0
  version: "1.0"
---

# Structured Labeling Skill

Authoritative standard for labeled templates across all planning-related artifacts in `agent-output/`.

---

## Purpose

Ensure all agents that write to `agent-output/` produce artifacts using structured labels (REQ-*, CON-*, TASK-*, ALT-*, etc.) with deterministic numbering rules. This enables scope correctness, alternative visibility, and confident approval without hidden constraints.

---

## Required Label Prefixes

All agents producing `agent-output/` artifacts MUST use these prefixes when applicable:

### Requirements & Constraints

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `REQ-*` | Requirement | Functional or non-functional requirement that MUST be met | `REQ-001: System MUST support async file operations` |
| `SEC-*` | Security Requirement | Authentication, authorization, data protection, threat posture | `SEC-001: All API calls MUST use authenticated sessions` |
| `CON-*` | Constraint | Hard limitation: technology, time, compatibility, policy | `CON-001: MUST maintain compat with VS Code 1.85+` |
| `GUD-*` | Guideline | Preferred practice; deviation allowed with justification | `GUD-001: PREFER composition over inheritance` |
| `PAT-*` | Pattern | Required architectural or structural pattern to follow | `PAT-001: Apply Repository pattern for data access` |

### Contracts & Compatibility

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `CONTRACT-*` | Proposed Contract | Provisional interface/boundary contract THIS PLAN proposes or creates (not existing external APIs) | `CONTRACT-001: MemoryStore.save(entry: MemoryEntry): Promise<void>` |
| `BACKCOMPAT-*` | Backwards Compatibility | Explicit backwards compatibility posture/decision (even if "not required") | `BACKCOMPAT-001: Save-file format MUST remain compatible with v1.x` |

### Testing

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `TEST-SCOPE-*` | Testing Scope | Testing depth posture (unit/integration/e2e) and expectations | `TEST-SCOPE-001: Unit tests REQUIRED; integration tests for API layer` |
| `TEST-*` | Test Procedure | Executable tests to be created or run (procedures, files, suites) | `TEST-001: Add unit tests for MemoryStore.save() edge cases` |

### Planning Structure

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `GOAL-*` | Phase Goal | Exactly one GOAL per implementation phase (1:1 mapping with phases) | `GOAL-001: Establish repo-wide labeling standard` |
| `TASK-*` | Task | Discrete implementation task; numbering is GLOBAL across all phases | `TASK-001: Create structured-labeling skill` |
| `USER-TASK-*` | User Task | **EXCEPTION CLASS**: Intentional human action required; MUST be justified, Critic-approved, and highlighted before user approval | `USER-TASK-001: User must configure API key in settings` |

### Traceability

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `FILE-*` | File Reference | File(s) expected to change, create, or be validated | `FILE-001: vs-code-agents/skills/structured-labeling/SKILL.md` |
| `DEP-*` | Dependency | Existing external dependency this plan consumes (NOT proposed contracts) | `DEP-001: Relies on no-silent-assumptions skill` |

### Alternatives & Risk

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `ALT-*` | Alternative | Alternative approach considered, with rationale and execution implications | `ALT-001: Store state in SQLite (rejected: over-engineering)` |
| `RISK-*` | Risk | Identified risk with mitigation strategy | `RISK-001: Template friction initially → mitigate with examples` |
| `ASSUMPTION-*` | Assumption | Explicit assumption (MUST NOT be buried in prose) | `ASSUMPTION-001: Agents can load skills by name` |
| `OPENQ-*` | Open Question | Explicitly unanswered question; MUST be listed before handoff | `OPENQ-001: Should REQ lists be capped at 10?` |

---

## Numbering Rules

### Independent Numbering (Per Section)

Each prefix restarts at 001 within its section:

```markdown
## Requirements
- REQ-001: First requirement
- REQ-002: Second requirement

## Security Requirements
- SEC-001: First security requirement

## Constraints
- CON-001: First constraint
```

### Global Numbering (TASK-* Only)

TASK numbers are global across all phases. Do NOT restart at each phase:

```markdown
### Phase 1
- TASK-001: First task
- TASK-002: Second task

### Phase 2
- TASK-003: Continues from Phase 1
- TASK-004: Fourth task globally
```

### GOAL Numbering

One GOAL per phase, numbered sequentially: GOAL-001, GOAL-002, etc.

---

## Plan Template (Rigid, Fixed Ordering)

Planner's plan output MUST follow this section order. Sections may be omitted only if explicitly marked "if applicable" below.

| Order | Section | Required | Notes |
|-------|---------|----------|-------|
| 1 | Value Statement and Business Objective | ✅ Always | User story format required |
| 2 | Objective | ✅ Always | Clear, measurable outcome |
| 3 | Requirements & Constraints (REQ/SEC/CON/GUD/PAT) | ✅ Always | Group by prefix type |
| 4 | Contracts (CONTRACT-*) | ⚠️ If applicable | State "None" if not relevant |
| 5 | Backwards Compatibility (BACKCOMPAT-*) | ✅ Always | Explicit decision required |
| 6 | Testing Scope (TEST-SCOPE-*) | ✅ Always | Unit required; integration/e2e default-able |
| 7 | Implementation Plan | ✅ Always | Contains phases, GOALs, TASKs |
| 7a | → Phase N Header | Per phase | Named implementation phase |
| 7b | → GOAL-00N | Per phase | Exactly one GOAL per phase |
| 7c | → TASK Table | Per phase | Global TASK numbering |
| 7d | → USER-TASK Table | ⚠️ If any | Only if justified |
| 8 | Alternatives (ALT-*) | ⚠️ If applicable | State "None" if not warranted |
| 9 | Dependencies (DEP-*) | ✅ Always | List external dependencies |
| 10 | Files (FILE-*) | ✅ Always | Expected file changes |
| 11 | Tests (TEST-*) | ✅ Always | Specific test procedures |
| 12 | Risks (RISK-*) | ✅ Always | Identified risks + mitigations |
| 13 | Assumptions (ASSUMPTION-*) | ✅ Always | Explicit assumptions |
| 14 | Open Questions (OPENQ-*) | ✅ Always | Unresolved questions |
| 15 | Approval & Sign-off | ✅ Always | User/Critic/Architect tracking |
| 16 | Traceability Map | ⚠️ Recommended | Phase→File mapping |

---

## Standard Task Statuses

Allowed values (canonical form: **lowercase hyphenated**):

| Status | Meaning |
|--------|---------|
| `not-started` | Work has not begun |
| `in-progress` | Work is actively underway |
| `complete` | Work is finished and verified |
| `blocked` | Work cannot proceed; blocker documented |
| `deferred` | Work postponed; rationale documented |

**Normalization Rule**: When summarizing or reporting status, always use the canonical lowercase-hyphenated form. Accept case-insensitive input but output canonical form.

---

## USER-TASK Policy (Exception Class)

USER-TASK-* items require human interpretation or action. They are exceptions to the goal of fully deterministic plans.

### Requirements for USER-TASK

1. **Justification Required**: Each USER-TASK MUST include rationale explaining why automation is not possible
2. **Critic Approval Required**: Critic MUST explicitly approve each USER-TASK as unavoidable
3. **User Notification Required**: USER-TASK items MUST be:
   - Listed in a dedicated section in the plan body
   - Restated prominently in the Executive Summary (when produced)
   - Shown BEFORE the approval prompt with justification summary

### USER-TASK Table Format

```markdown
| ID | Description | Justification | Critic Approved |
|----|-------------|---------------|-----------------|
| USER-TASK-001 | User must configure API key | Credentials cannot be auto-provisioned | ✅ / ⏳ |
```

---

## Executive Summary Required Fields

At final approval time, the Executive Summary MUST include:

| Field | Description |
|-------|-------------|
| Plan Identity | ID, title, last-updated, current Status |
| Scope Snapshot | REQ/SEC/CON items (cap at 10; if more, show first 10 + "see plan for full list") |
| Phases Overview | For each phase: phase name + GOAL-* + phase status |
| In-Progress Details | If phase started: list tasks with TASK-* + status |
| USER-TASK Highlight | List prominently with justification summary; MUST be shown before approval prompt |
| Assumptions | List ASSUMPTION-* (at least titles); highlight high-risk ones |
| Alternatives | List ALT-* with 1–3 sentence rationale each |
| Risks | Include top RISK-* with ⚠️ marker |
| Open Questions | List any OPENQ-* remaining; mark blocking ones as "BLOCKING" |

### Executive Summary MUST NOT

- Copy the entire plan verbatim
- Introduce new requirements
- Hide USER-TASK-* items

---

## Approval Tracking Frontmatter Schema

Plan documents SHOULD include approval tracking fields in frontmatter, in addition to the "Approval & Sign-off" section.

These fields are OPTIONAL additions to the mandatory ID/Origin/UUID/Status header.

### Schema

```yaml
---
ID: [number]
Origin: [number]
UUID: [8-char hex]
Status: [lifecycle status]

# Approval Tracking (all fields optional; use null for unset dates)
User_Approved: false
User_Approved_Date: null           # ISO-8601 date when user approves
Critic_Approved: false
Critic_Approved_Date: null         # ISO-8601 date when Critic approves
Architect_Reviewed: false          # optional; for significant architectural plans
Architect_Reviewed_Date: null      # ISO-8601 date when Architect reviews
UAT_Approved: false
UAT_Approved_Date: null            # ISO-8601 date when UAT passes
DevOps_Committed: false
DevOps_Committed_Date: null        # ISO-8601 date when committed locally
DevOps_Released: false             # optional; for released work
DevOps_Released_Date: null         # ISO-8601 date when pushed/published
---
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `User_Approved` | boolean | Whether user has approved the plan |
| `User_Approved_Date` | ISO-8601 / null | Date when user approved |
| `Critic_Approved` | boolean | Whether Critic has approved the plan |
| `Critic_Approved_Date` | ISO-8601 / null | Date when Critic approved |
| `Architect_Reviewed` | boolean | Whether Architect has reviewed (optional) |
| `Architect_Reviewed_Date` | ISO-8601 / null | Date when Architect reviewed |
| `UAT_Approved` | boolean | Whether UAT has validated value delivery |
| `UAT_Approved_Date` | ISO-8601 / null | Date when UAT passed |
| `DevOps_Committed` | boolean | Whether DevOps has committed changes |
| `DevOps_Committed_Date` | ISO-8601 / null | Date when committed locally |
| `DevOps_Released` | boolean | Whether changes have been pushed/published |
| `DevOps_Released_Date` | ISO-8601 / null | Date when released |

### Field Ownership

Each field is populated ONLY by its designated agent:

| Field | Populated By | When |
|-------|--------------|------|
| `User_Approved`, `User_Approved_Date` | Planner (after user approval) | When user approves plan in conversation |
| `Critic_Approved`, `Critic_Approved_Date` | Critic | When critique findings resolved |
| `Architect_Reviewed`, `Architect_Reviewed_Date` | Architect | When architectural review complete (if applicable) |
| `UAT_Approved`, `UAT_Approved_Date` | UAT | When value delivery validated |
| `DevOps_Committed`, `DevOps_Committed_Date` | DevOps | When changes committed locally |
| `DevOps_Released`, `DevOps_Released_Date` | DevOps | When changes pushed/published |

### Both Frontmatter and Section

Approval tracking appears in BOTH:
1. Frontmatter (machine-readable, for status queries)
2. "Approval & Sign-off" section (human-readable, with signatures/dates)

---

## Agent Coverage (Authoritative Mapping)

All agents that write artifacts to `agent-output/` MUST adopt structured labels appropriate to their domain:

| Agent | Output Directory | Primary Labels | Notes |
|-------|------------------|----------------|-------|
| Planner | `agent-output/planning/` | All labels | Full template required |
| Critic | `agent-output/critiques/` | Finding IDs (C-*, H-*, M-*) | Critique format |
| Analyst | `agent-output/analysis/` | ASSUMPTION-*, OPENQ-*, findings | Analysis format |
| Implementer | `agent-output/implementation/` | TASK-*, FILE-*, TEST-* | Implementation format |
| Code Reviewer | `agent-output/code-review/` | Finding IDs, FILE-* | Review format |
| QA | `agent-output/qa/` | TEST-*, TEST-SCOPE-* | QA format |
| UAT | `agent-output/uat/` | Value validation | UAT format |
| DevOps | `agent-output/deployment/` | Deployment tracking | Deployment format |
| Security | `agent-output/security/` | SEC-*, RISK-*, findings | Security format |
| Roadmap | `agent-output/roadmap/` | Epic tracking | Roadmap format |
| Retrospective | `agent-output/retrospective/` | Process findings | Retrospective format |
| PI | `agent-output/pi/` | Analysis synthesis | PI format (if used) |

---

## Validation Checklist

Before handoff, verify:

### For Plans (Planner → Critic)

- [ ] All 16 sections present in correct order (or marked "None" where optional)
- [ ] Value Statement in "As a/I want/So that" format
- [ ] All applicable labels used with proper prefixes
- [ ] TASK numbering is global (not restarting per phase)
- [ ] GOAL numbering matches phases (1:1)
- [ ] USER-TASK items (if any) have justification
- [ ] No unresolved OPENQ-* without user acknowledgment
- [ ] BACKCOMPAT decision explicitly stated
- [ ] TEST-SCOPE defined (even if "unit tests only")

### For All Artifacts

- [ ] Document header present (ID, Origin, UUID, Status)
- [ ] Changelog table included
- [ ] Status field accurate and current
- [ ] Labels used consistently within the document

---

## Quick Reference

### Creating a Plan Section

```markdown
## Requirements

- REQ-001: [Requirement description]
- REQ-002: [Requirement description]

## Security Requirements

- SEC-001: [Security requirement]

## Constraints

- CON-001: [Hard constraint]
```

### Creating a Phase

```markdown
### Phase 1 — [Phase Name]

GOAL-001: [Phase objective]

| Task | Description | Status | Owner | Date |
|------|-------------|--------|-------|------|
| TASK-001 | [Description] | not-started | implementer | |
| TASK-002 | [Description] | not-started | implementer | |
```

### Marking Resolved Questions

```markdown
- OPENQ-001 [RESOLVED]: Should X do Y? → Answer: Yes, because Z.
- OPENQ-002 [CLOSED]: Not applicable for this scope.
```

```
