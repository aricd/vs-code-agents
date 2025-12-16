# VS Code Agents

> A multi-agent workflow system for GitHub Copilot in VS Code that brings structure, quality gates, and long-term memory to AI-assisted development.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

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
| **QA** | Test strategy and verification |
| **UAT** | Business value validation |
| **DevOps** | Packaging and releases |
| **Retrospective** | Lessons learned |
| **ProcessImprovement** | Workflow evolution |

Each agent has **clear constraints** (Planner can't write code, Implementer can't redesign) and produces **structured documents** that create an audit trail.

You don't have to use them all. You don't have to use them in order. You can use some more than others. But, they are designed to know their role and the role of the other agents in this repo. 

## Quick Start

### 1. Get the Agents

```bash
git clone https://github.com/yourusername/agents.git
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

Or install them at the **user level** so they are available across all VS Code workspaces (paths vary by OS):

- **Linux**: `~/.config/github-copilot/agents/`
- **macOS**: `~/Library/Application Support/github-copilot/agents/`
- **Windows**: `%APPDATA%/github-copilot/agents/`

Place your `.agent.md` files directly in that directory, for example on Linux:

```text
~/.config/github-copilot/agents/
├── planner.agent.md
├── implementer.agent.md
└── ... (others you need)
```

### 3. Use in Copilot Chat

```text
@Planner Create a plan for adding user authentication
@Implementer Implement the approved plan at agent-output/planning/001-auth-plan.md
```

### 4. (Recommended) Enable Memory

Install [Flowbaby](https://marketplace.visualstudio.com/items?itemName=flowbaby.flowbaby) for cross-session memory:

1. VS Code Extensions → Search "Flowbaby" → Install
2. Command Palette → "Flowbaby: Initialize Workspace"
3. Command Palette → "Flowbaby: Set API Key"

### 5. (Optional) Use with GitHub Copilot CLI

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
| [memory-contract-example.md](vs-code-agents/memory-contract-example.md) | Memory usage patterns |

---

### Typical Workflow

```text
Roadmap → Planner → Analyst/Architect/Security/Critic → Implementer → QA → UAT → DevOps
```

1. **Roadmap** defines what to build and why
2. **Planner** creates a structured plan at the feature level or smaller
3. **Analyst** researches unknowns
4. **Architect** ensures design fit. Enforces best practices.
5. **Security** audits for vulnerabilities. Recommends best practices.
6. **Critic** reviews plan quality
7. **Implementer** writes code
8. **QA** verifies tests. Ensures robust test coverage
9. **UAT** confirms business value was delivered
10. **DevOps** releases (with user approval)

---

## Key Features

### 🎯 Separation of Concerns
Each agent has one job. Planner plans. Implementer implements. No scope creep.

### 📝 Document-Driven
Agents produce Markdown documents in `agent-output/`. Every decision is recorded.

### 🔒 Quality Gates
Critic reviews plans. Security audits code. QA verifies tests. Nothing ships without checks.

### 🧠 Robust Memory
With [Flowbaby](https://github.com/groupzer0/flowbaby), agents remember decisions across sessions.

### 🔄 Handoffs
Agents hand off to each other with context. No lost information between phases.

---

## Flowbaby Memory Integration

[Flowbaby](https://github.com/groupzer0/flowbaby) is a VS Code extension that provides **workspace-scoped long-term memory** for GitHub Copilot.

### Why Flowbaby?

Most AI memory solutions don't work well:

| Approach | Problem |
|----------|---------|
| Chat history | Lost between sessions |
| Vector DB alone | No structure, poor relationships |
| Manual notes | Inconsistent, requires effort |
| RAG on files | Noisy, retrieves irrelevant content |

**Flowbaby's approach**:
- **Hybrid Graph-Vector Search**: Combines knowledge graphs with vector similarity
- **Structured Summaries**: Stores decisions and reasoning, not raw logs
- **Workspace Isolation**: Each project has separate memory
- **Privacy-First**: All data stays local

### Key Features

- **Automatic memory search**: Flowbaby detects when context is needed
- **Automatic memory storage**: Stores key decisions and milestones
- **@flowbaby participant**: Query memory directly in chat
- **Agent tools**: `#flowbabyStoreSummary` and `#flowbabyRetrieveMemory`

