---
ID: 997
Origin: 997
UUID: test-missing-deferred-items
Status: Active
Review_State: approved
---

# Plan: Test Fixture - Missing Deferred Items

Epic Alignment: Testing / Validator parity Target Release: N/A (test fixture)

## Changelog

| Date | Agent | Change | Notes |
| --- | --- | --- | --- |
| 2026-09-01 | Implementer | Created | Fixture proving a plan lacking '## Deferred Items' -> ERROR (TEST-001, Plan 030) |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture that omits Deferred Items but is otherwise valid, so that I can verify the required-sections check flags exactly this one omission.

## Objective

Provide a plan that is valid in every respect except the missing Deferred Items section.

## Requirements & Constraints

- **REQ-001**: This fixture must fail validation with exactly the missing-Deferred-Items error
- **CON-001**: Must follow structured-labeling template otherwise

## Backwards Compatibility (BACKCOMPAT-\*)

**BACKCOMPAT-001**: Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- **TEST-SCOPE-001**: Unit: Validate the required-sections check

## Implementation Plan

### Phase 1 - Test Setup

GOAL-001: Create fixture

| Task     | Description         | Status   | Owner   | Date       |
| -------- | ------------------- | -------- | ------- | ---------- |
| TASK-001 | Create fixture file | complete | planner | 2026-09-01 |

## Dependencies (DEP-\*)

- **DEP-001**: None.

## Files (FILE-\*)

- **FILE-001**: scripts/test-fixtures/missing-deferred-items.md (this file)

## Tests (TEST-\*)

- **TEST-001**: Run validators against this file - expect ERROR for missing Deferred Items

## Risks (RISK-\*)

- **RISK-001**: None (test fixture).

## Assumptions (ASSUMPTION-\*)

- **ASSUMPTION-001**: Both validators are available.

## Open Questions (OPENQ-\*)

- **OPENQ-001 [RESOLVED]**: Is this fixture complete? - Yes.

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement     | Tasks    | Tests    | Risk     | Failure Mode |
| --------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (valid) | TASK-001 | TEST-001 | RISK-001 | --           |
