---
ID: 999
Origin: 999
UUID: test-valid
Status: Active
Review_State: approved
---

# Plan: Test Fixture - Valid Plan

Epic Alignment: Testing / Validator parity Target Release: N/A (test fixture)

## Changelog

| Date | Agent | Change | Notes |
| --- | --- | --- | --- |
| 2026-02-09 | Planner | Created | Test fixture for validator parity |
| 2026-03-24 | Implementer | Updated | Added FM-\* and new Traceability Map format |
| 2026-05-28 | Implementer | Updated | Added Review_State field (Plan 009) |
| 2026-06-14 | Implementer | Updated | FM Exposure model (Plan 017, ADR-002) |
| 2026-06-30 | Implementer | Updated | Added declared FM ID path to exercise FM-001/FM-002 (Plan 022) |
| 2026-09-01 | Implementer | Updated | Added Deferred Items ("None identified" form) at position 9 to keep pace with the new required section; Traceability Map intentionally kept 5-column (no Guarantee) to regression-test the absent-Guarantee-column WARNING-only behavior (Plan 030) |

## Value Statement and Business Objective

As a validator maintainer, I want a known-good plan fixture, so that I can verify validators pass valid plans.

## Objective

Provide a minimal valid plan that passes both PowerShell and bash validators.

## Requirements & Constraints

- **REQ-001**: This fixture must pass validation
- **REQ-002**: Must include all required sections
- **CON-001**: Must follow structured-labeling template

## Contracts (CONTRACT-\*)

**CONTRACT-001**: No contracts for this test fixture.

## Backwards Compatibility (BACKCOMPAT-\*)

**BACKCOMPAT-001**: Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- **TEST-SCOPE-001**: Unit: Validate plan structure

## Implementation Plan

### Phase 1 - Test Setup

GOAL-001: Create valid fixture

| Task     | Description           | Status   | Owner   | Date       |
| -------- | --------------------- | -------- | ------- | ---------- |
| TASK-001 | Create fixture file   | complete | planner | 2026-02-09 |
| TASK-002 | Add required sections | complete | planner | 2026-02-09 |

## Alternatives (ALT-\*)

- **ALT-001**: None considered (test fixture).

## Deferred Items (DEFER-\*)

None identified.

## Dependencies (DEP-\*)

- **DEP-001**: None.

## Files (FILE-\*)

- **FILE-001**: scripts/test-fixtures/valid-plan.md (this file)

## Tests (TEST-\*)

- **TEST-001**: Run validators against this file - PASS
- **TEST-002**: Verify traceability map validation works

## Risks (RISK-\*)

- **RISK-001**: None (test fixture).

### FM Exposure

Declared against: no registry (meta-repo test fixture)

| ID | Why plausibly touched |
| --- | --- |
| FM-CANDIDATE-001 | test fixture -- exercises declared-ID validation path (Plan 022) |

## Assumptions (ASSUMPTION-\*)

- **ASSUMPTION-001**: Both validators are available.

## Open Questions (OPENQ-\*)

- **OPENQ-001 [RESOLVED]**: Is this fixture complete? - Yes.

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement | Tasks | Tests | Risk | Failure Mode |
| --- | --- | --- | --- | --- |
| REQ-001 (valid) | TASK-001, TASK-002 | TEST-001, TEST-002 | RISK-001 | FM-CANDIDATE-001 |
| REQ-002 (sections) | TASK-002 | TEST-001 | -- | -- |
