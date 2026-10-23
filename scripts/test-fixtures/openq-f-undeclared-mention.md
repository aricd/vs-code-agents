---
ID: 906
Origin: 906
UUID: fx-openq-f
Status: Active
---

# Plan: Test Fixture - Undeclared OPENQ Mention (OPENQ-108)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a prose mention of an OPENQ id that is never declared as an entry in the Open Questions section, so that the entry-scoping fix is proven to downgrade it to a warning instead of hard-gating the plan.

## Objective

Exercise REQ-005: an id referenced anywhere else but never declared in the Open Questions section raises a WARNING, never an error.

## Requirements & Constraints

- REQ-001: This fixture must isolate the undeclared-mention case only. See OPENQ-108 for background (this is the only mention of that id anywhere in this document; it is never declared as an entry below).

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the undeclared-mention scenario.

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

- FILE-001: scripts/test-fixtures/openq-f-undeclared-mention.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: OPENQ-108 never appears as a declared row or list item in the Open Questions section below.

## Open Questions (OPENQ-\*)

None identified in this fixture; the point under test is the inbound citation in the Requirements section above.

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
