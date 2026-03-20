```skill
---
name: executive-summary
description: Generate an approval-time executive summary from an active plan. Produces a concise Markdown summary in chat (not a file) covering scope, phases, assumptions, alternatives, risks, and open questions before asking for user approval.
license: MIT
metadata:
  author: groupzer0
  version: "1.0"
---

# Executive Summary Skill

Generates an approval-time executive summary for a single active plan. Used by Planner (and potentially other agents) to present a focused overview before requesting user approval.

---

## Purpose

Provide a concise, approval-oriented summary of a plan's scope, status, and key decisions without copying the full plan. The summary:
- Informs the user of what they're approving
- Highlights USER-TASK-* items that require human action
- Surfaces risks, assumptions, and open questions
- Ends with an explicit approval prompt

---

## Activation Triggers

Load this skill when:
- **Final approval time**: After Critic approves the plan, before asking user for approval
- **Early approval**: User indicates approval before Planner expects it—still produce the summary and continue

---

## Relationship to Other Skills

| Skill | Purpose | Scope | Orientation |
|-------|---------|-------|-------------|
| `executive-summary` | Single-plan overview at approval time | One plan | Plan-centric, approval-oriented |
| `plan-status-reporting` | Cross-plan progress and evidence | Multiple plans | Execution-oriented, evidence-based |

**Both skills coexist. Neither replaces the other.**

- Use `executive-summary` when seeking user approval for a specific plan
- Use `plan-status-reporting` when reporting progress across active plans

---

## Output Requirements

### Format

- **Target**: Markdown output in chat (conversational response)
- **NOT a file**: Do not create a separate document; emit directly in response

### Required Sections

The executive summary MUST include these sections in order:

#### 1. Plan Identity

| Field | Source |
|-------|--------|
| ID | Plan frontmatter `ID` |
| Title | Plan title (H1 heading) |
| Last Updated | Most recent changelog entry date |
| Current Status | Plan frontmatter `Status` |

**Example**:
```markdown
## Executive Summary: Plan 003

| Field | Value |
|-------|-------|
| ID | 3 |
| Title | Unified Labeled Planning + No-Silent-Assumptions + Executive Summary |
| Last Updated | 2026-02-08 |
| Status | Active |
```

#### 2. Scope Snapshot

List REQ-*, SEC-*, CON-* items from the plan.

**Capping Rule**:
- If ≤10 items total: list all
- If >10 items: show first 10, then add "... see plan for full list (N total items)"

**Example**:
```markdown
### Scope

- REQ-001: All agents produce labeled artifacts
- REQ-002: Planner uses rigid template
- SEC-001: No credential storage in plans
- CON-001: Must maintain VS Code 1.85+ compatibility
```

#### 3. Phases Overview

For each phase, show phase name + GOAL-* + phase status.

**Status-based detail rules**:
- If phase is `not-started` or `complete`: list only phase + status (no task details)
- If phase is `in-progress`: list all tasks with TASK-* + status

**Example**:
```markdown
### Phases

| Phase | Goal | Status |
|-------|------|--------|
| Phase 1 — Labeling & Templates | GOAL-001: Define and adopt rigid labeled templates | complete |
| Phase 2 — No-Silent-Assumptions | GOAL-002: Prevent hidden scope/contract assumptions | complete |
| Phase 3 — Executive Summary | GOAL-003: Add approval-time executive summary | in-progress |

#### Phase 3 Tasks (in-progress)

| Task | Description | Status |
|------|-------------|--------|
| TASK-008 | Create executive-summary skill | in-progress |
| TASK-009 | Update Planner for executive summary | not-started |
| TASK-010 | Document approval tracking schema | not-started |
```

#### 4. USER-TASK Items (CRITICAL)

**This section is MANDATORY if any USER-TASK-* items exist.**

USER-TASK items MUST be:
- Listed prominently with justification summary
- Shown BEFORE the approval prompt
- Never hidden or buried

**Example**:
```markdown
### ⚠️ User Action Required (USER-TASK)

| ID | Description | Justification |
|----|-------------|---------------|
| USER-TASK-001 | Configure API key in settings | Credentials cannot be auto-provisioned |
| USER-TASK-002 | Approve license agreement | Legal acknowledgment required from human |

