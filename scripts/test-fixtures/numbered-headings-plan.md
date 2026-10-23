---
ID: 996
Origin: 996
UUID: test-numbered-headings
Status: Active
Review_State: approved
---

# Plan: Test Fixture - Numbered Headings (Guarantee Column)

Epic Alignment: Testing / Validator parity Target Release: N/A (test fixture)

## Changelog

| Date | Agent | Change | Notes |
| --- | --- | --- | --- |
| 2026-09-01 | Implementer | Created | Fixture using this repo's numbered-heading convention throughout (H-003, Plan 030) -- proves Test-TraceabilityMap's checks actually execute against a '## 17. Traceability Map' heading, and exercises the Guarantee column present-with-valid-ID case (TEST-001/TEST-002) |
| 2026-09-07 | Implementer | Added parser boundaries | Nested Requirements subsection, out-of-section REQ sentinel, distinct phases/GOAL IDs, and a later repeated GOAL citation |

## 1. Value Statement and Business Objective

As a validator maintainer, I want a fixture that uses the numbered-heading convention every real plan uses, so that I can verify the Traceability Map checks (including the new Guarantee-column check) actually execute against it instead of silently no-opping (H-003).

## 2. Objective

Provide a valid plan whose headings all use the "## N. Section Name" numbered form, with a 6-column Traceability Map (including Guarantee) exercising both a declared `G-*` ID and an absent (`--`) Guarantee cell.

## 3. Constraints

### Requirements

- **REQ-001**: This fixture must pass validation (Guarantee column present, one row references a real `G-*` ID from `guarantees/LEDGER.md`)
- **REQ-002**: This fixture's Traceability Map must use the numbered `## 17. Traceability Map` heading form

### Boundary Sentinel

`REQ-999` is outside the Requirements subsection and intentionally has no Traceability Map row.

## 4. Contracts (CONTRACT-\*)

**CONTRACT-001**: No contracts for this test fixture.

## 5. Backwards Compatibility (BACKCOMPAT-\*)

**BACKCOMPAT-001**: Not applicable (test fixture).

## 6. Testing Scope (TEST-SCOPE-\*)

- **TEST-SCOPE-001**: Unit: Validate numbered-heading tolerance and Guarantee-column behavior

## 7. Implementation Plan

### Phase 1 - Test Setup

GOAL-001: Create fixture

| Task     | Description           | Status   | Owner   | Date       |
| -------- | --------------------- | -------- | ------- | ---------- |
| TASK-001 | Create fixture file   | complete | planner | 2026-09-01 |
| TASK-002 | Add numbered headings | complete | planner | 2026-09-01 |

### Phase 2 - Boundary Cases

GOAL-002: Exercise section and identity boundaries

| Task     | Description                   | Status   | Owner   | Date       |
| -------- | ----------------------------- | -------- | ------- | ---------- |
| TASK-003 | Add parser boundary sentinels | complete | planner | 2026-09-07 |

## 8. Alternatives (ALT-\*)

- **ALT-001**: None considered (test fixture).

## 9. Deferred Items (DEFER-\*)

None identified.

## 10. Dependencies (DEP-\*)

- **DEP-001**: None.

## 11. Files (FILE-\*)

- **FILE-001**: scripts/test-fixtures/numbered-headings-plan.md (this file)

## 12. Tests (TEST-\*)

- **TEST-001**: Run validators against this file - PASS, with Traceability Map checks actually executing (not silently no-op'd)
- **TEST-002**: Verify the Guarantee-column check does not WARN when the column is present
- **TEST-003**: Verify the completed `GOAL-002` remains traceable without changing the distinct GOAL count

## 13. Risks (RISK-\*)

- **RISK-001**: None (test fixture).

### FM Exposure

Declared against: no registry (meta-repo test fixture)

| ID | Why plausibly touched |
| --- | --- |
| FM-CANDIDATE-002 | test fixture -- exercises declared-ID validation path against a numbered-heading Traceability Map |

## 14. Assumptions (ASSUMPTION-\*)

- **ASSUMPTION-001**: Both validators are available.

## 15. Open Questions (OPENQ-\*)

- **OPENQ-001 [RESOLVED]**: Is this fixture complete? - Yes.

## 16. Approval & Sign-off

- User: N/A (test fixture)

## 17. Traceability Map

| Requirement | Tasks | Tests | Risk | Failure Mode | Guarantee |
| --- | --- | --- | --- | --- | --- |
| REQ-001 (guarantee) | TASK-001, TASK-002 | TEST-001, TEST-002 | RISK-001 | FM-CANDIDATE-002 | G-T-OPENQGATE |
| REQ-002 (numbered heading) | TASK-002 | TEST-001 | -- | -- | -- |
