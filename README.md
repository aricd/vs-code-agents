# Multi-Disciplinary Team Agents Plugin

> 13 specialized AI agents and 19 skills for structured, auditable software delivery in VS Code — installable as a single VS Code Agent Plugin.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## What This Is

The **Multi-Disciplinary Team Agents Plugin** provides a complete set of **custom agent definitions** and **skills** for GitHub Copilot in VS Code.

The agents are intentionally specialized to support a structured workflow (planning, review, security, testing, release) with clear handoffs and constraints. Install as a VS Code Agent Plugin for one-action setup, or copy individual files for per-workspace customization.

## The Problem

AI coding assistants are powerful but chaotic:
- They forget context between sessions
- They try to do everything at once (plan, code, test, review)
- They skip quality gates and security reviews
- They lose track of decisions made earlier

## The Solution

This repository provides **specialized AI agents** that each own a specific part of your development workflow:

| Agent | Role |
|-------|------|
| **Roadmap** | Product vision and epics |
| **Planner** | Implementation-ready plans (WHAT, not HOW) |
| **Analyst** | Deep technical research |
| **Architect** | System design and patterns |
| **Critic** | Plan quality review |
| **Security** | Comprehensive security assessment |
| **Implementer** | Code and tests |
| **Code Reviewer** | Code quality gate before QA |
| **QA** | Test strategy and verification |
| **UAT** | Business value validation |
| **DevOps** | Packaging and releases |
| **Retrospective** | Lessons learned |
| **ProcessImprovement** | Workflow evolution |

Each agent has **clear constraints** (Planner can't write code, Implementer can't redesign) and produces **structured documents** that create an audit trail.

Use as many or as few as you need, in any order. They are designed to know their own role and work together with other agents in this repo. They are designed to work together to create a structured and auditable development process. They are also designed to challenge each other to ensure the best possible outcome.

## Requirements

