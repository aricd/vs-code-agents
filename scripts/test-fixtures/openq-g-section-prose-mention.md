---
ID: 907
Origin: 907
UUID: fx-openq-g
Status: Active
---

# Plan: Test Fixture - Required Section Present Only As Prose Mention

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a plan that never carries a real Deferred Items heading but does mention the DEFER- label prefix in prose, so that the anchored-presence fix is proven to still report the section missing.

## Objective

Exercise REQ-007/CONTRACT-002: a section is present iff a line matches its heading pattern, never on a bare label-prefix or prose mention elsewhere.

## Requirements & Constraints

- REQ-001: This fixture must isolate the anchored-presence defect only; it must not itself introduce a real Deferred Items heading anywhere.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the prose-mention scenario. We will not create a DEFER- entry section for this fixture on purpose -- see Objective.

| Task     | Description        | Status   | Owner       | Date       |
| -------- | ------------------ | -------- | ----------- | ---------- |
| TASK-001 | Author the fixture | complete | implementer | 2026-09-19 |

## Alternatives (ALT-\*)

- ALT-001: None considered (test fixture).

## Dependencies (DEP-\*)

- DEP-001: None.

## Files (FILE-\*)

- FILE-001: scripts/test-fixtures/openq-g-section-prose-mention.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: No line anywhere in this document matches a Deferred Items heading pattern.

## Open Questions (OPENQ-\*)

- OPENQ-109-1 [RESOLVED -- yes]: Is the rest of this fixture otherwise valid?

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ----------------- | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
