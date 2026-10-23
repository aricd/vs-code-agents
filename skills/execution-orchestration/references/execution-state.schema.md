# Execution State Schema (YAML-first, JSON-compatible)

This document defines the **execution-state artifact** used by the `execution-orchestration` skill.

## Purpose

The execution-state file is the **single authoritative** progress tracker for an orchestrated work chain. It captures:

- the mission and definition of done
- workflow gates and current status
- produced artifacts (with paths)
- blockers and unblock steps

## Storage Convention

To align with the document lifecycle and Planner constraints, store the state file under:

- `.agent-output/planning/`

Recommended filename pattern:

- `.agent-output/planning/<ID>-execution-state.yaml`

(One work chain ID -> one authoritative execution-state file.)

---

## Schema

The schema is **YAML-first** and MUST remain **JSON-compatible** (i.e., only JSON-compatible types: object, array, string, number, boolean, null).

### Required Top-Level Fields

- `plan_id` (string)
  - Work chain identifier: the human-facing plan/document ID. Spelled `plan_id`, always a quoted string, zero-padded to three digits (e.g. `"027"`). This is the canonical spelling, type and padding for **newly authored** execution-state files. Existing files using the legacy key `id` (bare, unpadded, or differently padded) remain valid -- normalizing them retroactively is out of scope for this declaration.
  - `id` (string) -- DEPRECATED alias, accepted for backward compatibility on existing files only. New execution-state files MUST use `plan_id`.
- `uuid` (string, 8 hex characters)
  - The chain UUID, inherited verbatim from the originating plan's frontmatter `UUID:` field. This is the **authoritative join key** for the chain: every artifact of a work chain -- markdown or YAML -- carries this same value. `plan_id`/`id` is a human-facing label with no uniqueness guarantee (a single numeric prefix can span more than one chain); never join chain membership on it. See `scripts/check-chain-closure.{ps1,sh}`.
- `owner_role` (string)
- `phase_name` (string)
- `mission` (string)
- `definition_of_done` (array of objects)
- `subagents` (array of objects)
- `artifacts` (array of objects)
- `status` (object)
- `blockers` (array of objects)
- `created` (string)
  - ISO-8601 timestamp with an **explicit offset** or `Z` (e.g. `2026-09-10T07:49:30-06:00`).
  - When this execution-state was created. **Immutable** — it records authorship, not modification; that is what `updated_at` is for. It survives renames.
  - **Obtain it by running a clock, never by composing the string:** `Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"` (PowerShell) / `date +%Y-%m-%dT%H:%M:%S%:z` (bash).
  - Add `created_derived: true` when the value was reconstructed rather than observed. This is required whenever `created` lands on a whole hour, which is the shape of an invented timestamp.
  - Owning definition: `skills/document-lifecycle/SKILL.md` § Document Header Format. The rule lives there; this entry restates where it lands in this schema.
- `updated_at` (string)
  - ISO-8601 timestamp (e.g., `2026-02-01T12:34:56Z`). Changes on every write, unlike `created`.

### Field Definitions

#### `definition_of_done[]`

Each DoD entry is an object:

- `id` (string) -- stable identifier (e.g., `"dod-1"`)
- `text` (string)
- `status` (string) -- one of: `not_started`, `in_progress`, `done`, `blocked`
- `owner` (string, optional) -- responsible role/agent
- `evidence` (array of strings, optional) -- paths/links to artifacts

#### `subagents[]`

Each subagent entry:

- `name` (string)
- `role` (string, optional)
- `last_handoff` (string, optional) -- short summary
- `status` (string, optional) -- `idle`, `requested`, `complete`, `blocked`

#### `artifacts[]`

Each artifact entry:

- `type` (string) -- e.g., `plan`, `critique`, `implementation`, `code-review`, `qa`, `uat`, `release`, `deployment`, `other`
- `path` (string) -- repo-relative file path
- `status` (string, optional) -- artifact-specific status (e.g., `Active`, `Approved`, `Committed`)
- `description` (string, optional)

#### `phases[]` (Optional)

Each phase entry tracks a GOAL-\* from the plan:

- `goal_id` (string) -- phase identifier (e.g., `"GOAL-001"`)
- `name` (string) -- human-readable phase name
- `status` (string) -- one of: `not-started`, `in-progress`, `complete`, `blocked`

#### `tasks[]` (Optional)

Each task entry tracks a TASK-\* from the plan:

- `task_id` (string) -- task identifier (e.g., `"TASK-001"`)
- `phase` (string) -- the parent phase (e.g., `"GOAL-001"`)
- `description` (string) -- brief task description
- `status` (string) -- one of: `not-started`, `in-progress`, `complete`, `blocked`, `deferred`
- `owner` (string, optional) -- responsible role/agent
- `completed_date` (string, optional) -- ISO-8601 date (e.g., `"2026-02-08"`)

#### `analyst_budget` (Optional)

