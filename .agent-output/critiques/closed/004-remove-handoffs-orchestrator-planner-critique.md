---
ID: 4
Origin: 4
UUID: d3f7a92e
Status: Resolved
---

# Critique: Plan 004 — Remove Handoffs & Elevate Planner to Default Orchestrator

| Date | Handoff | Request | Summary |
|------|---------|---------|---------|
| 2026-03-24 | User → Critic | Initial review | Review for clarity, completeness, and architectural alignment |
| 2026-09-15 | Critic | Document closed | Status: Resolved (findings resolved at Rev 1) |

---

## Artifact Under Review

- **Plan**: [.agent-output/planning/closed/004-remove-handoffs-orchestrator-planner.md](../../planning/closed/004-remove-handoffs-orchestrator-planner.md)
- **Analysis**: N/A (plan originated from user request)
- **Review Date**: 2026-03-24
- **Status**: Initial Review

---

## Template Validation

### Section Ordering and Presence

| Section | Present | Order | Notes |
|---------|---------|-------|-------|
| 1. Value Statement | ✅ | ✅ | User story format, clear |
| 2. Objective | ✅ | ✅ | Unnumbered but present |
| 3. Requirements & Constraints | ✅ | ✅ | REQ/SEC/CON/GUD prefixes used |
| 4. Contracts | ✅ | ✅ | States "None" appropriately |
| 5. Backwards Compatibility | ✅ | ✅ | Explicit decision documented |
| 6. Testing Scope | ✅ | ✅ | Manual verification defined |
| 7. Implementation Plan | ✅ | ✅ | 4 phases, 4 GOALs, 35 TASKs |
| 8. Alternatives | ✅ | ✅ | Two alternatives with rationale |
| 9. Dependencies | ✅ | ✅ | 4 dependencies listed |
| 10. Files | ✅ | ✅ | 14 files enumerated |
| 11. Tests | ✅ | ✅ | 5 test procedures |
| 12. Risks (with FM-*) | ✅ | ✅ | 3 risks, 3 failure modes |
| 13. Assumptions | ✅ | ✅ | 4 assumptions documented |
| 14. Open Questions | ✅ | ✅ | 2 items, both RESOLVED |
| 15. Approval & Sign-off | ✅ | ✅ | Tracking table present |
| 16. Traceability Map | ✅ | ✅ | All REQ-* items mapped |

**Template Compliance**: ✅ PASS

### Label Usage

- **REQ-***: 6 requirements, properly numbered ✅
- **SEC-***: 1 security note ✅
- **CON-***: 5 constraints ✅
- **GUD-***: 3 guidelines ✅
- **TASK-***: Global numbering 001-035 ✅
- **GOAL-***: 4 GOALs matching 4 phases (1:1) ✅
- **USER-TASK-***: None present (none required) ✅

### OPENQ Status

| ID | Status | Notes |
|----|--------|-------|
| OPENQ-001 | [RESOLVED] | Self-handoff removal decided |
| OPENQ-002 | [RESOLVED] | Retrospective terminology update decided |

**Unresolved Open Questions**: None

---

## Value Statement Assessment

**Value Statement**:
> "As a user of the agent framework, I want all manual handoff UI elements removed from agents and the Planner updated to act as a true orchestrator that delegates work to subagents when asked to 'execute until completion,' so that I no longer need to manually switch between agents and the workflow runs end-to-end when I grant permission."

**Assessment**: ✅ STRONG

The value statement directly addresses the user's stated problem: "the Planner tells them to 'switch to Implementer' instead of delegating directly." The "so that" clause is concrete and verifiable: end-to-end workflow without manual switching.

---

## Overview

Plan 004 proposes three coordinated changes:
1. Remove all `handoffs:` YAML frontmatter blocks (13 agents)
2. Elevate Planner orchestration from "optional" to "default mode"
3. Replace all handoff/switch language with delegation terminology

The scope is well-bounded (text changes to agent files only) and the implementation phases are logical: remove YAML blocks → update Planner → update other agents → sync and verify.

---

## Architectural Alignment

**Alignment with execution-orchestration skill**: ✅

The plan correctly references the existing `execution-orchestration` and `planner-execution-orchestration` skills as the behavioral contract. It does NOT propose changes to these skills, only to the Planner's instructions to make orchestration the default rather than optional.

**Alignment with document-lifecycle**: ✅

The plan doesn't affect document lifecycle. Agent instruction changes don't impact ID/Origin/UUID/Status protocols.

**Canonical source enforcement**: ✅

Plan correctly identifies `vs-code-agents/` as canonical and includes sync step (TASK-032).

---

## Scope Assessment

**Scope**: Appropriate for a single plan. 

- 13 agent files affected, but changes are repetitive (same operation per file)
- ~35 discrete tasks is borderline large, but all are simple text edits
- No code changes, no new features, no architectural shifts
- Single cohesive objective: transition from manual handoffs to automated orchestration

**Scope Risk**: LOW — the work is mechanical and verifiable.

---

## Technical Debt Risks

1. **Body text inconsistency risk**: Different agents use different phrasing ("handoff to", "hand off to", "switch to"). Grep patterns may miss variants.

2. **Retrospective metrics terminology**: The retrospective agent tracks "Total Handoffs" and "Handoff Chain" as metrics. Renaming these to "delegation" terminology is called out in TASK-028, but the impact on historical retrospective reports is not addressed.

---

## Findings

### M-001: Tool capability remediation not actionable (Medium)

