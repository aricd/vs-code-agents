---
description: Fixture agent for smoke-test check (d) — duplicate ordinal in ordered list.
name: test-duplicate-ordinal
target: vscode
---
Purpose:

This is a test fixture for smoke-test check (d) (duplicate ordinal in ordered list).

The list below intentionally repeats ordinal 3 within the same contiguous list.

Core Responsibilities:

1. First item — begins list, resets state.
2. Second item.
3. Third item (first occurrence).
4. Fourth item.
3. Third item again — this is the duplicate ordinal that should fire check (d).
5. Fifth item.

Expected smoke-test output when injected into agents/:
  FAIL: agents/test-duplicate-ordinal.agent.md:N: duplicate ordinal 3. in ordered list

Inject: copy this file to agents/test-duplicate-ordinal.agent.md and run make verify.
