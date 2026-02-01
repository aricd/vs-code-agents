# Changelog

All notable changes to this repository will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-02-01

### Added

- **execution-orchestration skill**: Role-agnostic orchestration contract with strict gating (`COMPLETE` vs `HARD BLOCK`), reject/redirect rules, and execution-state guidance.
- **planner-execution-orchestration skill**: Planner-specific preset/template for using orchestration without assuming skill-to-skill imports.
- **Execution-state schema reference**: YAML-first, JSON-compatible schema doc for the authoritative state file.

### Changed

- **Planner guidance**: Added orchestration-mode guidance (post-Critic approval only) and standardized the authoritative execution-state file location under `agent-output/planning/`.
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
