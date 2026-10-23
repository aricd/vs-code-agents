---
ID: 998
Origin: 998
Status: Active
Review_State: pending
---

# Plan: Test Fixture - Invalid Plan (Missing UUID)

Epic Alignment: Testing / Validator parity

## Changelog
| Date | Agent | Change | Notes |
|---|---|---|---|
| 2026-02-09 | Planner | Created | Intentionally invalid fixture |
| 2026-03-24 | Implementer | Updated | Added traceability map violation |
| 2026-05-28 | Implementer | Updated | Added invalid Review_State (Plan 009) |
| 2026-06-30 | Implementer | Updated | Added undeclared FM ID case (Plan 022) |

## Value Statement
This plan intentionally omits the "As a [user], I want..." format.

## Implementation Plan

### Phase 1 — Broken
GOAL-001: Missing required sections

| Task | Description | Status | Owner |
|---|---|---|---|
| TASK-001 | Incomplete plan | not-started | nobody |

### FM Exposure

| ID | Why plausibly touched |
|---|---|
| FM-DECLARED-001 | test fixture -- FM-WRONG-001 in Traceability Map intentionally does not match this |

## Open Questions (OPENQ-*)
- **OPENQ-001**: Unresolved question without resolution marker

## Traceability Map
| Requirement | Tasks | Tests | Risk | Failure Mode |
|-------------|-------|-------|------|--------------|
| REQ-999 (nonexistent) | TASK-999 | TEST-999 | RISK-999 | FM-WRONG-001 |

<!-- 
INTENTIONAL ERRORS IN THIS FIXTURE:
1. Missing UUID in frontmatter
2. Invalid Review_State value 'pending' (must be: draft, architect-review, critic-review, awaiting-user-approval, approved, rejected)
3. Value Statement missing "As a [user], I want..." format
4. Missing required sections: Objective, Requirements & Constraints, 
   Backwards Compatibility, Testing Scope, Dependencies, Files, 
   Tests, Risks, Assumptions, Approval & Sign-off
5. Unresolved OPENQ-001
6. Traceability Map references TASK-999, TEST-999, RISK-999 which don't exist in the plan body
   (NOTE: REQ-999 is not validated since Requirements section is absent)
7. Traceability Map FM cell 'FM-WRONG-001' is not declared in FM Exposure (FM-001 error)
   FM Exposure declares 'FM-DECLARED-001'; cell contains 'FM-WRONG-001' -- mismatch is intentional
-->
