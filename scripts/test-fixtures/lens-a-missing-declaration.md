---
ID: 921
Origin: 921
UUID: fx-lens-a
Status: Active
---

# Plan: Test Fixture - Lens-Applicability Missing Declaration

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-10-14 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture whose `ALT-*` entry carries no `Lens[...]` declaration, so that the hard-gate check's missing-declaration finding is exercised.

## Objective

Provide a negative fixture for the Lens-Applicability presence check (REQ-001).

## Requirements & Constraints

- REQ-001: This fixture's `ALT-001` entry has no `Lens[...]` first line and must be flagged.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the missing-declaration scenario.

| Task     | Description        | Status   | Owner       | Date       |
| -------- | ------------------- | -------- | ----------- | ---------- |
| TASK-001 | Author the fixture | complete | implementer | 2026-10-14 |

## Alternatives (ALT-\*)

- ALT-001: None considered (test fixture) -- intentionally has no `Lens[...]` declaration.

## Deferred Items (DEFER-\*)

None identified.

## Dependencies (DEP-\*)

- DEP-001: None.

## Files (FILE-\*)

- FILE-001: scripts/test-fixtures/lens-a-missing-declaration.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file; `ALT-001` must be flagged.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: The OPENQ entries below carry a valid declaration so only the `ALT-001` finding is exercised.

## Open Questions (OPENQ-\*)

- OPENQ-921-1 [OPEN -- non-blocking, tracked separately]: Lens[DM+ FC-(not a within-unit decomposition) LD+] Is this entry resolved?

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ------------------ | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
