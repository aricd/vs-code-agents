# Multi-Disciplinary Team Agents

> Specialized AI agents and skills for structured, auditable software delivery in VS Code -- distributed via system-level linking.

## What This Is

This repository provides a complete set of **custom agent definitions** and **skills** for GitHub Copilot in VS Code.

The agents are intentionally specialized to support a structured workflow (planning, review, security, testing, release) with clear handoffs and constraints. Distributed into VS Code via a one-time, system-level link setup -- see [LINKING.md](LINKING.md). This repo is separately also a Claude Code plugin in its own right (`plugin.json`, `hooks/`); that identity is unrelated to how it reaches VS Code and is unaffected by anything below -- see [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md).

## The Problem

AI coding assistants are powerful but chaotic:

- They forget context between sessions
- They try to do everything at once (plan, code, test, review)
- They skip quality gates and security reviews
- They lose track of decisions made earlier

## The Solution

This repository provides **specialized AI agents** that each own a specific part of your development workflow:

| Agent                  | Role                                       |
| ---------------------- | ------------------------------------------ |
| **Roadmap**            | Product vision and epics                   |
| **Planner**            | Implementation-ready plans (WHAT, not HOW) |
| **Analyst**            | Deep technical research                    |
| **Architect**          | System design and patterns                 |
| **Critic**             | Plan quality review                        |
| **Security**           | Comprehensive security assessment          |
| **Implementer**        | Code and tests                             |
| **Code Reviewer**      | Code quality gate before QA                |
| **QA**                 | Test strategy and verification             |
| **UAT**                | Business value validation                  |
| **DevOps**             | Packaging and releases                     |
| **ProcessImprovement** | Workflow evolution and lesson intake       |

Each agent has **clear constraints** (Planner can't write code, Implementer can't redesign) and produces **structured documents** that create an audit trail.

Use as many or as few as you need, in any order. They are designed to know their own role and work together with other agents in this repo. They are designed to work together to create a structured and auditable development process. They are also designed to challenge each other to ensure the best possible outcome.

## Directory Structure

This repository contains **shared agents and skills** used across multiple VS Code workspaces. A config-driven symlink system ensures consistent, repeatable setup:

```
/home/<user>/dev/mdt/vs-code-agents/
├── README.md                      ← This file
├── LINKING.md                     ← Symlinking guide (start here for setup)
├── Makefile                       ← Convenience commands (make setup, make verify)
├── scripts/
│   ├── link-config.example.yaml    ← Committed template — copy to link-config.yaml and edit
│   ├── link-config.yaml            ← Your local config (gitignored, never committed)
│   ├── link-setup.sh               ← Script: links shared skills/agents into workspaces
│   └── [other repo scripts...]
├── skills/
│   ├── system-integration-gate/   ← Prevent "built but not invoked" regressions
│   │   ├── SKILL.md
│   │   ├── README.md
│   │   └── smoke-check.sh         ← OS-agnostic smoke oracle
│   └── [other skills...]
└── agents/                        ← Shared agent definitions (if used)
    └── [agent definitions...]
```

The system-level `claude-user` target links this repo's skills into `~/.agents/skills`, which VS Code reads for every local workspace on that machine automatically -- no per-workspace copy to keep in sync. A per-workspace target (symlinking into that workspace's own `.github/skills`/`.github/agents`/`.github/prompts`) remains available as a documented fallback for the cases LINKING.md calls out, via the same `scripts/link_setup.py`.

**[→ See LINKING.md for complete linking setup and configuration guide](LINKING.md)**

## Requirements

| Requirement | Minimum |
| --- | --- |
| **VS Code** | **1.107** or later (custom agents and skills support) |
| **GitHub Copilot** | Active subscription with the GitHub Copilot Chat extension installed |

> [!NOTE] This repo previously also documented installing itself as a VS Code Agent Plugin (`chat.plugins.enabled`, **Chat: Install Plugin From Source**). That path is retired: Agent Plugin registrations are cached on the local client machine and are not discovered once the workspace is reopened over Remote-SSH, which silently drops every agent/skill with no error shown. See [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md).

## Quick Start

**The one supported install path is system-level linking**, via this repo's own `scripts/link_setup.py` (full detail in [LINKING.md](LINKING.md)).

### 1. Get the Agents

```bash
git clone https://git.example.com/acme/vs-code-agents.git
```

### 2. Link Skills System-Wide

**One whole-directory link, made once per machine.** `link_setup.py` does not manage it -- see [LINKING.md](LINKING.md) for why, and for the warning about pointing the linker at it.

Windows (junction -- needs neither Developer Mode nor an elevated shell):

```
mklink /J "%USERPROFILE%\.agents\skills" "C:\path\to\vs-code-agents\skills"
```

POSIX:

```bash
ln -s /path/to/vs-code-agents/skills ~/.agents/skills
```

