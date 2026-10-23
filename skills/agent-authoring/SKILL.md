---
name: agent-authoring
description: Design requirements, best practices, anti-patterns, and worked examples for authoring custom AI agent definitions across VS Code, Claude Code, and OpenAI Agents SDK. Load when creating, reviewing, or troubleshooting custom agents.
---

# Agent Authoring Skill

This skill provides authoritative guidance for authoring custom AI agent definitions, synthesized from official documentation by Microsoft VS Code, Anthropic Claude Code, and OpenAI Agents SDK. All recommendations are cited to source.

---

## Universal Rules (Convergence Points)

These rules apply across all three vendors. Violating them causes silent failures or poor routing behavior.

1. **Single responsibility**: Each agent should excel at one specific task or domain. Add more agents only when you need separate ownership, different tools, or different approval policies. (OpenAI, Anthropic, Microsoft)

2. **Short, action-oriented description**: The `description` field is the routing signal the orchestrator uses to decide when to delegate. Front-load keywords and use cases. (Anthropic, Microsoft, OpenAI)

3. **Least-privilege tool list**: Grant only the tools necessary for the agent's task. Including unnecessary tools defeats the security purpose of custom agents. (Microsoft, Anthropic, OpenAI)

4. **Structured handoffs**: When chaining agents, use explicit handoff hints (`handoffDescription`, `handoffs:` array, or delegation prompts) so routing agents know when to delegate. (OpenAI, Microsoft)

5. **No namespace prefixes**: VS Code auto-prefixes plugin-contributed agents with `<plugin>:<agent>`. Manual prefixes like `myorg/agent` break discovery. (Microsoft)

---

## Vendor-Specific Guidance

### Microsoft / VS Code

**Source**: [VS Code Custom Agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents)

#### File Format
- Extension: `.agent.md`
- Location: `.github/agents/` (workspace), `~/.copilot/agents/` (user), or `agents/` in a plugin

#### YAML Frontmatter Schema

| Field | Required | Notes |
|-------|----------|-------|
| `name` | No (defaults to filename) | Display name in picker |
| `description` | No | Placeholder text in chat input; routing signal |
| `tools` | No | Array of tool names; `<server>/*` for all MCP tools |
| `model` | No | String or prioritized array; falls back to picker |
| `agents` | No | Subagents allowed; `*` = all, `[]` = none |
| `argument-hint` | No | Hint text after agent selection |
| `user-invocable` | No (default `true`) | `false` hides from picker |
| `disable-model-invocation` | No (default `false`) | `true` blocks as subagent |
| `handoffs` | No | Array of handoff definitions |
| `hooks` (Preview) | No | Agent-scoped hooks; requires `chat.useCustomAgentHooks=true` |

#### Deprecated Fields
- **`infer`**: Replaced by `user-invocable` + `disable-model-invocation`. Do not use.

#### Best Practices
- Use `handoffs:` for multi-step workflows that give developers control for reviewing and approving each step. (Microsoft)
- For security-sensitive workflows, create agents with read-only tools to prevent unintended modifications. Follow principle of least privilege. (Microsoft)
- Use `disable-model-invocation: true` for agents that should only be invoked manually, not as subagents.

### Anthropic / Claude Code

**Source**: [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents)

#### File Format
- Extension: `.md` (plain Markdown with YAML frontmatter)
- Location: `.claude/agents/` (project), `~/.claude/agents/` (user), or plugin `agents/`

#### YAML Frontmatter Schema

| Field | Required | Notes |
|-------|----------|-------|
| `name` | **Yes** | Agent identifier |
| `description` | **Yes** | Routing signal; Claude uses this to decide when to delegate |
| `tools` | No | Allowlist of tool names |
| `disallowedTools` | No | Denylist (alternative to allowlist) |
| `model` | No | `sonnet`/`opus`/`haiku`/full ID/`inherit` |
| `permissionMode` | No | **Ignored when loaded from plugin** |
| `maxTurns` | No | Limit agent conversation turns |
| `skills` | No | Preload skill names |
| `mcpServers` | No | **Ignored when loaded from plugin** |
| `hooks` | No | **Ignored when loaded from plugin** |
| `memory` | No | `user`/`project`/`local` |
| `background` | No | Run in background |
| `isolation` | No | `worktree` for isolated git worktree |

#### Plugin Security Restrictions
Plugin-loaded subagents **silently ignore** `hooks`, `mcpServers`, and `permissionMode` for security. Design accordingly.

#### Best Practices
- Include phrases like "use proactively" in your subagent's description field to encourage automatic delegation. (Anthropic)
- Write detailed descriptions: Claude uses the description to decide when to delegate. (Anthropic)
- Design focused subagents: each subagent should excel at one specific task. (Anthropic)

### OpenAI / Agents SDK