### Links

- **GitHub**: https://github.com/groupzer0/flowbaby
- **VS Code Marketplace**: https://marketplace.visualstudio.com/items?itemName=flowbaby.flowbaby
- **Documentation**: See the GitHub README for full setup guide

---

## Repository Structure

```text
agents/
├── README.md                    # This file
├── USING-AGENTS.md              # Quick start guide
├── AGENTS-DEEP-DIVE.md          # Comprehensive documentation
├── LICENSE                      # MIT License
└── vs-code-agents/              # Agent definitions
    ├── analyst.agent.md
    ├── architect.agent.md
    ├── critic.agent.md
    ├── devops.agent.md
    ├── implementer.agent.md
    ├── pi.agent.md              # ProcessImprovement
    ├── planner.agent.md
    ├── qa.agent.md
    ├── retrospective.agent.md
    ├── roadmap.agent.md
    ├── security.agent.md
    ├── uat.agent.md
    └── reference/
        └── memory-contract-example.md
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
3. Include the Memory Contract section
4. Add to `.github/agents/` in your workspace

---

## Recent Updates

The last few commits introduced several improvements to how these agents integrate with VS Code and Flowbaby:

- **Refined Flowbaby memory contract (88ae9ccd, 2025-12-16)**: All core agents now embed a unified Flowbaby memory contract and share a concrete example in [vs-code-agents/reference/memory-contract-example.md](vs-code-agents/reference/memory-contract-example.md), making memory usage mandatory and consistent.
- **Aligned agent tool names with VS Code APIs (c47c1e2, 2025-12-16)**: Agent `tools` definitions now use the official VS Code agent tool identifiers (for example, `read/readFile`, `edit/editFiles`, `execute/runInTerminal`), improving reliability when running as VS Code agents.
- **Added subagent usage patterns (d5be1cc, 2025-12-15)**: Planner, Implementer, QA, Analyst, and Security now document how to invoke each other as scoped subagents in VS Code 1.107, while preserving clear ownership of planning, implementation, QA, and security responsibilities.
- **Background Implementer mode (5958e05, 2025-12-15)**: Planner and Implementer now explain that implementation can run either as a local chat session or as a background agent (for example, in a separate Git worktree), with the human user always choosing the mode.
- **Repository cleanup and unified memory (dde6211, 2025-12-15)**: Removed the legacy `memory.agent.md` in favor of the shared memory contract embedded in each agent and cleaned up an unused Markdown lint configuration file.

## Contributing

Contributions welcome! Areas of interest:

- **Agent refinements**: Better constraints, clearer responsibilities
- **New agents**: For specialized workflows (e.g., Documentation, Performance)
- **Memory patterns**: Better retrieval/storage strategies
- **Documentation**: Examples, tutorials, troubleshooting

This repository also runs an automatic **Markdown lint** check in GitHub Actions on pushes and pull requests that touch `.md` files. The workflow uses `markdownlint-cli2` with a shared configuration, and helps catch issues like missing fenced code block languages (MD040) early in review. This lint workflow was proposed based on feedback and review from @rjmurillo.

---

## Requirements

- VS Code with GitHub Copilot
- For memory: [Flowbaby extension](https://marketplace.visualstudio.com/items?itemName=flowbaby.flowbaby) + Python 3.10+

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Related Resources

- [GitHub Copilot Agents Documentation](https://code.visualstudio.com/docs/copilot/copilot-agents)
- [Flowbaby Extension](https://github.com/groupzer0/flowbaby)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
