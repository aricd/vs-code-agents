---
ID: 1
Origin: 1
UUID: 6f4a1d2c
Status: Superseded
---

# Plan: Execution Orchestration Skill + Planner Integration

Superseded By: `agent-output/planning/003-unified-labeled-planning-and-approval.md`

Target Release: Unassigned (per user request; not tied to roadmap)
Epic Alignment: Agent system consistency / execution governance

## Value Statement and Business Objective
As an owner agent (starting with Planner), I want a reusable, parameterized execution-orchestration skill and a deterministic execution-state schema, so that subagent-driven work is consistently delegated, strictly gated (`COMPLETE` vs `HARD BLOCK`), and auditable across roles.

## Objective
Deliver a repo-convention-compliant skill (folder-based `SKILL.md`) that:
- Is role-agnostic via required runtime parameters (OWNER_ROLE, MISSION, etc.)
- Enforces strict response gating and “reject & redirect” rules
- Provides an execution-state schema that owners can persist as a YAML/JSON artifact
- Integrates into the Planner agent so Planner can hard-switch into orchestration mode after plan approval

## Non-Goals / Out of Scope
- No roadmap/product-roadmap integration in this plan.
- No changes to business epics or release mapping.
- No feature work outside agent-orchestration contract + minimal Planner integration.

## Repo Conventions and Constraints
- Skills MUST be folder-based: `vs-code-agents/skills/<skill-name>/SKILL.md`.
- Planner (this role) does not implement; Implementer will apply file edits.
- Keep changes minimal (KISS) and avoid duplicating content already present in Planner instructions unless necessary.

## Assumptions
- Agent runtime supports loading a skill by name, but do NOT assume skills can load/import other skills.
- The Planner agent definition can be updated to reference the new skill and wrapper (as a human copy/paste preset) without breaking other agents.

## Plan

### 1) Add the role-agnostic execution-orchestration skill
**Owner**: Implementer

**Objective**: Add a reusable orchestration contract skill that can be invoked by any owner agent.

**Work**:
- Create folder: `vs-code-agents/skills/execution-orchestration/`
- Add: `vs-code-agents/skills/execution-orchestration/SKILL.md`
  - Include the contract sections from the user-provided draft (parameterized placeholders + required Runtime Parameters block)
  - Explicitly define:
    - Phase Transition (hard switch)
    - Delegation Contract requirements
    - Reject & Redirect rules
    - Response Gating rules (`COMPLETE` vs `HARD BLOCK`)
    - Standard Redirect Template (verbatim)
    - Standard Hard Block Format (verbatim)
  - Keep the skill role-agnostic: no Planner-specific paths or agent names baked in.

**Acceptance Criteria**:
- Skill exists at `vs-code-agents/skills/execution-orchestration/SKILL.md`
- Skill clearly states required runtime parameters and behavior when missing
- Skill is usable verbatim by non-Planner owners (DevOps, etc.)

### 2) Add a Planner wrapper skill with repo-default parameters
**Owner**: Implementer

**Objective**: Reduce cognitive load by providing a Planner-specific wrapper that pre-fills defaults.

**Work**:
- Create folder: `vs-code-agents/skills/planner-execution-orchestration/`
- Add: `vs-code-agents/skills/planner-execution-orchestration/SKILL.md`
  - States: This is a Planner preset/template; do NOT assume skill-to-skill import is supported
  - Provides a standard Runtime Parameters template with Planner defaults:
    - OWNER_ROLE: Planner
    - PHASE_NAME: EXECUTION-ORCHESTRATION
    - ARTIFACT_ROOTS: include `agent-output/planning/`, `agent-output/analysis/`, `agent-output/qa/`, and any other existing domains used by your workflow (see step 4)
    - SUBAGENTS: Analyst, Implementer, Code Reviewer, QA, Critic (consistent with current repo workflow)
    - CONSTRAINTS: Planner must not edit source/config/tests; planning artifacts only
    - HANDOFF_RULES: reflect repo workflow order (Implementer → Code Reviewer → QA → UAT → DevOps) while keeping Planner’s orchestration responsibilities clear
    - BLOCKER_POLICY: define the hard-block categories relevant to this system