**Source**: [OpenAI Agents SDK](https://developers.openai.com/api/docs/guides/agents/define-agents)

#### Definition Format
OpenAI agents are constructed in **code** (TypeScript or Python), not Markdown files.

```typescript
new Agent({
  name: string,
  instructions: string,
  model: string,
  tools: Tool[],
  handoffDescription?: string,
  handoffs?: Agent[],
  outputType?: ZodSchema,
  prompt?: string  // stored prompt ID
})
```

#### Key Differences
- No file-based definition -- agents are SDK constructs
- Uses `instructions` instead of Markdown body
- `outputType` enables typed structured output for downstream code
- **No lifecycle hooks** -- use guardrails and approvals instead

#### Best Practices
- Use `outputType` (typed structured output) when downstream code needs typed data. (OpenAI)
- Keep `handoffDescription` short and concrete so routing agents know when to delegate. (OpenAI)

---

## Anti-Patterns Checklist

❌ **Do NOT** include unnecessary tools -- defeats security purpose (Microsoft)

❌ **Do NOT** use deprecated `infer` field -- replaced by `user-invocable` + `disable-model-invocation` (Microsoft)

❌ **Do NOT** put plugin-relative paths in agent body without `${CLAUDE_PLUGIN_ROOT}` token -- paths break when installed to cache (Microsoft, Anthropic)

❌ **Do NOT** use namespace prefixes in agent names (`myorg/agent`, `myorg:agent`) -- VS Code auto-prefixes; manual prefixes break discovery (Microsoft)

❌ **Do NOT** rely on `hooks`/`mcpServers`/`permissionMode` in plugin-distributed subagents -- silently ignored for security (Anthropic)

❌ **Do NOT** make Planner-type agents write code or Implementer-type agents redesign plans -- maintain separation of concerns

❌ **Do NOT** skip the description field -- it's the primary routing signal

---

## Worked Examples

### Example 1: Read-Only Planning Agent (VS Code)

A planning agent that collects context and produces a plan, then hands off to implementation.

```markdown
---
name: Planning Assistant
description: Generate implementation plans for new features. Collects project context, analyzes requirements, and produces phased implementation plans. Does NOT write code.
tools:
  - search
  - web
  - read_file
  - list_dir
handoffs:
  - label: Start Implementation
    agent: implementer
    prompt: Implement the plan outlined above.
    send: false
---

You are a planning agent. Your job is to:
1. Understand the user's requirements
2. Gather relevant project context
3. Produce a clear, phased implementation plan

**Constraints**:
- Do NOT write or modify code
- Do NOT make architectural decisions without user approval
- Always explain trade-offs and alternatives
```

**Why this works**:
- Read-only tools (search, read_file, list_dir) prevent accidental modifications
- Clear description helps routing
- Explicit handoff to implementer maintains separation of concerns
- Constraints reinforce the agent's narrow scope

---

### Example 2: Code Reviewer Subagent (Anthropic/Claude Code)

A specialist reviewer that can be delegated to automatically after code changes.

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code, or when the user asks for a code review.
tools:
  - Read
  - Grep
  - Glob
  - Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run `git diff` to see recent changes
2. Analyze code for:
   - Logic errors and edge cases
   - Security vulnerabilities (OWASP Top 10)
   - Performance issues
   - Code style and maintainability
3. Provide specific, actionable feedback with line references

**Output format**:
- Summary of changes reviewed
- Findings by severity (Critical, High, Medium, Low)
- Specific recommendations with code examples
```

**Why this works**:
- "Proactively" in description encourages automatic delegation
- Specific tools granted (Read, Grep, Glob, Bash for git)
- `model: inherit` uses parent session's model
- Structured output format ensures consistent reviews

---

### Example 3: OpenAI Agents SDK -- Weather Agent

A minimal agent demonstrating SDK-style definition with typed output.

```typescript
import { Agent, tool, z } from "@openai/agents-sdk";

const getWeather = tool({
  name: "get_weather",
  description: "Get current weather for a location",
  parameters: z.object({
    location: z.string().describe("City name"),
    unit: z.enum(["celsius", "fahrenheit"]).default("celsius")
  }),
  execute: async ({ location, unit }) => {
    // Implementation
    return { temperature: 22, unit, condition: "sunny" };
  }
});

const weatherAgent = new Agent({
  name: "Weather Bot",
  instructions: "You are a helpful weather assistant. Use the get_weather tool to answer questions about current weather conditions.",
  model: "gpt-4o-mini",
  tools: [getWeather],
  outputType: z.object({
    location: z.string(),
    temperature: z.number(),
    unit: z.string(),
    condition: z.string(),
    summary: z.string()
  })
});
```

**Why this works**:
- Single-purpose agent with one focused tool
- `outputType` provides typed structured output for downstream code
- Clear, concise instructions
- No unnecessary tools

---

### Example 4: Narrow-Tool Specialist (VS Code)

A security-focused agent with extremely limited tool access.

```markdown
---
name: Security Scanner
description: Scans code for security vulnerabilities. Read-only analysis only -- does NOT modify files or execute commands.
tools:
  - search
  - read_file
  - grep_search
user-invocable: true
disable-model-invocation: true
---

You are a security specialist focused on finding vulnerabilities.

**Scope**:
- OWASP Top 10 vulnerabilities
- Language-specific security patterns (SQL injection, XSS, etc.)
- Dependency vulnerabilities (if package files are present)
- Secrets in code (API keys, passwords)

**Process**:
1. Identify the technology stack from project files
2. Search for common vulnerability patterns
3. Report findings with severity, location, and remediation guidance

**Constraints**:
- Read-only analysis -- NEVER suggest or make code changes
- Flag findings, don't fix them
- Be specific about file paths and line numbers
```

**Why this works**:
- Minimal tool set (search, read_file, grep_search only)
- `disable-model-invocation: true` prevents automatic invocation as subagent
- Clear read-only constraints
- Specific scope prevents scope creep

---

## Cross-References

- For skill authoring guidance, see `skills/skill-authoring/SKILL.md`
- For hook authoring guidance, see `skills/hook-authoring/SKILL.md`
- For existing agent customization workflow, see the user-level agent-customization skill (if available)

---

## Source Bibliography

All sources accessed 2026-05-01.

- Microsoft: https://code.visualstudio.com/docs/copilot/customization/custom-agents
- Anthropic: https://code.claude.com/docs/en/sub-agents
- OpenAI: https://developers.openai.com/api/docs/guides/agents/define-agents
