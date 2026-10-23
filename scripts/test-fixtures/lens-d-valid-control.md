---
ID: 924
Origin: 924
UUID: fx-lens-d
Status: Active
---

# Plan: Test Fixture - Lens-Applicability Valid Control

## Changelog

| Date       | Change  | Author      |
| ---------- | ------- | ----------- |
| 2026-10-14 | Created | Implementer |

## Value Statement and Business Objective

As a validator maintainer, I want a fully-formed `Lens[...]` declaration on every `ALT-*`/`OPENQ-*` entry, so that a clean plan is never falsely flagged by the new rule.

## Objective

Provide a clean, defect-free control fixture for the Lens-Applicability rule set.

## Requirements & Constraints

- REQ-001: This fixture must pass the Lens-Applicability check cleanly (zero findings).

## Contracts (CONTRACT-\*)

Not applicable (test fixture).

## Backwards Compatibility (BACKCOMPAT-\*)

Not applicable (test fixture).

## Testing Scope (TEST-SCOPE-\*)

- TEST-SCOPE-001: Unit -- exercised directly by the validator scripts.

## Implementation Plan

### Phase 1 - Fixture Content

GOAL-001: Provide the valid-control scenario.

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

- FILE-001: scripts/test-fixtures/lens-d-valid-control.md (this file)

## Tests (TEST-\*)

- TEST-001: Run both validators against this file; the Lens-Applicability check must stay silent.

## Risks (RISK-\*)

- RISK-001: None (test fixture).

### FM Exposure

none

## Assumptions (ASSUMPTION-\*)

- ASSUMPTION-001: All entries below carry a fully-formed `Lens[...]` declaration.

## Open Questions (OPENQ-\*)

- OPENQ-924-1 [OPEN -- non-blocking, tracked separately]: Lens[DM+ FC-(not a within-unit decomposition) LD+] Is the first entry resolved?
- OPENQ-925-1 [OPEN -- non-blocking, tracked separately]: Lens[DM+ FC-(not a within-unit decomposition) LD+] Is the second entry resolved?

## Approval & Sign-off

- User: N/A (test fixture)

## Traceability Map

| Requirement       | Tasks    | Tests    | Risk     | Failure Mode |
| ------------------ | -------- | -------- | -------- | ------------ |
| REQ-001 (fixture) | TASK-001 | TEST-001 | RISK-001 | --           |