| Field | Value |
|-------|-------|
| Status | RESOLVED |
| Section | REQ-006, CON-002, TASK-014 |
| Description | TASK-014 says "Verify each agent's `tools:` array includes `'agent'` capability; **add where missing**." However, TEST-005 only says "Verify every agent's `tools:` array includes the `'agent'` capability." The test verifies but doesn't specify the remediation action if verification fails. |
| Impact | If an agent lacks the `'agent'` tool, the implementer may not know to add it, leading to FM-002 (silent orchestration failure). |
| Recommendation | Update TASK-014 to two explicit subtasks: (a) verify presence, (b) add `'agent'` to `tools:` array for any agent missing it. Update TEST-005 to include expected count (13 agents, 13 should have it). |

### M-002: Grep patterns may miss body text variants (Medium)

| Field | Value |
|-------|-------|
| Status | RESOLVED |
| Section | TASK-035, TEST-003 |
| Description | TASK-035 says to verify no directive-sense "switch to the [Agent]" or "hand off to [Agent]" remains. But actual agent body text uses phrases like "Handoff to Planner" (capital H, no "the"), "handoff to QA" (lowercase), and "Hand off to Retrospective" (mixed case, spaces). The regex in TEST-003 (`switch to the.*agent\|hand off to`) may miss "Handoff" (no space, capital H). |
| Impact | Residual legacy handoff language could remain undetected, partially defeating the plan's objective. |
| Recommendation | Standardize the grep pattern in TEST-003 to: `grep -riE "(switch to|hand\s*off\s*to)" vs-code-agents/*.agent.md` (case-insensitive, optional space in "handoff"). Add this pattern to TASK-035 explicitly. |

### M-003: RISK-001 mitigation is indirect (Medium)

| Field | Value |
|-------|-------|
| Status | RESOLVED |
| Section | RISK-001 |
| Description | RISK-001 ("Agents lose context in subagent mode") cites the execution-orchestration skill's delegation contract as mitigation. However, the plan adds no new enforcement or validation that the Planner will follow this contract when orchestrating. The mitigation is "the skill exists" rather than "the plan ensures compliance." |
| Impact | Context loss could still occur if Planner omits delegation context. The risk is acknowledged but not actively addressed by this plan. |
| Recommendation | Accept this as a known limitation (outside scope of this plan) OR add a TASK to include a checklist/reminder in the Planner's orchestration instructions referencing the delegation contract requirements. |

### L-001: Minor section numbering inconsistency (Low)

| Field | Value |
|-------|-------|
| Status | RESOLVED |
| Section | Entire plan |
| Description | Section 1 uses "## 1. Value Statement", Section 2 uses "## Objective" (no number), Section 3 uses "## 3. Requirements" (number). Inconsistent numbering style. |
| Impact | Cosmetic. Does not affect plan execution. |
| Recommendation | Normalize section headings to follow consistent pattern (e.g., all numbered or none numbered). |

---

## Questions for Planner

1. **Tool capability gap**: If an agent is missing the `'agent'` tool capability, should the implementer add it to the `tools:` array, or is this a blocker requiring user decision?

2. **Retrospective metrics history**: Renaming "Handoff" metrics to "Delegation" metrics in the retrospective agent — does this affect interpretation of historical retrospective reports, or are those metrics computed fresh each time?

---

## Risk Assessment

| Risk Level | Count |
|------------|-------|
| Critical (C-*) | 0 |
| High (H-*) | 0 |
| Medium (M-*) | 3 |
| Low (L-*) | 1 |

**Overall Risk**: LOW

This plan is low-risk because:
- All changes are text edits to instruction files (no code changes)
- Changes are verifiable via grep and diff
- Rollback is trivial (git revert)
- The existing orchestration skills already define the behavioral contract

---

## Hotfix Scenario Analysis

Per Critic protocol: "How will this plan result in a hotfix after deployment?"

**Likely hotfix scenarios**:

1. **Missed handoff language** (M-002 → FM-003): A user reports the Planner still says "switch to Implementer." Fix: grep for the missed phrase, update the agent file.

2. **Missing `'agent'` tool** (M-001 → FM-002): Planner tries to delegate to an agent that lacks the tool capability. Orchestration silently fails. Fix: add `'agent'` to that agent's `tools:` array.

**Hotfix severity**: LOW — all fixes are single-line text edits to agent instruction files. No code deployment, no data migration, no API changes.

---

## Recommendations

1. **Address M-001**: Make TASK-014 explicitly two-step (verify + remediate). This is a quick fix that prevents FM-002.

2. **Address M-002**: Update the grep pattern to be more comprehensive. This is a quick fix that improves verification confidence.

3. **Accept M-003**: The delegation contract enforcement is outside this plan's scope. Note it as a known gap for future improvement.

4. **Accept L-001**: Cosmetic; not worth revision.

---

## Verdict

**APPROVED_WITH_CHANGES**

The plan is well-structured, addresses the user's stated problem, and follows the template correctly. The identified findings are all Medium or Low severity and do not fundamentally undermine the plan's objectives.

**Required changes before implementation**:
- Address M-001 (clarify tool capability remediation)
- Address M-002 (standardize grep pattern)

**Optional**:
- Address M-003 (add delegation contract reminder to Planner instructions)
- Address L-001 (normalize section numbering)

---

## Revision History

| Date | Revision | Changes | Findings Addressed | New Findings | Status |
|------|----------|---------|-------------------|--------------|--------|
| 2026-03-24 | Initial | First review | — | M-001, M-002, M-003, L-001 | OPEN |
| 2026-03-24 | Rev 1 | Planner addressed all findings | M-001, M-002, M-003, L-001 | None | RESOLVED |
