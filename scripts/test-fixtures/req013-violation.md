---
ID: 909
Origin: 909
UUID: fx-req013-violation
Status: Active
---

# Plan: Test Fixture - REQ-013 Violation (FM IDs Declared, No Registry File Cited)

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-09-19 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fixture that declares FM Exposure ids without citing guarantees/LEDGER.md or failure-modes/INDEX.md in its Files section, so that the REQ-013 WARNING rule is proven to fire.

## Objective

Exercise REQ-013: a plan declaring FM ids in FM Exposure without a registry file cited in Files MUST warn.

## Requirements & Constraints

- REQ-001: This fixture must isolate the FM-registry citation violation only.

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the REQ-013 violation scenario.

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

- FILE-001: scripts/test-fixtures/req013-violation.md (this file; deliberately no registry file cited here)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

Declared against: guarantees/LEDGER.md and failure-modes/INDEX.md (not cited in Files above, on purpose)

| ID               | Why plausibly touched                              |
| ---------------- | -------------------------------------------------- |
| FM-CANDIDATE-900 | test fixture -- exercises the REQ-013 warning path |

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: Neither guarantees/LEDGER.md nor failure-modes/INDEX.md appears anywhere in the Files section above.

## Open Questions (OPENQ-\*)

- OPENQ-112-1 [RESOLVED -- yes]: Is the rest of this fixture otherwise valid?

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode     |
| ----------------- | -------- | -------- | -------- | ---------------- |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | FM-CANDIDATE-900 |
