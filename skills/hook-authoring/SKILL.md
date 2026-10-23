---
name: hook-authoring
description: Design requirements, best practices, anti-patterns, and worked examples for authoring AI agent lifecycle hooks. Covers hooks.json schema, supported events, matcher syntax, cross-platform scripting, and VS Code/Claude Code differences. Load when creating, reviewing, or troubleshooting lifecycle hooks.
---

# Hook Authoring Skill

This skill provides authoritative guidance for authoring AI agent lifecycle hooks, synthesized from official documentation by Microsoft VS Code and Anthropic Claude Code. All recommendations are cited to source.

**IMPORTANT**: OpenAI Agents SDK has **no documented lifecycle hooks system**. If you target OpenAI, use guardrails and approvals instead (see OpenAI docs on [guardrails](https://developers.openai.com/api/docs/guides/agents/guardrails-approvals)).

---

## Universal Rules (Convergence Points)

These rules apply to both VS Code and Anthropic Claude Code.

### 1. JSON Configuration

Hooks are configured in JSON, not Markdown. Format:
```json
{
  "hooks": {
    "<EventName>": [
      { "type": "command", "command": "..." }
    ]
  }
}
```

### 2. Event Names are PascalCase

Event names use **PascalCase**: `PreToolUse`, not `preToolUse` or `pre_tool_use`.

### 3. Shared Core Events (Portable Subset)

These events are supported by both VS Code and Anthropic:
- `SessionStart` -- Session begins
- `UserPromptSubmit` -- User sends a message
- `PreToolUse` -- Before a tool executes
- `PostToolUse` -- After a tool executes
- `Stop` -- Session/agent stops
- `SubagentStart` -- Subagent invoked
- `SubagentStop` -- Subagent completes
- `PreCompact` -- Before context compaction

### 4. Command Handlers (Portable)

The `command` handler type is supported by both vendors:
- **stdin**: JSON event data
- **stdout**: JSON response (parsed only on exit code 0)
- **exit 0**: Success, stdout parsed
- **exit 2**: Blocking error, stderr shown to model
- **exit 1**: Non-blocking warning (default)

### 5. Hooks Run with Full User Permissions

⚠️ **SECURITY WARNING**: Hook scripts run with the same permissions as the user. Review all hook scripts before enabling, especially in shared repositories.

---

## VS Code-Specific Guidance

**Source**: [VS Code Hooks](https://code.visualstudio.com/docs/copilot/customization/hooks)

### Supported Events (8 total)

| Event | When | Can Block? |
|-------|------|------------|
| `SessionStart` | Session begins | Yes |
| `UserPromptSubmit` | User sends message | Yes |
| `PreToolUse` | Before tool executes | Yes |
| `PostToolUse` | After tool executes | No |
| `PreCompact` | Before context compaction | Yes |
| `SubagentStart` | Subagent invoked | Yes |
| `SubagentStop` | Subagent completes | No |
| `Stop` | Session/agent stops | Yes |

### Handler Schema

```json
{
  "type": "command",
  "command": "script.sh",
  "windows": "script.ps1",
  "linux": "script.sh",
  "osx": "script.sh",
  "cwd": ".",
  "env": { "VAR": "value" },
  "timeout": 30
}
```

### File Locations

| Location | Scope |
|----------|-------|
| `.github/hooks/*.json` | Workspace |
| `.claude/settings.json` | Workspace (Claude format) |
| `~/.copilot/hooks` | User |
| Plugin `hooks.json` (Copilot format) | Plugin |
| Plugin `hooks/hooks.json` (Claude format) | Plugin |
| Agent frontmatter `hooks:` | Agent-scoped (Preview) |

### Critical Differences from Claude Code

| Aspect | VS Code | Claude Code |
|--------|---------|-------------|
| Matcher support | **Parsed but IGNORED** | Full regex/exact/OR |
| Tool-input casing | `camelCase` (`filePath`) | `snake_case` (`file_path`) |
| Tool names | `create_file`, `replace_string_in_file` | `Write`, `Edit` |
| Plugin root token | None for Copilot format; `${CLAUDE_PLUGIN_ROOT}` for Claude format only | `${CLAUDE_PLUGIN_ROOT}` |

### VS Code Anti-Patterns

❌ **Do NOT** rely on matcher values -- VS Code parses them but **currently ignores** them; hooks fire on every event

❌ **Do NOT** read `tool_input.file_path` (snake_case) -- VS Code uses `tool_input.filePath` (camelCase)

❌ **Do NOT** assume Claude tool names (`Write`, `Edit`) -- VS Code uses different names (`create_file`, `replace_string_in_file`)

❌ **Do NOT** use `${CLAUDE_PLUGIN_ROOT}` in Copilot-format plugins -- token only set for Claude-format plugins

---

## Anthropic Claude Code-Specific Guidance

**Source**: [Claude Code Hooks](https://code.claude.com/docs/en/hooks)

### Supported Events (30+)

Claude Code supports many more events than VS Code:

**Core events** (shared with VS Code):
`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `SubagentStart`, `SubagentStop`, `Stop`

**Additional events** (Claude Code only):
`Setup`, `InstructionsLoaded`, `UserPromptExpansion`, `PermissionRequest`, `PostToolUseFailure`, `PostToolBatch`, `PermissionDenied`, `Notification`, `TaskCreated`, `TaskCompleted`, `StopFailure`, `TeammateIdle`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PostCompact`, `SessionEnd`, `Elicitation`, `ElicitationResult`

### Five Handler Types

| Type | Description |
|------|-------------|
| `command` | Shell script (portable) |
| `http` | POST to URL |
| `mcp_tool` | Call connected MCP tool |
| `prompt` | LLM evaluator |
| `agent` | Subagent verifier (experimental) |

### Matcher Syntax

| Pattern | Meaning |
|---------|---------|
| `*` or empty | Match all |
| `[A-Za-z0-9_\|]` only | Exact string or pipe-OR |
| Any other char | JavaScript regex |

### Per-Handler Filtering (`if` field)

Tool events support permission-rule syntax filtering:
```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "if": "Bash(rm *)", "command": "./block-rm.sh" }
  ]
}
```

### Async Hooks

For long-running tasks, use `async: true`:
```json
{
  "type": "command",
  "command": "./deploy.sh",
  "async": true
}
```
Async hooks cannot block; output delivered next turn.

### Path Tokens

| Token | Value |
|-------|-------|
| `${CLAUDE_PROJECT_DIR}` | Project root |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin installation directory |
| `${CLAUDE_PLUGIN_DATA}` | Plugin data directory |

### Claude Code Anti-Patterns

❌ **Do NOT** return JSON when exiting with code 2 -- Claude ignores stdout on exit 2; only stderr is shown

❌ **Do NOT** use exit code 1 to enforce policy -- exit 1 is non-blocking; only exit 2 blocks (except `WorktreeCreate`)

❌ **Do NOT** let shell profile print text on startup -- interferes with JSON parsing on stdout

❌ **Do NOT** configure `bypassPermissions` for subagents without launching parent in bypass mode -- silently no-op

---

## Anti-Patterns Checklist (All Vendors)

❌ **Do NOT** forget `stop_hook_active` check in Stop/SubagentStop hooks -- causes infinite continuation loop and burns premium requests (Microsoft, Anthropic)

❌ **Do NOT** disable auto-edit for hook scripts without good reason -- `chat.tools.edits.autoApprove` should be reviewed (Microsoft)

❌ **Do NOT** hardcode secrets -- use env vars or secure credential storage (Microsoft)

❌ **Do NOT** trust input data blindly -- validate and sanitize all inputs (Anthropic)

❌ **Do NOT** use unquoted shell variables -- always quote: `"$VAR"` (Anthropic)

❌ **Do NOT** skip path traversal checks -- check for `..` in paths (Anthropic)

❌ **Do NOT** skip sensitive file checks -- avoid `.env`, `.git/`, keys (Anthropic)

❌ **Do NOT** phrase `additionalContext` as imperative system instructions -- use factual statements to avoid prompt-injection defenses (Anthropic)

---

## Worked Examples

### Example 1: Auto-Format on File Edit (VS Code)

Automatically run Prettier on files after they're edited.

**File**: `.github/hooks/hooks.json`

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": ".github/hooks/format-on-edit.sh",
        "timeout": 10
      }
    ]
  }
}
```

**Script**: `.github/hooks/format-on-edit.sh`
```bash
#!/bin/bash
# Read event JSON from stdin (VS Code hook contract)
EVENT=$(cat)

