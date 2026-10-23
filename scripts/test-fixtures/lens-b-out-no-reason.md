---
ID: 922
Origin: 922
UUID: fx-lens-b
Status: Active
---

# Plan: Test Fixture - Lens-Applicability Out Token Missing Reason

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-10-14 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture whose `Lens[...]` declaration carries an out (`-`) token with no parenthesized reason, so that the hard-gate check's missing-reason finding is exercised.

## Objective

Provide a negative fixture for the Lens-Applicability out-token-reason check (REQ-002).

## Requirements & Constraints

- REQ-001: This fixture's `OPENQ-922-1` entry reads bare `Lens[DM+ FC- LD+]` -- no reason on `FC-` -- and must be flagged.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the out-token-no-reason scenario.

| Task     | Description        | Status   | Owner       | Date       |
| -------- | ------------------- | -------- | ----------- | ---------- |
| TASK-001 | Author the fixture | complete | implementer | 2026-10-14 |

## Alternatives (ALT-\*)

- ALT-001: Lens[DM+ FC-(not a within-unit decomposition) LD+] None considered (test fixture).

## Deferred Items (DEFER-\*)

None identified.

## Dependencies (DEP-\*)

- DEP-001: None.

## Files (FILE-\*)

- FILE-001: scripts/test-fixtures/lens-b-out-no-reason.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file; `OPENQ-922-1` must be flagged for a missing `FC-` reason.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: `ALT-001` above carries a valid declaration so only the `OPENQ-922-1` finding is exercised.

## Open Questions (OPENQ-\*)

- OPENQ-922-1 [OPEN -- non-blocking, tracked separately]: Lens[DM+ FC- LD+] Bare out token with no reason.

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ------------------ | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