**Acceptance Criteria**:
- Wrapper skill exists at `vs-code-agents/skills/planner-execution-orchestration/SKILL.md`
- Wrapper references the base skill and provides a ready-to-copy runtime parameter block
- Wrapper does not duplicate the entire base skill

### 3) Add an execution-state schema (deterministic progress tracking)
**Owner**: Implementer

**Objective**: Provide a simple schema so the owner agent can track execution across subagent returns.

**Work**:
- Add reference doc under the skill:
  - Preferred: `vs-code-agents/skills/execution-orchestration/references/execution-state.schema.md`
- Define:
  - A YAML-first schema (JSON-compatible)
  - Required fields: `id`, `owner_role`, `phase_name`, `mission`, `definition_of_done`, `subagents`, `artifacts`, `status`, `blockers`, `updated_at`
  - Allowed statuses for DoD items: `not_started | in_progress | done | blocked`
  - A minimal example instance (ILLUSTRATIVE ONLY)
- Decide on a storage location convention for state artifacts:
- Decide on a storage location convention for state artifacts:
  - Default suggestion: `agent-output/planning/<ID>-execution-state.yaml`

**Acceptance Criteria**:
- Schema doc exists and is unambiguous enough to be followed consistently
- Schema supports linking to produced artifacts (plan, QA report, critique)

### 4) Integrate with Planner agent definition
**Owner**: Implementer

**Objective**: Make Planner explicitly aware of and aligned with the new orchestration skill.

**Work**:
- Update: `vs-code-agents/planner.agent.md`
  - Add guidance in the workflow/process section:
    - After plan approval, Planner must “Load skill: planner-execution-orchestration” (or the base skill with filled parameters)
    - Planner must maintain a single authoritative execution state file using the schema
  - Align the Planner workflow text with current repo process (notably the presence of Code Reviewer between Implementer and QA)
  - If the Planner file already contains a hard-coded “Execution Orchestration Mode” block, either:
    - Replace it with a reference to the skill (preferred to avoid duplication), or
    - Keep a short summary + reference the skill as authoritative source

**Acceptance Criteria**:
- Planner doc references the wrapper skill and execution-state schema
- Planner orchestration behavior matches the base skill contract (gating + redirects)
- Planner’s documented handoffs align with current repo workflow

### 5) Update documentation entry points (minimal)
**Owner**: Implementer

**Objective**: Make the new skill discoverable.

**Work**:
- Update one or more of:
  - `README.md`
  - `USING-AGENTS.md`
  - `AGENTS-DEEP-DIVE.md`
- Add a short section “Execution Orchestration” describing:
  - when to use
  - how to invoke via wrapper
  - where state artifacts live

**Acceptance Criteria**:
- At least one doc mentions the new skill and wrapper
- Links/paths use repo conventions

### 6) Version management (repo-level)
**Owner**: DevOps (or Implementer if you prefer)

**Objective**: Record the change.

**Work**:
- Add a CHANGELOG entry describing:
  - new execution-orchestration skill
  - wrapper skill
  - planner integration
  - execution-state schema reference

**Acceptance Criteria**:
- `CHANGELOG.md` updated with date + summary

## Validation (Non-QA)
- Run a quick doc/path sanity check:
  - Skills exist in folder-based convention
  - Planner references correct paths
  - No circular/duplicated “authoritative” instruction sources (skill should be the source of truth)

## Risks and Mitigations
- Risk: Divergence between Planner instructions and skill contract → Mitigation: make the skill authoritative; keep Planner doc as a pointer.
- Risk: Too many parameters increases friction → Mitigation: wrapper skill with defaults + copy/paste block.
- Risk: Workflow drift (Code Reviewer, UAT ordering) → Mitigation: align wrapper + Planner to current workflow documented in CHANGELOG.

## Handoff Notes
- Implementer should keep the new skills small and focused (DRY/KISS).
- Do not embed implementation code; keep it as behavioral contract.
- Ensure any examples are labeled ILLUSTRATIVE ONLY.

## Changelog
| Date | Agent | Change | Notes |
|---|---|---|---|
| 2026-02-08 | Planner | Document closed | Status: Superseded (consolidated into Plan 003) |
