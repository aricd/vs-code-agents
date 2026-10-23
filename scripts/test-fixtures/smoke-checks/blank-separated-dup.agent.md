---
description: Regression fixture for smoke-test check (d) blank-line-reset blind spot — a duplicate ordinal separated by a blank line MUST be caught.
name: test-blank-separated-dup
target: vscode
---
Purpose:

Regression fixture for smoke-test check (d).

This file contains an ordered list where ordinal 3 appears twice, separated by a blank line.
The oracle MUST flag the duplicate (ordinal 3.) even though a blank line precedes it.
A blank line is NOT a list boundary — only an explicit restart at 1. resets the context.

## Workflow

1. First step.

2. Second step.

3. Third step.

3. This is a duplicate of ordinal 3. — check (d) MUST flag this as a duplicate ordinal.

Expected smoke-test behavior when injected into agents/:
  Check (d) FAIL — duplicate ordinal 3. detected (blank line does not reset list context).
  (The agent count check will also fail as expected.)

Inject: copy this file to agents/test-blank-separated-dup.agent.md and run make verify.
Confirm: FAIL output includes duplicate ordinal 3. AND the file:line reference for this file.
