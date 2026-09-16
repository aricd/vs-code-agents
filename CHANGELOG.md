# Changelog

All notable changes to this repository will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-09-16 (follow-up)

### Added

- **`TARGET-*` — the criterion's target is now part of the ledger** (`literal-intent-fidelity` skill): a criterion always applies to *something* (a working tree, remote, branch, directory, or document set), and when that target is inherited rather than stated, every downstream step can be flawless while the whole result lands somewhere the user did not mean. New Step 0 in the Criterion Ledger, a "The Target Is Part of the Criterion" section covering the common sources of inherited targets (session/tooling binding, fork vs. abandoned remote, canonical vs. generated copies, branch drift, a prior task's target), and a graduated rule: quote a user-stated target, **disclose** an inherited one in a single line before the first edit, and **ask** when more than one plausible target exists.
- **`TARGET-*` prefix registered** in the `structured-labeling` skill's Scope & Criterion Fidelity table, and added to the ledger template's field rules and both ledger forms.
- **Second case study** in `references/worked-example-scope-substitution.md`: a target-substitution incident in which the work itself was entirely correct but was applied to a clone of an abandoned remote rather than the user's working repository, undetectable from the work product because the work product was correct. Includes the canonical-vs-generated-copy near-miss from the same task.

### Changed

- **`planner.agent.md`**: Process step 5b now leads with `TARGET-001` before `CRIT-001`.
- **`architect.agent.md`**: notes that in projects with canonical sources plus generated/mirrored copies, which copy is edited is a target decision — edits to a generated copy are reverted by the next sync.
- **`[MDT Literal-Criterion Check]` hook block** (bash + PowerShell): adds a line requiring the target to be stated before the first edit.
- **`README.md`**: Literal Intent Fidelity feature section describes the target rule.

## 2026-09-16

### Added

- **`literal-intent-fidelity` skill**: New skill addressing **criterion substitution** — the failure where a user states an explicit, testable criterion and the agent silently applies a narrower or semantically adjacent test, then reports the result as though it answered the original request. Defines the Criterion Ledger procedure (verbatim `CRIT-*` capture, mechanical per-candidate testing, cited evidence for every verdict), the valid exclusion taxonomy, the separation of scope decisions from cost decisions, and the pushback protocol (one correct objection invalidates the test, so the full pass is re-run). Companion to `no-silent-assumptions-software-planning`: that skill covers what the user did NOT say, this one covers what the user DID say.
- **`literal-intent-fidelity/references/criterion-ledger-template.md`**: Copy-paste ledger template with field rules and a minimal inline form for small decisions.
- **`literal-intent-fidelity/references/worked-example-scope-substitution.md`**: End-to-end case study of a real substitution incident and its correction.
- **Scope & Criterion Fidelity label prefixes** (`structured-labeling` skill): `CRIT-*`, `PROXY-*`, `EXCL-*`, `COST-*`, `DRIFT-*`. These are artifact-local (used inside a Criterion Ledger), not plan-template sections, and are not checked by the plan validators.
- **`[MDT Literal-Criterion Check]` prompt injection**: `hooks/user-prompt-submit.sh` and `.ps1` now read the UserPromptSubmit payload and inject a literal-criterion reminder when the prompt states a testable scope criterion or disputes how stated intent was interpreted. This makes the guardrail fire without relying on the agent choosing to load the skill.

### Changed

- **CONTRACT-003 (UserPromptSubmit hook output)**: `contextInjection` may now carry two blocks — `[MDT Literal-Criterion Check]` (first, when triggered) and `[MDT Active Orchestrations]`. Either block may be absent; output remains `{}` when neither applies or on any error. Orchestration-block content and formatting are unchanged.
- **Agent wiring for `literal-intent-fidelity`**:
  - `planner.agent.md`: new skills-header directive plus Process step 5b (stated-criterion fidelity), the counterpart to the existing step 5 ambiguity detection.
  - `critic.agent.md`: Critic is named as the gate that catches criterion substitution in plan scope.
  - `analyst.agent.md`: applies when investigation scope comes from a stated criterion; candidate population must be enumerated from the repository, not a prior document.
  - `architect.agent.md`: architectural categories ("transport layer", "domain core", "plumbing") may describe an exclusion but never justify one.
  - `implementer.agent.md`: change sets defined by a criterion ("every caller of X") must be enumerated mechanically and cited.
  - `qa.agent.md`: coverage reported against a narrower population than the one requested is a false pass.
