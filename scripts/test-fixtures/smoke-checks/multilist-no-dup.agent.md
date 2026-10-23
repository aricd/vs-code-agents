---
description: Fixture agent for smoke-test check (d) negative guard — multiple ordered lists each restarting at 1. must NOT fire check (d).
name: test-multilist-no-dup
target: vscode
---
Purpose:

Negative guard fixture for smoke-test check (d).

This file contains MULTIPLE ordered lists, each restarting at 1.
Check (d) MUST NOT fire on this file — per-list scoping is required.

## Phase 1 responsibilities

1. Read the plan.
2. Validate value statement.
3. Check constraints.
4. Begin implementation.

## Phase 2 responsibilities

1. Write failing tests first (TDD Red).
2. Write minimal code to make tests pass (TDD Green).
3. Refactor while keeping tests green.
4. Document findings.
5. Verify acceptance criteria.

## Phase 3 responsibilities

1. Run full smoke test.
2. Update execution-state.
3. Prepare implementation doc.

## Workflow

1. Start with Phase 1 responsibilities.
2. Proceed to Phase 2 after Phase 1 complete.
3. Proceed to Phase 3 after Phase 2 complete.
4. Handoff to QA.

Expected smoke-test behavior when injected into agents/:
  Check (d) PASS — no duplicate ordinals within any single list.
  (The agent count check will fail as expected with 13 agents.)

Inject: copy this file to agents/test-multilist-no-dup.agent.md and run make verify.
Confirm: FAIL output mentions agent count (13 != 12) but NOT duplicate ordinal.