# Extract filePath from tool_input (camelCase per VS Code schema)
FILE_PATH=$(echo "$EVENT" | jq -r '.tool_input.filePath // empty')

# Only run prettier if a filePath was provided
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
    npx prettier --write "$FILE_PATH" 2>/dev/null || true
fi

exit 0
```

**Why this works**:
- `PostToolUse` fires after file edits
- Reads JSON from stdin and parses `tool_input.filePath` (matches VS Code's camelCase schema)
- Gracefully handles missing filePath or non-existent files
- Short timeout prevents hanging

**Caveat**: This fires on ALL PostToolUse events (VS Code ignores matchers). The script guards against this by checking for filePath presence.

---

### Example 2: Block Dangerous Commands (Anthropic)

Prevent `rm -rf` from executing by returning a deny decision.

**Config in `.claude/settings.json`**:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh"
          }
        ]
      }
    ]
  }
}
```

**Script**: `.claude/hooks/block-rm.sh`
```bash
#!/bin/bash
set -euo pipefail

# Read event JSON from stdin
EVENT=$(cat)

# Extract the command
COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // ""')

# Block rm -rf
if [[ "$COMMAND" =~ rm[[:space:]]+-rf ]]; then
  echo '{"hookSpecificOutput":{"permissionDecision":"deny"},"reason":"rm -rf is blocked by policy"}' >&2
  exit 2
fi

# Allow other rm commands
echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
exit 0
```