- **`no-silent-assumptions-software-planning` skill**: Added companion-skill section distinguishing unstated scope (ask) from stated-and-narrowed scope (quote and test literally).
- **Skill count 19 → 20**: Updated in `plugin.json`, `README.md`, `USING-AGENTS.md`, `scripts/install-probe.sh`, and `scripts/install-probe.ps1`; skill catalogs in `USING-AGENTS.md` and `AGENTS-DEEP-DIVE.md` updated; new "Literal Intent Fidelity" feature section in `README.md`.

## 2026-03-24 (Plan 003)

### Added

- **FM-* (Failure Mode) label prefix**: New required label for identifying how requirements or components can fail, with impact and mitigating references. FM-* is a required subsection within the Risks section (or "None identified").
- **Traceability Map — new requirement-centric format**: Required columns are now `Requirement | Tasks | Tests | Risk | Failure Mode`. Every REQ-* must appear as a row, and all cross-references must resolve to existing labels in the plan body.
- **Deep cross-reference validation in validators**: Both `validate-plan-template.sh` and `.ps1` now check that all TASK-*/TEST-*/RISK-*/FM-* references in the Traceability Map exist elsewhere in the plan. Missing references produce errors; missing risk analysis produces warnings.
- **Backwards compatibility for old-format plans**: Plans using the old Phase→Files traceability map format (Plans 001, 002) are automatically detected by column headers and exempted from new validation checks.

### Changed

- **Traceability Map changed from recommended to required**: Section 16 in the plan template is now mandatory (structured-labeling skill updated).
- **`plan-status-reporting` skill**: Removed Phase→File traceability map guidance. File verification now uses the FILE-* section instead.
- **`planner.agent.md`**: Updated section ordering to show Traceability Map as required, added FM-* guidance in Risks section documentation, specified required Traceability Map columns.
- **`critic.agent.md`**: Added Traceability Map validation to template checks — verifies correct columns, all REQs present, cross-references resolve, and FM-* subsection exists.
- **Validation checklist in structured-labeling skill**: Added four new items for Traceability Map compliance.

### Fixed

- **`validate-plan-template.sh`**: Fixed section extraction regex to match `## Traceability Map` specifically rather than any heading containing "Traceability Map" (prevented false positive matches on plan titles).
- **`validate-plan-template.ps1`**: Same fix applied to PowerShell version.

## 2026-03-24

### Added

- **`scripts/smoke-test-plugin.sh`**: Bash smoke test script validating plugin structure (plugin.json, agent frontmatter, skill frontmatter, hooks.json, no stale references, no duplicate agent names). Supports `--canonical` flag to validate source directory and `--sync-check` flag to detect drift between canonical and plugin copies.
- **`scripts/smoke-test-plugin.ps1`**: PowerShell equivalent with identical checks and output format.
- **`scripts/install-probe.sh`**: Level 2 install probe that creates a temporary VS Code user-data directory with plugin settings for manual verification. Supports `--launch` flag to auto-launch VS Code.
- **`scripts/install-probe.ps1`**: PowerShell equivalent of the install probe.
- **Plugin Testing documentation**: New "Plugin Testing" section in README.md covering smoke tests, install probe, Level 3 gap, and Chat Diagnostics reference.

### Fixed

- **`vs-code-agents/skills/analysis-methodology/SKILL.md`**: Added missing YAML frontmatter (`name`, `description`) — skill was not discoverable by VS Code.
- **`vs-code-agents/skills/cross-repo-contract/SKILL.md`**: Added missing YAML frontmatter — skill was not discoverable by VS Code.
- **`vs-code-agents/skills/no-silent-assumptions-software-planning/SKILL.md`**: Changed `name: no-silent-assumptions.software-planning` to `name: no-silent-assumptions-software-planning` (hyphens) to match directory name.
- **`vs-code-agents/skills/executive-summary/SKILL.md`**: Removed code fence wrapping (` ```skill `) so frontmatter is at document boundary where VS Code expects it.
- **`vs-code-agents/skills/structured-labeling/SKILL.md`**: Removed code fence wrapping — same fix as executive-summary.

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
