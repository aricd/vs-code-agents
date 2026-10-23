---
ID: 902
Origin: 902
UUID: fx-openq-b
Status: Active
---

# Plan: Test Fixture - Genuinely Unresolved (OPENQ-103)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture with one genuinely unresolved OPENQ entry and an unrelated stray resolution word elsewhere, so that the hard gate is proven to still fire on the entry's own line, not on any later text.

## Objective

Exercise CON-004: an unrelated resolution word elsewhere in the document MUST NOT resolve an id whose own entry lacks the marker.

## Requirements & Constraints

- REQ-001: This fixture must isolate the genuinely-unresolved case from every other OPENQ defect.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the genuinely-unresolved scenario.

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

- FILE-001: scripts/test-fixtures/openq-b-genuinely-unresolved.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: Nothing else in this document declares an OPENQ id.

## Open Questions (OPENQ-\*)

| ID | Question | Status |
| --- | --- | --- |
| OPENQ-103 | Is the follow-up review complete | pending, no decision recorded yet |

## Approval & Sign-off

- User: an unrelated, earlier concern was already noted as RESOLVED text here [RESOLVED] during a prior planning cycle; this fixture's own OPENQ-103 remains open for a separate reason.

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
