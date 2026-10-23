---
ID: 908
Origin: 908
UUID: fx-openq-h
Status: Active
---

# Plan: Test Fixture - Valid Control (Post-038 Rule Set)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fully valid plan exercising both table-form and list-form resolved entries plus an intentionally-open entry, so that a clean plan is never falsely hard-gated by the new rule set.

## Objective

Provide a clean, defect-free control fixture for the Plan 038 rule set.

## Requirements & Constraints

- REQ-001: This fixture must pass both validators cleanly, before and after the rewrite.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the control scenario.

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

- FILE-001: scripts/test-fixtures/openq-h-valid-control.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: All three entries below are self-contained on their own line.

## Open Questions (OPENQ-\*)

| ID | Question | Status |
| --- | --- | --- |
| OPENQ-110-1 | Is the table-form entry resolved | [RESOLVED -- yes] |
| OPENQ-110-2 | Is this entry intentionally left open | [OPEN -- non-blocking, tracked separately] |

- OPENQ-111-1 [CLOSED -- superseded]: Is the list-form entry closed?

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
