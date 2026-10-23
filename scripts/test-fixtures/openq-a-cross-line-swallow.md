---
ID: 901
Origin: 901
UUID: fx-openq-a
Status: Active
---

# Plan: Test Fixture - Cross-Line Swallow (OPENQ-101 / OPENQ-102)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture that isolates the cross-line OPENQ swallow defect, so that the fix can be demonstrated red then green.

## Objective

Exercise the per-line, non-cross-line OPENQ resolution rule in isolation from every other OPENQ defect.

## Requirements & Constraints

- REQ-001: This fixture must isolate the cross-line swallow defect only.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the swallow scenario.

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

- FILE-001: scripts/test-fixtures/openq-a-cross-line-swallow.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: The unrelated background noted in OPENQ-101 carries no resolution marker of its own nearby.

## Open Questions (OPENQ-\*)

| ID | Question | Status |
| --- | --- | --- |
| OPENQ-102 | Is the follow-up review fully resolved | [RESOLVED -- yes, confirmed] |

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