**Why this works**:
- Uses Anthropic's matcher + `if` filter for targeted execution
- Returns structured `permissionDecision` for `PreToolUse`
- Exit 2 for blocking deny
- Uses `${CLAUDE_PROJECT_DIR}` for portable path

---

### Example 3: Context-Injecting Hook (Cross-Platform)

Inject environment context at the start of each session.

**File**: `hooks/hooks.json` (plugin format)
```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/inject-context.sh",
        "windows": "powershell -File ${CLAUDE_PLUGIN_ROOT}/hooks/inject-context.ps1",
        "timeout": 5
      }
    ]
  }
}
```

**Script**: `hooks/inject-context.sh`
```bash
#!/bin/bash
set -euo pipefail

# Gather environment info
NODE_VERSION=$(node --version 2>/dev/null || echo "not installed")
PYTHON_VERSION=$(python3 --version 2>/dev/null || echo "not installed")
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "not in git repo")

# Return as additionalContext (factual statements, not instructions)
cat <<EOF
{
  "additionalContext": "Environment: Node ${NODE_VERSION}, Python ${PYTHON_VERSION}. Current git branch: ${GIT_BRANCH}."
}
EOF
```

**Script**: `hooks/inject-context.ps1`
```powershell
$nodeVersion = try { node --version } catch { "not installed" }
$pythonVersion = try { python --version } catch { "not installed" }
$gitBranch = try { git branch --show-current } catch { "not in git repo" }

@{
    additionalContext = "Environment: Node $nodeVersion, Python $pythonVersion. Current git branch: $gitBranch."
} | ConvertTo-Json
```

**Why this works**:
- Cross-platform with `windows:` override
- `additionalContext` phrased as factual statement, not instruction
- Uses plugin root token for portable paths
- Short timeout for startup hook

---

### Example 4: Stop Hook with Loop Prevention (VS Code)

A stop hook that logs session end but prevents infinite loops.

**File**: `.github/hooks/session-log.json`
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "./log-session.sh",
        "timeout": 5
      }
    ]
  }
}
```

**Script**: `log-session.sh`
```bash
#!/bin/bash
set -euo pipefail

# Read event JSON
EVENT=$(cat)

# CRITICAL: Check if we're already in a stop hook to prevent infinite loop
STOP_HOOK_ACTIVE=$(echo "$EVENT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  # Already in stop hook, exit cleanly
  exit 0
fi

# Log session end
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(echo "$EVENT" | jq -r '.session_id // "unknown"')
echo "${TIMESTAMP} - Session ${SESSION_ID} ended" >> ~/.copilot-session.log

# Return success, do not continue
echo '{"continue": false}'
exit 0
```

**Why this works**:
- **Checks `stop_hook_active`** to prevent infinite loops (critical for Stop hooks)
- Returns `{"continue": false}` to end cleanly
- Short timeout
- Logs to user's home directory (avoids workspace pollution)

---

## OpenAI Gap Documentation

**OpenAI Agents SDK has no documented lifecycle hooks system.** This is an explicit gap, not an oversight.

If you target OpenAI, alternative approaches:
- **Guardrails**: Input/output validation (see [OpenAI guardrails docs](https://developers.openai.com/api/docs/guides/agents/guardrails-approvals))
- **Approval gates**: Human review for sensitive operations
- **Tool wrappers**: Add validation logic inside tool implementations

---

## Cross-References

- For agent authoring guidance, see `skills/agent-authoring/SKILL.md`
- For skill authoring guidance, see `skills/skill-authoring/SKILL.md`
- VS Code hooks FAQ: https://code.visualstudio.com/docs/copilot/customization/hooks#_faq
- Claude Code hooks reference: https://code.claude.com/docs/en/hooks

---

## Source Bibliography

All sources accessed 2026-05-01.

- Microsoft: https://code.visualstudio.com/docs/copilot/customization/hooks
- Anthropic: https://code.claude.com/docs/en/hooks
- OpenAI (no hooks, guardrails instead): https://developers.openai.com/api/docs/guides/agents/guardrails-approvals
