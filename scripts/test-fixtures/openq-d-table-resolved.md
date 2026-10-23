---
ID: 904
Origin: 904
UUID: fx-openq-d
Status: Active
---

# Plan: Test Fixture - Table-Form Resolved Entry (OPENQ-106-1)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a table-form resolved composite OPENQ entry, so that the unified detection rule is proven to handle the table form without format branching.

## Objective

Exercise the unified CONTRACT-001 rule against a table-form entry.

## Requirements & Constraints

- REQ-001: This fixture must exercise table-form resolution only.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the table-form control scenario.

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

- FILE-001: scripts/test-fixtures/openq-d-table-resolved.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: This is the only OPENQ entry in the document.

## Open Questions (OPENQ-\*)

| ID          | Question                | Status                           |
| ----------- | ----------------------- | -------------------------------- |
| OPENQ-106-1 | Is the schema finalized | [RESOLVED -- yes, schema locked] |

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
