---
name: test-execution-privilege
description: Verify the agent runtime can execute shell commands and read/write files in `.agent-output/` before workflows that depend on it. Load when starting a new plan, when a plan is approved (before orchestration handoff), or before an Implementer's first terminal operation. Performs a create-read-verify-delete cycle on a uniquely-named temp file. HARD BLOCK on failure.
---

# Test Execution Privilege

This skill verifies that the agent runtime can do the two things planner/implementer workflows depend on:

1. **Execute a shell command** via the terminal tool.
2. **Read and write files** under `.agent-output/`.

It is a smoke test, not a diagnostics suite. Pass = continue. Fail = `HARD BLOCK`.

---

## When to Invoke

| Trigger | Agent | Why |
|---|---|---|
| Starting a new plan | Planner | About to create plan doc + bump `.next-id` |
| Plan approved (pre-orchestration handoff) | Planner | About to invoke validator + delegate to subagents |
| Before first terminal command in a session | Implementer | About to run builds, tests, commits |

Running it more than once per session is cheap. Skip only if a fresh marker is present (see below).

---

## Two-Path Protocol

### Path A -- Hook (primary, automatic)

A `SessionStart` hook runs `scripts/test-execution-privilege.{ps1,sh}` automatically when the session begins. On success it:

- Refreshes `.agent-output/.exec-probe-ok` with timestamp + platform metadata.
- Emits a visible `contextInjection` line: `[Exec Probe] OK <iso-timestamp> <platform>`.

If you see that line at session start, the probe already passed -- no action needed.

### Path B -- Inline (backup, manual)

Use Path B when **any** of the following is true:

- No `[Exec Probe]` line appeared at session start (hook didn't fire / hooks disabled).
- The marker file `.agent-output/.exec-probe-ok` is missing.
- The marker `timestamp:` field is older than 1 hour.
- You are about to perform a workflow step listed in "When to Invoke" above and want explicit confirmation.

Run the platform-appropriate command from the workspace root:

| Platform | Command |
|---|---|
| Windows | `pwsh -File scripts/test-execution-privilege.ps1` |
| Linux   | `bash scripts/test-execution-privilege.sh` |
| macOS   | `bash scripts/test-execution-privilege.sh` |

The script always exits `0`. **Read its stdout JSON** to determine pass/fail:

- `{"contextInjection":"[Exec Probe] OK ..."}` -> pass, continue.
- `{"contextInjection":"[Exec Probe] FAIL ..."}` -> fail, see escalation below.

---

## What the Probe Does

1. Ensures `.agent-output/` exists.
2. Generates a unique tempfile name: `.exec-probe-<pid>-<8-hex>.tmp`.
3. Writes a sentinel string.
4. Reads it back and verifies byte-for-byte.
5. Deletes the tempfile.
6. Refreshes `.agent-output/.exec-probe-ok` with `timestamp`, `platform`, `pid`, `probe_file`, `result: ok`.

Unique filenames prevent collisions when multiple sessions/agents probe concurrently.

---

## Escalation on Failure (HARD BLOCK)

If the probe fails, do NOT proceed with any workflow step that depends on terminal execution or `.agent-output/` writes. Emit a HARD BLOCK to the user using this format:

```
HARD BLOCK: Execution privilege probe failed

Probe output: <verbatim FAIL message from the script>
Platform: <windows | linux | macos>
Required for: <new plan creation | plan approval handoff | implementer terminal ops>

Likely causes:
- VS Code terminal tool disabled or sandboxed
- Workspace not opened to expected folder (cwd mismatch)
- `.agent-output/` permissions blocked
- PowerShell execution policy / bash unavailable on this OS

Recommended remediation:
- Confirm a terminal can be opened manually in VS Code at the workspace root
- Verify write permission on `.agent-output/`
- Re-run the probe manually with the platform command above

Cannot proceed until resolved.
```

Do not attempt to silently fall back to file-only operations -- the dependent workflows will fail later in less obvious ways.

---

## Anti-Patterns

- ❌ Probing a real artifact (e.g., reading `.next-id`) -- proves read access only, not write.
- ❌ Hard-coding absolute paths -- breaks cross-platform. Use workspace-relative paths only.
- ❌ Treating a non-zero exit code as failure -- the script always exits `0`; parse the JSON payload instead.
- ❌ Suppressing the FAIL message and continuing -- every dependent step will fail mysteriously.
- ❌ Running the probe inside a loop or on every prompt -- once per session (via hook) plus on-demand (via skill) is sufficient.
