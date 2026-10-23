---
ID: 903
Origin: 903
UUID: fx-openq-c
Status: Active
---

# Plan: Test Fixture - Composite ID Collapse (OPENQ-105-1 / OPENQ-105-2)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want two composite OPENQ ids sharing an origin, one resolved and one genuinely still open, so that the id-collapse defect can be demonstrated red then green.

## Objective

Exercise composite-id extraction: OPENQ-105-1 and OPENQ-105-2 must be tracked as two distinct entries, never collapsed to the shared origin OPENQ-105.

## Requirements & Constraints

- REQ-001: This fixture must isolate the composite-id-collapse defect only.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the composite-id-collapse scenario.

| Task     | Description        | Status   | Owner       | Date       |
| -------- | ------------------ | -------- | ----------- | ---------- |
| TASK-001 | Author the fixture | complete | implementer | 2026-09-19 |

## Alternatives (ALT-\*)

- ALT-001: None considered (test fixture).

## Deferred Items (DEFER-\*)

None identified.

## Dependencies (DEP-\*)

- DEP-001: None.

## Files (FILE-\*)

- FILE-001: scripts/test-fixtures/openq-c-composite-id-collapse.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: Both entries share the same origin id, 105.

## Open Questions (OPENQ-\*)

| ID | Question | Status |
| --- | --- | --- |
| OPENQ-105-1 | First composite entry sharing origin 105 | [RESOLVED -- yes] |
| OPENQ-105-2 | Second composite entry sharing origin 105, still open | pending, no decision recorded |

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
