---
ID: 923
Origin: 923
UUID: fx-lens-c
Status: Active
---

# Plan: Test Fixture - Lens-Applicability Paraphrased Canned Reason

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-10-14 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture whose `Lens[...]` declaration carries a non-verbatim `FC-` reason, so that the hard-gate check's canned-reason-mismatch finding is exercised.

## Objective

Provide a negative fixture for the Lens-Applicability verbatim-canned-reason check (REQ-004).

## Requirements & Constraints

- REQ-001: This fixture's `OPENQ-923-1` entry reads `Lens[DM+ FC-(not within-unit) LD+]` -- a paraphrase of the fixed canned string, not the verbatim `not a within-unit decomposition` -- and must be flagged.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the paraphrased-canned-reason scenario.

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

- FILE-001: scripts/test-fixtures/lens-c-paraphrased-canned-reason.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file; `OPENQ-923-1` must be flagged for a non-verbatim `FC-` reason.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: `ALT-001` above carries a valid declaration so only the `OPENQ-923-1` finding is exercised.

## Open Questions (OPENQ-\*)

- OPENQ-923-1 [OPEN -- non-blocking, tracked separately]: Lens[DM+ FC-(not within-unit) LD+] Paraphrased canned reason.

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ------------------ | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