Tracks the Analyst delegation budget for the execution phase. Present once the orchestrator initializes execution-state. See the [Analyst Delegation Budget](#analyst-delegation-budget-authoritative-owner) section of the `execution-orchestration` skill for the formula and decrement/report rules.

- `allocated` (int) -- total allocations computed at execution-state initialization (per the budget formula in the skill section linked above)
- `consumed` (int) -- number of Analyst subagent invocations used so far
- `remaining` (int) -- `allocated - consumed`; reported in each handoff / state update
- `note` (string, optional) -- free-text record of top-up events or budget changes

This field is **additive and optional** (backward-compatible). Existing state files without it are valid; new orchestrations SHOULD include it.

#### `run_target` (Optional)

Records the end state the user approved the run toward. See §Run-to-Target Contract in the `execution-orchestration` skill.

- `text` (string) -- the user's instruction, verbatim (e.g. `"orchestrate these plans until closed and fully committed locally"`)
- `target_state` (string) -- the state every item must reach (e.g. `"Committed"`)
- `items` (array of strings) -- the plans or phases the run covers, in execution order
- `pre_approved_deferrals` (array of strings, optional) -- scope the user has approved for deferral without stopping
- `ambiguity_resolutions` (array of objects, optional) -- one entry per ladder use:
  - `question` (string)
  - `analyst_report` (string, optional) -- path
  - `critic_report` (string, optional) -- path
  - `outcome` (string) -- `resolved`, `reframed`, `safe-default`, or `confirmed-block`

This field is **additive and optional** (backward-compatible). Orchestrations started from a run-to-target instruction SHOULD include it.

#### `status`

- `workflow_order` (string) -- human-readable gate order
- `current_gate` (string) -- e.g., `"Critic"`
- `gate_state` (string) -- one of: `not_started`, `in_progress`, `passed`, `failed`, `blocked`
- `overall_state` (string) -- one of: `in_progress`, `complete`, `blocked`

#### `blockers[]`

Each blocker entry:

- `id` (string)
- `blocked_on` (string)
- `impact` (string)
- `required_from_user` (string, optional)
- `required_from_other_agents` (array of strings, optional)
- `unblocked_by` (string)
- `stop_reason` (string, optional) -- `hard-block` or `unapproved-deferral`; required for any blocker that stopped an approved run
- `ladder_evidence` (array of strings, optional) -- Analyst and Critic report paths, when the blocker arose from uncertainty
- `deferral_needed` (string, optional) -- for `unapproved-deferral`: the scope that would have to be deferred
- `status` (string) -- `open` or `resolved`

---

## Illustrative Example (ILLUSTRATIVE ONLY)

```yaml
plan_id: "001"
uuid: "3a9c14e7"
owner_role: "Planner"
phase_name: "EXECUTION-ORCHESTRATION"
mission: "Integrate execution orchestration skills and Planner guidance."

definition_of_done:
  - id: "dod-1"
    text: "execution-orchestration skill added"
    status: "in_progress"
    evidence: []

subagents:
  - name: "Critic"
    status: "complete"
    last_handoff: "Reviewed plan; must-fix corrections applied."

artifacts:
  - type: "plan"
    path: ".agent-output/planning/001-execution-orchestration-skill-integration.md"

status:
  workflow_order: "Planner -> Critic -> Implementer -> Code Reviewer -> QA -> UAT -> DevOps"
  current_gate: "Implementer"
  gate_state: "in_progress"
  overall_state: "in_progress"

blockers: []
updated_at: "2026-02-01T00:00:00Z"
```

---

## Extended Example with Phases and Tasks

When tracking structured plans with GOAL-_/TASK-_ labels, use the optional `phases` and `tasks` arrays:

```yaml
plan_id: "003"
uuid: "5d21f8b6"
owner_role: "Planner"
phase_name: "UNIFIED-LABELING"
mission: "Deliver repo-wide labeled templates and approval workflow."

definition_of_done:
  - id: "dod-1"
    text: "structured-labeling skill created"
    status: "done"
    evidence:
      - "skills/structured-labeling/SKILL.md"
  - id: "dod-2"
    text: "executive-summary absorbed into structured-labeling and planner"
    status: "done"
    evidence:
      - "skills/structured-labeling/SKILL.md"
      - "agents/planner.agent.md"

phases:
  - goal_id: "GOAL-001"
    name: "Establish repo-wide labeling + templates"
    status: "complete"
  - goal_id: "GOAL-002"
    name: "No-silent-assumptions integration"
    status: "complete"
  - goal_id: "GOAL-003"
    name: "Executive Summary skill + approval workflow"
    status: "complete"
  - goal_id: "GOAL-004"
    name: "Validation gates and exception handling"
    status: "complete"
  - goal_id: "GOAL-005"
    name: "Execution state enhancements"
    status: "in-progress"

tasks:
  - task_id: "TASK-001"
    phase: "GOAL-001"
    description: "Create structured-labeling skill"
    status: "complete"
    owner: "implementer"
    completed_date: "2026-02-08"
  - task_id: "TASK-013"
    phase: "GOAL-005"
    description: "Extend execution-state schema for phases/tasks"
    status: "in-progress"
    owner: "implementer"
  - task_id: "TASK-014"
    phase: "GOAL-005"
    description: "Align plan-status-reporting with approval tracking"
    status: "not-started"
    owner: "implementer"

subagents:
  - name: "Critic"
    status: "complete"
    last_handoff: "Reviewed plan; approved with no blockers."
  - name: "Implementer"
    status: "requested"
    last_handoff: "Phase 5 in progress."

artifacts:
  - type: "plan"
    path: ".agent-output/planning/003-unified-labeled-planning-and-approval.md"
    status: "Active"
  - type: "critique"
    path: ".agent-output/critiques/003-unified-labeled-planning-and-approval-critique.md"
    status: "Approved"
  - type: "implementation"
    path: ".agent-output/implementation/003-unified-labeled-planning-and-approval.md"
    status: "In Progress"

status:
  workflow_order: "Planner -> Critic -> Implementer -> Code Reviewer -> QA -> UAT -> DevOps"
  current_gate: "Implementer"
  gate_state: "in_progress"
  overall_state: "in_progress"

blockers: []
updated_at: "2026-02-08T12:00:00Z"
```
