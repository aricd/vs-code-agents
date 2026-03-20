# Changelog

All notable changes to this repository will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-03-20

### Added

- **Plugin packaging**: Repository restructured as a VS Code Agent Plugin. Install via `Chat: Install Plugin From Source` with the Git URL — all 13 agents and 19 skills are immediately available.
- **`plugin.json` manifest**: Plugin metadata at repo root (name: "Multi-Disciplinary Team Agents Plugin", version 1.0.0).
- **`agents/` directory**: Plugin-discoverable copies of all 13 `.agent.md` files at repo root.
- **`skills/` directory**: Plugin-discoverable copies of all 19 skill directories and reference docs at repo root.
- **`hooks/hooks.json`**: Plugin hooks for plan validation (PostToolUse) and active orchestration context injection (UserPromptSubmit).
- **`hooks/user-prompt-submit.sh`**: Bash hook that reads `.agent-output/planning/*-execution-state.yaml` and injects `[MDT Active Orchestrations]` context into every agent prompt.
- **`hooks/user-prompt-submit.ps1`**: PowerShell equivalent of the UserPromptSubmit hook with identical output per CONTRACT-003.
- **`scripts/sync-plugin.sh`**: Script to sync plugin directories (`agents/`, `skills/`) from canonical source (`vs-code-agents/`).
- **Migration documentation**: README guidance for detecting and removing workspace-level agent duplicates after plugin installation.
- **Planner as Orchestrator**: README and USING-AGENTS documentation explaining Planner's role as the primary multi-plan orchestrator.

### Changed

- **Renamed `agent-output/` to `.agent-output/`**: All agent, skill, script, and documentation references updated. The dot-prefix aligns with conventions (`.github/`, `.vscode/`) and simplifies `.gitignore` management. Users with existing `agent-output/` directories should rename: `mv agent-output .agent-output`.
- **README header**: Updated from "VS Code Agents" to "Multi-Disciplinary Team Agents Plugin" with new intro paragraph.
- **Repository structure**: Updated to show plugin layout (`plugin.json`, `agents/`, `skills/`, `hooks/`, `scripts/`).

## 2026-02-04

### Added

- **git-commit-message skill**: Craft best-practice git commit messages with subject/body formatting rules, imperative mood, and 50/72 character guidelines. Supports Conventional Commits (with Type selection guidance and breaking change handling) when explicitly requested. DevOps loads this skill when crafting commit messages.

- **plan-status-reporting skill**: Evidence-based plan status reporting in strict plain-text format. Includes output template, evidence hierarchy rules, and worked example. Planner agent loads this skill when asked for current plan status.

## 2026-02-03

### Added

- **functional-programming skill**: Integrated into the skills library with MIT license and metadata. Guides pure functions, immutability, composition, and side-effect isolation; referenced in Implementer agent and Available Skills table.
- **implementation-principles skill**: Tie-breaker guidance for implementers covering DRY (with AHA nuance), YAGNI, Rule of Three, composition over inheritance, separation of concerns, POLA, Boy Scout Rule, defensive programming, and appropriate exception use.

### Changed

- Agent definitions no longer proactively ask for application/release version identifiers, recommend version bumps, or mandate version consistency management.

## 2026-02-01

### Added

- **execution-orchestration skill**: Role-agnostic orchestration contract with strict gating (`COMPLETE` vs `HARD BLOCK`), reject/redirect rules, and execution-state guidance.
- **planner-execution-orchestration skill**: Planner-specific preset/template for using orchestration without assuming skill-to-skill imports.
- **Execution-state schema reference**: YAML-first, JSON-compatible schema doc for the authoritative state file.

### Changed

- **Planner guidance**: Added orchestration-mode guidance (post-Critic approval only) and standardized the authoritative execution-state file location under `.agent-output/planning/`.
- **Docs**: Updated entry points to mention the new skills and the state file convention.

## 2026-01-29

### Removed

- Persistent-memory integration references across agent definitions (tool IDs, instructions, and the dedicated persistence guidance section).
- Persistent-memory skill and the accompanying example reference doc.

## 2026-01-18

### Added

- **Code Reviewer agent**: New quality gate between Implementer and QA. Reviews code for architecture alignment, SOLID/DRY/YAGNI/KISS, TDD compliance, documentation/comments, security, and code smells. Can reject on quality alone.
- **code-review-standards skill**: Extracted review checklist, severity definitions, and document templates for reuse.

### Changed

- **UAT agent simplified**: Now a quick, document-based value validation (read-only tools only). Relies on Implementation, Code Review, and QA docs rather than inspecting code directly.
- **Implementer handoff**: Now goes to Code Reviewer instead of QA directly.
- **Workflow updated**: `Implementer → Code Reviewer → QA → UAT → DevOps`

## 2026-01-15

### Added

- Uncertainty-aware issue analysis guidance across Analyst, Architect, and QA agents.
- Analyst hard pivot trigger to avoid forced root-cause narratives when evidence is missing.
- Normal vs debug telemetry criteria, plus a minimum viable incident telemetry baseline.
- Reusable uncertainty review template: `vs-code-agents/reference/uncertainty-review-template.md`.

### Changed

- QA guidance now prefers validating telemetry via structured fields/events over brittle log string matching.
