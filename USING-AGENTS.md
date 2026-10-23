# Using the Agents

This file contains a high-level overview of these agents and how to get started using them quickly. However, you may find you want or need more guidance. In that case, see the AGENTS-DEEP-DIVE.md file.

## Overview

This repo defines a set of `.agent.md` files that configure specialized AI personas ("agents") for a structured software delivery workflow. Each agent focuses on a specific phase or concern (planning, implementation, QA, UAT, DevOps, etc.), with clear responsibilities, constraints, and handoffs.

A typical high-level workflow looks like:

Roadmap -> Planner -> (Analyst, Architect, Critic, Security) -> Implementer -> Code Reviewer -> QA -> UAT -> Planner mini-retro -> DevOps

## Where to Put These Files

**The one supported path is system-level linking** -- a single whole-directory link, made once per machine (full detail, including why the linker must not be pointed at it, in [LINKING.md](LINKING.md)):

```
mklink /J "%USERPROFILE%\.agents\skills" "C:\path\to\vs-code-agents\skills"   :: Windows
ln -s /path/to/vs-code-agents/skills ~/.agents/skills                            # POSIX
```

VS Code reads `~/.agents/skills` for every local workspace on that machine -- no plugin registration, no per-workspace copy to keep in sync, no re-run when a skill is added, and no cache-locality problem when a workspace is opened over Remote-SSH (make the same link once on each Remote-SSH host too, since `~/.agents` is scoped per machine).

This repo previously also documented installing itself as a VS Code **Agent Plugin** (`chat.plugins.enabled`, **Chat: Install Plugin From Source**). That path is retired: Agent Plugin registrations are cached on the local client machine and are not discovered once the workspace is reopened over Remote-SSH -- every agent/skill silently disappears, with no error shown. See [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md).

Agents and prompts do not have a confirmed system-level VS Code discovery location yet (also ADR-017), so the `claude-user` target only links skills by default. A workspace that needs synced agents/prompts specifically can add a per-workspace target (`.github/agents`/`.github/prompts`) in `scripts/link-config.yaml` -- see LINKING.md's Per-Workspace Fallback section. Doing so reintroduces a small double-registration risk for anything also covered by a future system-level location, so scope it to workspaces that actually need it.

For more guidance on GitHub Copilot agents in VS Code, see the official documentation: https://code.visualstudio.com/docs/copilot/customization/custom-agents

## Using with GitHub Copilot CLI

These agents were originally written for GitHub Copilot in VS Code, but you can also use them with the GitHub Copilot CLI.

- Place your `.agent.md` files under `.github/agents/` in each repository where you run the CLI.
- Then invoke an agent with a command like:

```bash
copilot --agent planner --prompt "Create a plan for adding user authentication"
```

### Known limitation (user-level agents)

