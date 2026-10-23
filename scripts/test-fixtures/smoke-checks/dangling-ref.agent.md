---
description: Fixture agent for smoke-test check (c) — dangling skill reference.
name: test-dangling-ref
target: vscode
---
Purpose:

This is a test fixture for smoke-test check (c) (dangling skill reference).

It references a skill that does not exist in this repo.

Dangling Reference: Load `nonexistent-skill-xyzzy` when doing things.

Expected smoke-test output when injected into agents/:
  FAIL: agents/test-dangling-ref.agent.md:N: dangling skill ref `nonexistent-skill-xyzzy` (no skills/nonexistent-skill-xyzzy/ dir)

Inject: copy this file to agents/test-dangling-ref.agent.md and run make verify.