Every skill in this repo is then visible to every local VS Code session on that machine, and a newly committed skill appears with no re-run. Repeat once on each machine you use, including each Remote-SSH host (clone the repo there and make the same link from that host's own shell), since `~/.agents` is scoped to whichever machine it lives on.

`make setup` / `make setup-dry-run` drive `scripts/link_setup.py`, which exists for the **per-workspace fallback** in LINKING.md -- not for the home-level link above.

> [!NOTE] Agents and prompts do not have a confirmed system-level VS Code discovery location yet (see [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md)) -- `link_skills` is the only flag this target enables by default. A workspace that needs synced agents/prompts can add a per-workspace target for those two primitives in `scripts/link-config.yaml` (LINKING.md's Per-Workspace Fallback section); that reintroduces a small double-registration risk for anything also covered by a future system-level location, so keep it scoped to the workspaces that actually need it.

### 3. Use in Copilot Chat

In VS Code, select your agent from the **agents dropdown** at the top of the Chat panel, then type your prompt:

```text
Create a plan for adding user authentication
```

> [!NOTE] Unlike built-in participants (e.g., `@workspace`), custom agents are **not** invoked with the `@` symbol. You must select them from the dropdown or use the Command Palette.

### VS Code Settings (Recommended)

> [!NOTE] Review the `chat.tools.*.autoApprove` entries below before enabling. These settings allow certain actions to proceed without per-action confirmation.

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

| Document                                   | Purpose                        |
| ------------------------------------------ | ------------------------------ |
| [USING-AGENTS.md](USING-AGENTS.md)         | Quick start guide (5 min read) |
| [AGENTS-DEEP-DIVE.md](AGENTS-DEEP-DIVE.md) | Comprehensive documentation    |
| [CHANGELOG.md](CHANGELOG.md)               | Notable repository changes     |

---

### Typical Workflow

```text
Roadmap -> Planner -> Analyst/Architect/Security/Critic -> Implementer -> Code Reviewer -> QA -> UAT -> Planner mini-retro -> DevOps
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
11. **Planner** runs the mandatory `mini-retro` before the DevOps handoff; **ProcessImprovement** routes lessons into the next cycle
12. **DevOps** releases (with user approval)

---

## Key Features

### 🎯 Separation of Concerns

Each agent has one job. Planner plans. Implementer implements. No scope creep.

### 📝 Document-Driven

Agents produce Markdown documents in `.agent-output/`. Every decision is recorded.

### 🔒 Quality Gates

Critic reviews plans. Security audits code. QA verifies tests. Nothing ships without checks.

### 🎯 Literal Intent Fidelity

When you state a criterion -- _"all Python files that may be executed when interpreting specs"_ -- agents must test **those words**, not a narrower paraphrase of them. The `literal-intent-fidelity` skill requires the criterion to be quoted verbatim, the candidate list to be enumerated from the repository, and **every** verdict (inclusions and exclusions alike) to carry a citation. Role arguments ("it's just plumbing", "it's a test harness") are not valid exclusion reasons, and budget pressure is surfaced as an explicit cost decision instead of a quiet scope reduction.

It also pins the **target** a criterion is applied to -- working tree, remote, branch, canonical source vs. generated copy. A target inherited from the session or a prior task is disclosed in one line before the first edit, and an ambiguous one is asked about, because a flawless answer about the wrong repository is still the wrong answer.

A `UserPromptSubmit` hook detects stated criteria and scope pushback in your prompt and injects a `[Literal-Criterion Check]` reminder, so the guardrail applies even when the agent would not have thought to load the skill.

### 🔄 Handoffs

Agents hand off to each other with context. No lost information between phases.

### 📌 Execution Orchestration (Optional)

For larger changes, you can use the `execution-orchestration` skill to coordinate subagent work with strict quality gates and a single authoritative execution-state file:

- Skill: `execution-orchestration`
- State file location: `.agent-output/planning/<ID>-execution-state.yaml`

### 🎛️ Planner as Orchestrator

The **Planner** agent serves as the primary orchestrator for structured multi-agent delivery. Once one or more plans are user-approved, the Planner can:

- **Delegate execution** to any other agent (Implementer, Critic, QA, etc.) as subagents
- **Coordinate multiple plans concurrently**, tracking each through its own execution-state file
- **Enforce workflow gates** -- ensuring plans progress through the correct sequence (Critic -> Implementer -> Code Reviewer -> QA -> UAT -> DevOps)
- **Monitor progress** via the execution-state YAML, surfacing blockers and completion status

This is the recommended workflow for any structured, multi-step delivery effort. See the `execution-orchestration` skill and [USING-AGENTS.md](USING-AGENTS.md#planner-as-orchestrator) for details.

---

## Repository Structure Validation

`scripts/smoke-test-plugin.{sh,ps1}` validates this repo's own structure: agent/skill frontmatter, `hooks/hooks.json` (this repo's Claude Code plugin manifest -- unrelated to the retired VS Code Agent Plugin install path, see [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md)), duplicate agent names, dangling skill references, and a few other structural invariants listed at the top of the script. It is not a VS Code integration test; nothing here installs or probes a VS Code instance.

```bash
./scripts/smoke-test-plugin.sh
```

PowerShell equivalent:

```powershell
./scripts/smoke-test-plugin.ps1
```

---

## Migrating Off the VS Code Agent Plugin Install

If you previously used **Chat: Install Plugin From Source** (the now-retired install path -- see [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md)), switch to system-level linking:

1. **Remove the plugin registration**: Command Palette -> `Chat: Show Chat Diagnostics` -> find this repo under "Plugins" -> remove it from that VS Code installation.
2. **Remove any workspace-level copies** you may also have, to avoid duplicate agents:
   ```bash
   rm -f .github/agents/*.agent.md
   rm -rf .github/skills/architecture-patterns .github/skills/testing-patterns  # etc.
   ```
3. **Set up system-level linking** per Quick Start above.
4. **Verify**: reload the window and confirm each agent/skill appears exactly once.

> [!NOTE] The `.agent-output/` directory is a workspace runtime artifact and is not distributed by either install path.

---

## Repository Structure

```text
├── plugin.json                  # Claude Code plugin manifest (see ADR-017 -- unrelated to how VS Code gets these agents/skills)
├── agents/                      # Agent definitions (12 files)
│   ├── planner.agent.md
│   ├── implementer.agent.md
│   └── ... (11 more)
├── skills/                      # Skill definitions
│   ├── execution-orchestration/
│   ├── testing-patterns/
│   ├── agent-authoring/
│   ├── skill-authoring/
│   ├── hook-authoring/
│   ├── mini-retro/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── question-bank.md        # Tier-1 baseline (incl. gradient-scorecard)
│   │   │   ├── memory-model.md
│   │   │   ├── project-policy.schema.md
│   │   │   └── gradient-scorecard.md  # 20-question 1-10 rubric (single owner)
│   │   └── assets/
│   │       ├── mini-retro-template.md
│   │       ├── gradient-scorecard-blank.md  # standalone blank fill-in form
│   │       ├── gradient-scorecard-example.md # walk-through example (ILLUSTRATIVE)
│   │       └── project-policy.example.yaml
│   └── ...
├── hooks/                       # Claude Code plugin hooks
│   ├── hooks.json
│   ├── user-prompt-submit.sh
│   └── user-prompt-submit.ps1
├── scripts/                     # Validation + linking scripts
│   ├── validate-plan-template.sh
│   ├── validate-plan-template.ps1
│   ├── smoke-test-plugin.sh
│   ├── smoke-test-plugin.ps1
│   ├── link_setup.py            # Canonical linking implementation (see LINKING.md)
│   ├── link-setup.sh
│   └── link-setup.ps1
├── README.md
├── USING-AGENTS.md
├── AGENTS-DEEP-DIVE.md
└── CHANGELOG.md
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

The Security Agent systematically checks all of these, producing actionable findings with severity ratings and remediation guidance.

See [security.agent.md](agents/security.agent.md) for the full specification.

---

## Customization

### Modify Existing Agents

Edit `.agent.md` files to adjust:

- `description`: What shows in Copilot
- `tools`: Which VS Code tools the agent can use (either a coarse group-level array, e.g. `[execute, read, agent, edit, search, todo]`, or a granular per-capability array, e.g. `['execute/runInTerminal', 'read/readFile', ...]` -- both forms are valid; an agent uses whichever grain its constraints require)
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
- **Template**: `agents/analyst.references/uncertainty-review-template.md` provides a repeatable output format.

### Skills System (2025-12-19)

Agents now use **Claude Skills**--modular, reusable instruction sets that load on-demand:

| Skill | Purpose |
| --- | --- |
| `code-review` | Unified pre/post-implementation review criteria, severity definitions, document templates |
| `cross-repo-contract` | Multi-repo API type safety and contract coordination |
| `document-lifecycle` | Unified numbering, automated closure, orphan detection |
| `implementation-principles` | DRY, YAGNI, Rule of Three, composition, SoC, POLA, Boy Scout Rule, defensive programming |
| `release-procedures` | Two-stage release workflow, semver, platform constraints |
| `security-patterns` | OWASP Top 10, language-specific vulnerabilities |
| `testing-patterns` | TDD workflow, test pyramid, coverage strategies |

**Skill Placement:**

- **VS Code Stable (1.107+)**: Place in `.claude/skills/`
- **VS Code Insiders**: Place in `.github/skills/`

> [!NOTE] These locations are changing with upcoming VS Code releases. The `.github/skills/` location is becoming the standard. See the [VS Code Agent Skills documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills) for the latest guidance.

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

- **Unified numbering**: All documents in a work chain share the same ID (analysis 080 -> plan 080 -> qa 080 -> uat 080)
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

## Related Resources

- [GitHub Copilot Agents Documentation](https://code.visualstudio.com/docs/copilot/copilot-agents)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