| Requirement | Minimum |
|-------------|---------|
| **VS Code** | **1.110** or later (agent plugins introduced in [v1.110 — February 2026](https://code.visualstudio.com/updates/v1_110#_agent-plugins-experimental)) |
| **GitHub Copilot** | Active subscription with the GitHub Copilot Chat extension installed |
| **Setting** | `chat.plugins.enabled` must be `true` (plugins are currently a Preview feature) |

> [!TIP]
> Option B (copy to workspace) works on any VS Code version that supports custom agents and skills (v1.107+). The v1.110 requirement applies only to the Plugin install method.

## Quick Start

### Option A: Install as a Plugin (Recommended)

1. Open VS Code **1.110+** and ensure `chat.plugins.enabled` is `true` in your settings
2. Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
3. Run **Chat: Install Plugin From Source**
4. Enter the Git URL: `https://github.com/groupzer0/agents.git`
5. All 13 agents and 19 skills are immediately available in Copilot Chat

> [!NOTE]
> Agent Plugins are currently a Preview feature in VS Code 1.110+. You must enable `chat.plugins.enabled` in VS Code settings.

### Option B: Copy to Your Project (Per-Workspace)

### 1. Get the Agents

```bash
git clone https://github.com/groupzer0/agents.git
```

### 2. Add to Your Project

Copy agents to your workspace (per-repo, recommended):
```text
your-project/
└── .github/
    └── agents/
        ├── planner.agent.md
        ├── implementer.agent.md
        └── ... (others you need)
```

Or install them at the **user level** so they are available across all VS Code workspaces. User-level agents are stored in your [VS Code profile folder](https://code.visualstudio.com/docs/configure/profiles):

- **Linux**: `~/.config/Code/User/`
- **macOS**: `~/Library/Application Support/Code/User/`
- **Windows**: `%APPDATA%\Code\User\`

> [!TIP]
> The easiest way to create a user-level agent is via the Command Palette: **Chat: New Custom Agent** → select **User profile**. VS Code will place it in the correct location automatically.


### 3. Use in Copilot Chat

In VS Code, select your agent from the **agents dropdown** at the top of the Chat panel, then type your prompt:

```text
Create a plan for adding user authentication
```

> [!NOTE]
> Unlike built-in participants (e.g., `@workspace`), custom agents are **not** invoked with the `@` symbol. You must select them from the dropdown or use the Command Palette.

### VS Code Settings (Recommended)

> [!NOTE]
> Review the `chat.tools.*.autoApprove` entries below before enabling. These settings allow certain actions to proceed without per-action confirmation.

```json
{
    "accessibility.hideAccessibleView": true,
    "chat.agent.maxRequests": 256,
    "chat.checkpoints.showFileChanges": true,
    "chat.customAgentInSubagent.enabled": true,
    "chat.instructionsFilesLocations": {
        ".github/instructions": true
    },
    "chat.mcp.autostart": "newAndOutdated",
    "chat.mcp.gallery.enabled": true,
    "chat.tools.terminal.autoApprove": {
        "cd": true,
        "git": true,
        "npm": true,
        "python": true
    },
    "chat.tools.urls.autoApprove": {
        "https://duckduckgo.com": {
            "approveRequest": false,
            "approveResponse": true
        },
        "https://github.com": {
            "approveRequest": false,
            "approveResponse": true
        },
        "https://vtk.org": true,
        "https://www.google.com": {
            "approveRequest": false,
            "approveResponse": true
        }
    },
    "chat.useAgentSkills": true,
    "editor.accessibilitySupport": "off",
    "github.copilot.nextEditSuggestions.enabled": true,
    "terminal.integrated.accessibleViewFocusOnCommandExecution": false
}
```

### 4. (Optional) Use with GitHub Copilot CLI

You can also use these agents with the GitHub Copilot CLI by placing your `.agent.md` files under `.github/agents/` in each repository where you run the CLI, then invoking them with commands like:

```bash
copilot --agent planner --prompt "Create a plan for adding user authentication"
```

**Known limitation (user-level agents):** The Copilot CLI currently has an upstream bug where user-level agents in `~/.copilot/agents/` are not loaded, even though they are documented ([github/copilot-cli#452](https://github.com/github/copilot-cli/issues/452)). This behavior and the recommended per-repository workaround were identified and documented by @rjmurillo. Until the bug is fixed, prefer `.github/agents/` in each repo.


## Documentation

| Document | Purpose |
|----------|---------|
| [USING-AGENTS.md](USING-AGENTS.md) | Quick start guide (5 min read) |
| [AGENTS-DEEP-DIVE.md](AGENTS-DEEP-DIVE.md) | Comprehensive documentation |
| [CHANGELOG.md](CHANGELOG.md) | Notable repository changes |

---

### Typical Workflow

```text
Roadmap → Planner → Analyst/Architect/Security/Critic → Implementer → Code Reviewer → QA → UAT → DevOps
```

1. **Roadmap** defines what to build and why
2. **Planner** creates a structured plan at the feature level or smaller
3. **Analyst** researches unknowns
4. **Architect** ensures design fit. Enforces best practices.
5. **Security** audits for vulnerabilities. Recommends best practices.
6. **Critic** reviews plan quality
7. **Implementer** writes code
8. **Code Reviewer** verifies code quality
9. **QA** verifies tests. Ensures robust test coverage
10. **UAT** confirms business value was delivered
11. **DevOps** releases (with user approval)

---

## Key Features

### 🎯 Separation of Concerns
Each agent has one job. Planner plans. Implementer implements. No scope creep.

### 📝 Document-Driven
Agents produce Markdown documents in `.agent-output/`. Every decision is recorded.

### 🔒 Quality Gates
Critic reviews plans. Security audits code. QA verifies tests. Nothing ships without checks.

### 🔄 Handoffs
Agents hand off to each other with context. No lost information between phases.

### 📌 Execution Orchestration (Optional)
For larger changes, you can use the execution orchestration skills to coordinate subagent work with strict quality gates and a single authoritative execution-state file:
- Skills: `execution-orchestration`, `planner-execution-orchestration`
- State file location: `.agent-output/planning/<ID>-execution-state.yaml`

### 🎛️ Planner as Orchestrator

The **Planner** agent serves as the primary orchestrator for structured multi-agent delivery. Once one or more plans are user-approved, the Planner can:

- **Delegate execution** to any other agent (Implementer, Critic, QA, etc.) as subagents
- **Coordinate multiple plans concurrently**, tracking each through its own execution-state file
- **Enforce workflow gates** — ensuring plans progress through the correct sequence (Critic → Implementer → Code Reviewer → QA → UAT → DevOps)
- **Monitor progress** via the execution-state YAML, surfacing blockers and completion status

This is the recommended workflow for any structured, multi-step delivery effort. See the `planner-execution-orchestration` skill and [USING-AGENTS.md](USING-AGENTS.md#planner-as-orchestrator) for details.

---

## Plugin Testing

Scripts for validating plugin structure and verifying VS Code integration.

### Level 1: Smoke Tests (Structural Validation)

Validates plugin files without launching VS Code:

```bash
# Basic validation (agents/, skills/, hooks, plugin.json)
./scripts/smoke-test-plugin.sh

# Also validate canonical source directory
./scripts/smoke-test-plugin.sh --canonical

# Check for drift between canonical and plugin copies
./scripts/smoke-test-plugin.sh --sync-check
```

PowerShell equivalent:
```powershell
./scripts/smoke-test-plugin.ps1
./scripts/smoke-test-plugin.ps1 -Canonical
./scripts/smoke-test-plugin.ps1 -SyncCheck
```

### Level 2: Install Probe (VS Code Integration)

Creates a temporary VS Code profile with the plugin registered for manual verification:

```bash
# Generate instructions for manual verification
./scripts/install-probe.sh

# Launch VS Code with the temporary profile
./scripts/install-probe.sh --launch
```

After VS Code opens:
1. Open Copilot Chat (`Ctrl+Shift+I`)
2. Open Chat Diagnostics: Command Palette → `Chat: Show Chat Diagnostics`
3. Verify all 13 agents and 19 skills appear in the diagnostics view

### Level 3: Post-Install Discovery (Future)

Automated verification that VS Code discovered the plugin is not yet available. VS Code does not currently provide a headless API to query loaded plugins programmatically.

**Recommended future approach**: A custom VS Code test extension that queries the `chat.plugins` API and runs in CI via `@vscode/test-electron`.

### Chat Diagnostics Reference

To manually verify plugin loading at any time:
1. Open Command Palette (`Ctrl+Shift+P`)
2. Run `Chat: Show Chat Diagnostics`
3. Expand the "Plugins" section to see registered plugins and their agents/skills

---

## Migrating from Workspace-Level Agents to Plugin

If you previously copied agent files into `.github/agents/` or `~/.config/Code/User/`, you may see duplicate agents after installing the plugin. To resolve:

1. **Check for duplicates**: Open Copilot Chat and look for agents with the same name but different sources (plugin vs. workspace)
2. **Remove workspace copies**: Delete the manually-copied `.agent.md` files from your `.github/agents/` directory
3. **Remove workspace skills**: Delete any manually-copied skill directories from `.github/skills/` or `.claude/skills/`
4. **Verify**: Confirm only the plugin-provided agents appear in the agents dropdown

```bash
# Quick cleanup — remove workspace-level copies if using the plugin
rm -f .github/agents/*.agent.md
rm -rf .github/skills/analysis-methodology .github/skills/architecture-patterns  # etc.
```

> [!NOTE]
> The `.agent-output/` directory (renamed from `agent-output/`) is a workspace runtime artifact and is NOT part of the plugin. If you have an existing `agent-output/` directory, rename it:
> ```bash
> mv agent-output .agent-output
> ```

---

## Repository Structure

```text
├── plugin.json                  # Plugin manifest
├── agents/                      # Plugin-discoverable agents (13 files)
│   ├── planner.agent.md
│   ├── implementer.agent.md
│   └── ... (11 more)
├── skills/                      # Plugin-discoverable skills (19 directories)
│   ├── execution-orchestration/
│   ├── testing-patterns/
│   ├── reference/               # Shared reference docs
│   └── ... (16 more)
├── hooks/                       # Plugin hooks
│   ├── hooks.json
│   ├── user-prompt-submit.sh
│   └── user-prompt-submit.ps1
├── scripts/                     # Validation and sync scripts
│   ├── validate-plan-template.sh
│   ├── validate-plan-template.ps1
│   └── sync-plugin.sh
├── vs-code-agents/              # Canonical source (agents + skills)
│   ├── *.agent.md
│   ├── skills/
│   └── reference/
├── README.md
├── USING-AGENTS.md
├── AGENTS-DEEP-DIVE.md
├── CHANGELOG.md
└── LICENSE
```

---

## Security Agent Highlight

The **Security Agent** has been enhanced to provide truly comprehensive security reviews:

### Five-Phase Framework
1. **Architectural Security**: Trust boundaries, STRIDE threat modeling, attack surface mapping
2. **Code Security**: OWASP Top 10, language-specific vulnerability patterns
3. **Dependency Security**: CVE scanning, supply chain risk assessment
4. **Infrastructure Security**: Headers, TLS, container security
5. **Compliance**: OWASP ASVS, NIST, industry standards

### Why This Matters

Most developers don't know how to conduct thorough security reviews. They miss:
- Architectural weaknesses (implicit trust, flat networks)
- Language-specific vulnerabilities (prototype pollution, pickle deserialization)
- Supply chain risks (abandoned packages, dependency confusion)
- Compliance gaps (missing security headers, weak TLS)

The Security Agent systematically checks all of these, producing actionable findings with severity ratings and remediation guidance.You can then hand this off to the Planner agent and the Implementer to address. 

See [security.agent.md](vs-code-agents/security.agent.md) for the full specification.

---

## Customization

### Modify Existing Agents

Edit `.agent.md` files to adjust:
- `description`: What shows in Copilot
- `tools`: Which VS Code tools the agent can use
- `handoffs`: Other agents it can hand off to
- Responsibilities and constraints

### Create New Agents

1. Create `your-agent.agent.md` following the existing format
2. Define purpose, responsibilities, constraints
3. Add to `.github/agents/` in your workspace

---

## Recent Updates

Recent commits introduced significant improvements to agent workflow and capabilities:

### Uncertainty-Aware Issue Analysis (2026-01-15)

Agents now explicitly avoid forced root-cause narratives when evidence is missing.

- **Analyst**: Uses an objective hard pivot trigger (timebox/evidence gate) to switch from RCA attempts to system hardening + telemetry requirements.
- **Architect**: Treats insufficient observability as an architectural risk; defines normal vs debug logging guidance and a minimum viable incident telemetry baseline.
- **QA**: Validates diagnosability improvements; prefers asserting structured telemetry fields/events over brittle log string matching.
- **Template**: `vs-code-agents/reference/uncertainty-review-template.md` provides a repeatable output format.

### Skills System (2025-12-19)

Agents now use **Claude Skills**—modular, reusable instruction sets that load on-demand:

| Skill | Purpose |
|-------|---------|
| `analysis-methodology` | Confidence levels, gap tracking, investigation techniques |
| `architecture-patterns` | ADR templates, patterns, anti-pattern detection |
| `code-review-checklist` | Pre/post-implementation review criteria |
| `code-review-standards` | Code review checklist, severity definitions, document templates |
| `cross-repo-contract` | Multi-repo API type safety and contract coordination |
| `document-lifecycle` | Unified numbering, automated closure, orphan detection |
| `engineering-standards` | SOLID, DRY, YAGNI, KISS with detection patterns |
| `release-procedures` | Two-stage release workflow, semver, platform constraints |
| `security-patterns` | OWASP Top 10, language-specific vulnerabilities |
| `testing-patterns` | TDD workflow, test pyramid, coverage strategies |

**Skill Placement:**
- **VS Code Stable (1.107.1)**: Place in `.claude/skills/`
- **VS Code Insiders**: Place in `.github/skills/`

> [!NOTE]
> These locations are changing with upcoming VS Code releases. The `.github/skills/` location is becoming the standard. See the [VS Code Agent Skills documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills) for the latest guidance.

### Key Agent Flow Improvements

- **TDD mandatory**: Implementer and QA now require Test-Driven Development for new feature code
- **Two-stage release**: DevOps commits locally first; pushes only on explicit release approval
- **Document status tracking**: All agents update Status fields in planning docs ("Draft", "In Progress", "Released")
- **Open Question Gate**: Implementer halts if plans have unresolved questions; requires explicit user acknowledgment to proceed
- **Slimmed Security agent**: Reduced by 46% using skill references instead of inline content

### Cross-Repository Contract Skill (2025-12-26)

New `cross-repo-contract` skill for projects with runtime + backend repos that need to stay aligned:

- **Contract discovery**: Agents check `api-contract/` or `.contracts/` for type definitions
- **Type safety enforcement**: Implementer verifies contract definitions before coding API endpoints/clients
- **Breaking change coordination**: Plans must document contract changes and sync dependencies
- **Quality gate**: Critic verifies multi-repo plans address contract adherence

Integrated into Architect, Planner, Implementer, and Critic agents.

### Document Lifecycle System (2025-12-24)

New `document-lifecycle` skill implementing:

- **Unified numbering**: All documents in a work chain share the same ID (analysis 080 → plan 080 → qa 080 → uat 080)
- **Automated closure**: Documents move to `closed/` subfolders after commit
- **Orphan detection**: Agents self-check + Roadmap periodic sweep

This keeps active plans visible while archiving completed work for traceability.

### Previous Updates
- **Aligned agent tool names with VS Code APIs (2025-12-16)**: Agent `tools` definitions now use official VS Code agent tool identifiers.
- **Added subagent usage patterns (2025-12-15)**: Planner, Implementer, QA, Analyst, and Security document how to invoke each other as scoped subagents.
- **Background Implementer mode (2025-12-15)**: Implementation can run as local chat or background agent in isolated Git worktree.

## Contributing

Contributions welcome! Areas of interest:

- **Agent refinements**: Better constraints, clearer responsibilities
- **New agents**: For specialized workflows (e.g., Documentation, Performance)
- **Documentation**: Examples, tutorials, troubleshooting

This repository also runs an automatic **Markdown lint** check in GitHub Actions on pushes and pull requests that touch `.md` files. The workflow uses `markdownlint-cli2` with a shared configuration, and helps catch issues like missing fenced code block languages (MD040) early in review. This lint workflow was proposed based on feedback and review from @rjmurillo.

---

## Requirements

- VS Code with GitHub Copilot

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Related Resources

- [GitHub Copilot Agents Documentation](https://code.visualstudio.com/docs/copilot/copilot-agents)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