The Copilot CLI has a known upstream bug ([github/copilot-cli#452](https://github.com/github/copilot-cli/issues/452)) where **user-level agents in `~/.copilot/agents/` are not loaded**, even though they are documented. This behavior and workaround were originally reported and documented by @rjmurillo.

**Workaround:**

- Use per-repository agents under `.github/agents/` instead of relying on `~/.copilot/agents/`.
- If you prefer a single source of truth, you can keep your agents in one folder and copy or symlink them into each repo's `.github/agents/` directory.

Once the upstream bug is fixed, this section can be updated to reflect the restored user-level behavior.

## Customizing Agents

Each `.agent.md` file defines:

- A **description** and **purpose**
- Allowed **tools** (editing files, running tests, using GitHub, etc.)
- **Handoffs** to other agents
- Detailed **responsibilities** and **constraints**

To customize:

- Edit the relevant `.agent.md` file to adjust:
  - Description and Purpose
  - Allowed tools
  - Handoff targets and prompts
- Keep responsibilities and constraints intact unless you intentionally want to change your development process (e.g., Planner must not edit code, QA owns test strategy docs, etc.).

Custom agents give you:

- **Separation of concerns**: planning vs coding vs QA vs UAT vs DevOps
- **Repeatable workflow**: each phase of work is clearly owned by one agent
- **Safety and clarity**: it's explicit who may edit what, and when

---

## Skills

Agents can load **Skills**--modular, reusable instruction sets that provide specialized knowledge on-demand. Skills are stored in the `skills/` directory.

### Available Skills

> This is a representative sample, not the complete list -- see the `skills/` directory for the full, current catalog.

| Skill | Purpose |
| --- | --- |
| `architecture-patterns` | ADR templates, patterns, anti-pattern detection |
| `code-review` | Unified pre/post-implementation review criteria, severity definitions, document templates |
| `cross-repo-contract` | Multi-repo API type safety and contract coordination |
| `deep-modules` | Scores interface depth (ISC/ILC/RCK/CHEC) for any caller-facing surface; produces an A-vs-B depth verdict |
| `design-rubrics` | Router for the three design-quality rubrics; hosts the shared auditable-judgment output contract and the impactful-decision scorecard template |
| `document-lifecycle` | Unified numbering, automated closure, orphan detection |
| `functional-core` | Scorecard for function-level purity, decomposition, and complexity (PLR, FLC-max, CC-max, TCC); also covers the functional-core/imperative-shell technique for making code predictable and testable |
| `implementation-principles` | Tie-breaker guidance for implementers: DRY, YAGNI, Rule of Three, composition, SoC, POLA, Boy Scout Rule, defensive programming, and appropriate exception use. |
| `lean-design` | Ambient "minimum that works" bound at every scale (function → architecture); owns the earn-a-name rule and the auditable ladder-trace output format |
| `git-commit-message` | Craft best-practice git commit messages; supports Conventional Commits when explicitly requested |
| `execution-orchestration` | Owner-agent orchestration contract: strict gating, reject/redirect rules, and execution-state tracking |
| `plan-status-reporting` | Deterministic, evidence-based plan status reporting in strict plain-text format |
| `release-procedures` | Two-stage release workflow, semver, platform constraints |
| `security-patterns` | OWASP Top 10, language-specific vulnerabilities |
| `testing-patterns` | TDD workflow, test pyramid, coverage strategies |

### Execution State (Orchestration)

If you use execution orchestration, keep a **single authoritative execution-state file** under:

- `.agent-output/planning/` (recommended: `.agent-output/planning/<ID>-execution-state.yaml`)

Schema reference:

- `skills/execution-orchestration/references/execution-state.schema.md`

### Planner as Orchestrator

The **Planner** agent is the primary orchestrator for structured multi-agent delivery. This is the recommended workflow for any multi-step effort:

1. **Create and approve plans**: Ask the Planner to create one or more plans. Each plan goes through Critic review and user approval.
2. **Delegate execution**: Once approved, the Planner delegates tasks to specialized agents (Implementer, Code Reviewer, QA, etc.) as subagents.
3. **Coordinate concurrently**: The Planner can manage multiple approved plans simultaneously, tracking each through its own execution-state YAML file.
4. **Enforce workflow gates**: Plans progress through the defined sequence -- Critic -> Implementer -> Code Reviewer -> QA -> UAT -> DevOps -- with the Planner ensuring gate compliance.
5. **Monitor progress**: The Planner reads execution-state files to surface blockers, completion percentages, and current gate status.

Skills used: `execution-orchestration`

See the [README](README.md#-planner-as-orchestrator) for an overview.

### Skill Placement

Skills are placed in different directories depending on your VS Code version:

| Version                     | Location          |
| --------------------------- | ----------------- |
| **VS Code Stable (1.107+)** | `.claude/skills/` |
| **VS Code Insiders**        | `.github/skills/` |

> [!NOTE] These locations are changing with upcoming VS Code releases. The `.github/skills/` location is becoming the standard. Check the [VS Code Agent Skills documentation](https://code.visualstudio.com/docs/copilot/customization/agent-skills) for the latest guidance.

---

## The `.agent-output/` Directory

All agents produce their documents (plans, critiques, QA reports, implementation docs, etc.) into a `.agent-output/` directory at the root of your workspace.

The directory is a **workspace runtime artifact** -- it is NOT part of the plugin and is typically `.gitignore`'d. Add this to your `.gitignore`:

```gitignore
.agent-output/
```

---

## Document Lifecycle Setup

Agents use a **unified numbering system** to track work across the entire pipeline. All documents in a work chain share the same ID for easy traceability.

### The `.next-id` File

Create a simple counter file to enable unified numbering:

```bash
echo "1" > .agent-output/.next-id
```

**What it does:**

- When Analyst creates analysis `080`, Planner inherits `080` for the plan
- QA, UAT, Implementation all use `080` too
- Easy to follow: `analysis-080.md` -> `plan-080.md` -> `qa-080.md` -> `uat-080.md`

**If you have existing plans:** Start with your highest plan number + 1:

```bash
echo "75" > .agent-output/.next-id  # If your highest plan is 074
```

**How it works:**

1. Originating agents (Analyst, Planner) read the number, use it, then increment
2. Downstream agents (QA, UAT, Implementer) inherit the ID from their source document
3. Completed documents automatically move to `closed/` subfolders after commit

That's it! The agents handle the rest automatically.

---

## Plan Validation Scripts

Two platform-specific validators are provided to check plan templates for compliance with the structured-labeling requirements before handoff to Critic or QA.

### Windows (PowerShell Core 7+)

```powershell
pwsh .\scripts\validate-plan-template.ps1 -FilePath ".agent-output/planning/your-plan.md"
```

### Ubuntu 22.04 / Linux (Bash)

```bash
./scripts/validate-plan-template.sh -FilePath ".agent-output/planning/your-plan.md"
```

### What the Validators Check

- YAML frontmatter with required fields (ID, Origin, UUID, Status)
- Value Statement in user story format ("As a [user], I want...")
- Required sections present in correct order
- Label prefixes used correctly (REQ-_, TASK-_, GOAL-\*, etc.)
- No unresolved OPENQ-\* in CONTRACT/BACKCOMPAT sections (hard gate)
- Standard status values (not-started, in-progress, complete, blocked, deferred)

### Exit Codes

- `0` = PASS (warnings allowed)
- `1` = FAIL

### Parity

Both validators enforce the same rules. See [docs/VALIDATOR-PARITY-CHECKLIST.md](docs/VALIDATOR-PARITY-CHECKLIST.md) for details.

---

## Agent-by-Agent Guide

### Roadmap - Product Vision & Epics

**Role**: Owns product vision and outcome-focused epics, maintains the product roadmap.

**Use when**:

- Defining or revising product direction and epics
- Checking if a plan/feature still aligns with the Master Product Objective

**Example handoff prompts**:

- To Architect: "Epic requires architectural assessment and documentation before planning."
- To Planner: "Epic is ready for detailed implementation planning."

**Tips**:

- Talk about **user outcomes and business value**, not implementation details.
- Use Roadmap to sanity-check that a proposed change is actually worth building.

---

### Planner - High-Rigor Implementation Planning

**Role**: Turns roadmap epics into concrete, implementation-ready plans (WHAT/WHY, not HOW).

**Use when**:

- You have a feature/epic and need a structured plan before coding.
- Requirements or scope need to be clarified and broken into milestones.

**Example handoff prompts**:

- To Roadmap: "Validate that plan delivers epic outcomes defined in roadmap."
- To Architect: "Please review this plan to ensure it aligns with the architecture."
- To Analyst: "I've encountered technical unknowns that require deep investigation. Please analyze."
- To Critic: "Plan is complete. Please review for clarity, completeness, and architectural alignment."

**Tips**:

- Expect a **Value Statement** like: "As a [user] I want [objective] so that [value]."
- Planner writes **no code** and defines **no test cases**; it shapes the work for others.

---

### Analyst - Deep Technical/Context Research

**Role**: Investigates unknowns, APIs, performance questions, and tricky tradeoffs.

**Use when**:

- The Planner or Implementer hits technical uncertainty.
- You need API experiments, benchmarks, or comparative analysis.

**Example handoff-style prompts**:

- From Planner: "I've encountered technical unknowns that require deep investigation. Please analyze."
- From Implementer: "I've encountered technical unknowns during implementation. Please investigate."

**Tips**:

- Use Analyst to **de-risk decisions** before committing to an approach.
- Expect analysis docs that other agents then consume--not direct code changes.

---

### Architect - System & Design Decisions

**Role**: Maintains architecture, patterns, boundaries, and high-level design decisions.

**Use when**:

- A feature affects system structure, boundaries, or cross-cutting concerns.
- You need ADRs or architectural guidance for a plan.

**Example handoff prompts**:

- From Roadmap: "Epic requires architectural assessment and documentation before planning."
- From Planner: "Please review this plan to ensure it aligns with the architecture."
- From ProcessImprovement: "Mini-retro findings reveal architectural patterns that should be documented."

**Tips**:

- Use Architect to define **where** things live and how they interact, not the exact code.
- Have Architect bless or adjust big structural changes before coding.

---

### Critic - Plan Reviewer & Program Manager

**Role**: Critically reviews plans (and sometimes architecture/roadmap) before implementation.

**Use when**:

- A plan is "done" and you need a quality gate before implementation.

**Example handoff prompts**:

- To Planner: "Please revise the plan based on my critique findings."
- To Analyst: "Plan reveals research gaps or unverified assumptions. Please investigate."
- To Implementer: "Plan is sound and ready for implementation. Please begin implementation now."

**Tips**:

- Expect structured critiques focusing on **clarity, completeness, scope, and alignment**, not code style.
- Treat Critic as your pre-implementation "red team" for plans.

---

### Implementer - Coding & Tests

**Role**: Writes and modifies code, implements the approved plan, and ensures tests exist and pass.

**Use when**:

- The plan has been approved and you're ready to make code changes.
- You need to fix implementation issues uncovered by QA/UAT.

**Example handoff prompts**:

- To Analyst: "I've encountered technical unknowns during implementation. Please investigate."
- To Planner: "The plan has ambiguities or conflicts. Please clarify."
- To Code Reviewer: "Implementation is complete. Please review code quality."

**Tips**:

- Provide the **plan file path** and any existing analysis/architecture links.
- Expect the Implementer to: update code and tests, run tests, and produce an implementation doc--without editing QA/UAT docs directly.

---

### Code Reviewer - Code Quality Gate

**Role**: Reviews code quality, architecture alignment, and maintainability before QA.

**Use when**:

- Implementation is complete and ready for quality review.
- You want to catch design issues before QA invests testing time.

**Example handoff prompts**:

- To Implementer: "Code review found quality issues. Please address findings."
- To Architect: "Implementation reveals architectural issues or deviates from design."
- To QA: "Code review approved. Implementation ready for testing."

**Tips**:

- Code Reviewer can **reject on code quality alone**.
- It checks: architecture alignment, SOLID/DRY/YAGNI/KISS, TDD compliance, documentation/comments, code smells.
- Uses Architect's `system-architecture.md` as source of truth.

---

### QA - Testing Strategy & Execution

**Role**: Designs test strategy, ensures coverage, and runs tests to validate technical quality.

**Use when**:

- You need a test plan before implementation.
- Code review is complete and you want a thorough technical test pass.

**Example handoff prompts**:

- To Planner: "Testing infrastructure is missing or inadequate. Please update plan to include required test frameworks, libraries, and configuration."
- To Implementer: "Implementation has test coverage gaps or test failures. Please address."
- To UAT: "Implementation is completed and QA passed. Please review."

**Tips**:

- QA focuses on **tests, coverage, and technical risk**, not business value.
- Use QA to design/execute tests and verify they're meaningful, not just green.

---

### UAT - Product Owner / Value Validation

**Role**: Validates that implementation delivers the plan's **value statement** and user outcomes.

**Use when**:

- QA is complete and you want to confirm that the feature actually solves the intended problem.

**Example handoff prompts**:

- To Planner: "Implementation does not deliver stated value. Plan revision may be needed."
- To Implementer: "Implementation has gaps in value delivery. Please address UAT findings."
- To DevOps: "Implementation complete with release decision. Please manage release steps."

**Tips**:

- UAT reads the plan's value statement and **assesses code against that**, not just tests.
- Expect a clear decision: **APPROVED FOR RELEASE** or **NOT APPROVED**, with evidence.

---

### DevOps - Packaging & Release

**Role**: Ensures packaging/versioning is correct and executes releases (with explicit user approval).

**Use when**:

- QA and UAT are complete and you're ready to prepare/publish a release.

**Example handoff prompts**:

- To Implementer: "Packaging issues or version mismatches detected. Please fix before release."

**Tips**:

- DevOps checks versions, packaging, tags, registry publish, etc.
- It **must** ask you for a final "yes" before releasing.

---

### Security - Security Audits & Guidance

**Role**: Security specialist reviewing plans and code for vulnerabilities and compliance.

**Use when**:

- A feature touches sensitive data, auth, or external interfaces.
- You want a targeted security audit or threat model.

**Example handoff prompts**:

- To Analyst: "Security finding requires deep technical investigation."
- To Planner: "Security risks require plan revision."
- To Implementer: "Security remediation requires code changes."

**Tips**:

- Use Security early (during planning/architecture) and again after implementation.
- Expect reports with prioritized risks and concrete remediation guidance.

---

### ProcessImprovement - Evolving Agents & Workflow

**Role**: Reads `.agent-output/mini-retro/` lessons and updates the **agent instructions/workflow** (with your approval).

**Use when**:

- You have recurring mini-retro findings and want to evolve how the agents work together.

**Example handoff prompt**:

- To Planner: "Previous work iteration is complete. Ready to start something new."

**Tips**:

- This is the only agent that should routinely edit `.agent.md` files (after you approve changes).
- Use it to keep your multi-agent workflow sharp and aligned with real-world lessons.

---

## Putting It All Together

- Start with **Roadmap** for vision, then **Planner** for a concrete plan.
- Use **Architect / Analyst / Security / Critic** to refine and de-risk the plan and architecture.
- Hand off to **Implementer** for code and tests, then **QA** for technical quality and **UAT** for value.
- The **Planner** authors the mandatory mini-retro before handing off to **DevOps**; **ProcessImprovement** consumes recurring lessons for future workflow updates.