**You must complete these actions manually during or after implementation.**
```

If no USER-TASK items exist, state: "No USER-TASK items — this plan is fully automatable."

#### 5. Assumptions

List ASSUMPTION-* items (at least titles). Highlight high-risk assumptions.

**Example**:
```markdown
### Assumptions

- ASSUMPTION-001: Agents can load skills by name
- ASSUMPTION-002: Users prefer mega-plans over multiple small plans
- ⚠️ ASSUMPTION-003 (HIGH RISK): External API availability assumed stable
```

#### 6. Alternatives

List ALT-* items with 1–3 sentence rationale each.

**Example**:
```markdown
### Alternatives Considered

- **ALT-001**: Store state in SQLite — Rejected: over-engineering for current scope; JSON files sufficient
- **ALT-002**: Use YAML instead of Markdown — Rejected: Markdown better for human readability and VS Code rendering
```

If no alternatives exist in the plan, state: "No alternatives documented."

#### 7. Risks

Include top RISK-* items with ⚠️ marker.

**Example**:
```markdown
### Risks

- ⚠️ RISK-001: Rigid templates increase friction initially — Mitigation: clear examples + auto-validation
- ⚠️ RISK-002: Over-labeling leads to noisy docs — Mitigation: "when applicable" rule
```

#### 8. Open Questions

List any OPENQ-* items remaining. Mark blocking ones explicitly.

**Example**:
```markdown
### Open Questions

- OPENQ-001 [RESOLVED]: Cap scope lists at 10 items? → Yes
- OPENQ-002 [RESOLVED]: Store approvals in frontmatter and section? → Yes
- ⚠️ OPENQ-003 [BLOCKING]: Performance SLA not yet defined — MUST resolve before approval
```

If no open questions remain (all resolved/closed), state: "All open questions resolved."

#### 9. Approval Prompt (MANDATORY)

End with an explicit approval prompt:

```markdown
---

**The plan is ready for approval. Do you approve?**
```

---

## Output Constraints

The executive summary MUST NOT:
- **Copy the entire plan verbatim** — summarize, don't duplicate
- **Introduce new requirements** — reflect only what's in the plan
- **Hide USER-TASK-* items** — these MUST be prominent

---

## Template

Use this template when generating the executive summary:

````markdown
## Executive Summary: Plan [ID]

| Field | Value |
|-------|-------|
| ID | [plan ID] |
| Title | [plan title] |
| Last Updated | [most recent changelog date] |
| Status | [frontmatter Status] |

### Scope

[List REQ-*, SEC-*, CON-* items; cap at 10]

### Phases

| Phase | Goal | Status |
|-------|------|--------|
| [Phase name] | [GOAL-*] | [status] |

[If any phase is in-progress, add task table for that phase]

### ⚠️ User Action Required (USER-TASK)

[List USER-TASK-* with justifications, OR "No USER-TASK items — this plan is fully automatable."]

### Assumptions

[List ASSUMPTION-* items; mark high-risk with ⚠️]

### Alternatives Considered

[List ALT-* with 1–3 sentence rationale, OR "No alternatives documented."]

### Risks

[List top RISK-* with ⚠️ markers]

### Open Questions

[List OPENQ-* with resolution status; mark blocking with ⚠️ BLOCKING]

---

**The plan is ready for approval. Do you approve?**
````

---

## Validation Checklist

Before emitting the summary, verify:

- [ ] Plan identity (ID, title, last-updated, status) present
- [ ] Scope snapshot includes REQ/SEC/CON items (capped at 10 if needed)
- [ ] All phases listed with GOAL-* and status
- [ ] In-progress phases show task details
- [ ] USER-TASK items (if any) are prominently listed with justifications
- [ ] Assumptions listed (high-risk marked)
- [ ] Alternatives listed with rationale
- [ ] Top risks listed with ⚠️
- [ ] Open questions listed; blocking ones marked
- [ ] Summary ends with explicit approval prompt
- [ ] No verbatim plan copy
- [ ] No new requirements introduced
- [ ] USER-TASK items not hidden

```
