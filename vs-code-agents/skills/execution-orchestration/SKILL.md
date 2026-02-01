---
name: execution-orchestration
description: Role-agnostic execution orchestration contract for delegating work to subagents with strict gating (`COMPLETE` vs `HARD BLOCK`), reject/redirect enforcement, and an execution-state artifact.
license: MIT
metadata:
  author: groupzer0
  version: "1.0"
---

# Execution Orchestration

Use this skill when you are the **owner agent** responsible for coordinating multiple subagents and enforcing workflow gates.

This skill is **role-agnostic**. It MUST be parameterized at runtime and MUST NOT bake in role-specific paths, agent names, or repo-specific assumptions beyond the contract below.

---

## Required Runtime Parameters (MANDATORY)

You MUST supply all of the following. If any are missing, you MUST HARD BLOCK.

- `OWNER_ROLE`: The owning role running orchestration (e.g., `Planner`, `DevOps`).
- `PHASE_NAME`: The current phase label (e.g., `EXECUTION-ORCHESTRATION`).
- `MISSION`: One sentence describing the goal of the execution.
- `DEFINITION_OF_DONE`: A numbered list of completion criteria.
- `WORKFLOW_ORDER`: The required workflow gates (e.g., `Planner -> Critic -> Implementer -> Code Reviewer -> QA -> UAT -> DevOps`).
- `EXECUTION_STATE_PATH`: Path to the single authoritative execution-state file.
- `ARTIFACT_ROOTS`: Allowed output roots for artifacts (e.g., `agent-output/planning/`, `agent-output/qa/`).
- `SUBAGENTS`: Ordered list of participating subagents (names must match available agents).
- `OWNER_CONSTRAINTS`: Explicit constraints the owner must follow during orchestration.

### Parameter Validation (Hard Switch)

Before you orchestrate anything, you MUST:
1. Validate all Required Runtime Parameters are present.
2. Validate the workflow gate that precedes execution is satisfied for this mission.
3. If the gate is not satisfied, you MUST REJECT & REDIRECT (do not proceed).

---

## Hard Switch: When Orchestration Is Allowed

Execution orchestration is a distinct mode. You MUST NOT enter it until the upstream approval gate(s) are satisfied.

Examples:
- If the owner is `Planner`, orchestration MUST NOT begin until the plan has passed `Critic` approval.
- If the owner is `DevOps`, orchestration MUST NOT begin until `UAT` has approved.

If you are asked to orchestrate without the required upstream approval, you MUST REJECT & REDIRECT.

---

## Execution-State Artifact (Single Source of Truth)

You MUST maintain one authoritative state file at `EXECUTION_STATE_PATH`.

Rules:
- Treat it as the single source of truth for progress, blockers, artifacts, and next handoffs.
- Update it after every subagent return and after every meaningful decision.
- The state file MUST follow the schema in:
  - `vs-code-agents/skills/execution-orchestration/references/execution-state.schema.md`

---

## Delegation Contract (MANDATORY)

Every subagent request you issue MUST include:

- **Objective**: One clear objective.
- **Scope**: In-scope and out-of-scope items.
- **Inputs**: Links/paths the subagent must read.
- **Constraints**: Tooling constraints, file edit constraints, policy constraints.
- **Deliverables**: Concrete outputs and exact file paths.
- **Acceptance Criteria**: What “done” means.
- **Return Format**: Subagent MUST respond in either `COMPLETE` or `HARD BLOCK` format.
- **State Update Instructions**: What state fields to update or what evidence to return so the owner can update state.

If a subagent response does not match the Return Format, you MUST REJECT & REDIRECT.

---

## Response Gating (Owner Responsibilities)

You MUST treat every subagent interaction as gated.

### Accepted outcomes
- `COMPLETE`: The subagent claims all deliverables are met and provides evidence/paths.
- `HARD BLOCK`: The subagent cannot proceed and provides a concrete blocking reason and required inputs.

### Rejection rules (Reject & Redirect)
Reject any response that:
- does not clearly declare `COMPLETE` or `HARD BLOCK`
- declares completion without satisfying acceptance criteria
- invents files/paths that do not exist
- violates constraints (e.g., edits forbidden directories)
- proposes bypassing workflow gates

---

## Standard Redirect Template (VERBATIM)

Use this template when rejecting a subagent response or redirecting them to re-run with corrected constraints.

```markdown
REDIRECT

- Target: [AgentName]
- Reason: [Why the previous output was rejected / what was missing]
- Required Fix: [Exactly what to do next]
- Inputs: [Paths/links to read]
- Constraints: [Must-follow constraints]
- Deliverables: [Expected outputs with exact paths]
- Return Format: Respond with either:
  - COMPLETE: [evidence + links/paths]
  - HARD BLOCK: [blocking reason + required inputs]
```

---

## Standard Hard Block Format (VERBATIM)

Use this format whenever you cannot proceed.

```markdown
HARD BLOCK

- Blocked On: [What is missing / what prevents progress]
- Impact: [What cannot be completed]
- Required From User: [Exact decision/info/access needed]
- Required From Other Agents: [If applicable]
- Unblocked By: [Concrete next action to unblock]
- Notes: [Optional]
```

---

## Owner Output Contract

When you report status to the user, you MUST:
- State the current gate and whether it is satisfied.
- State the next handoff (which agent, what prompt summary).
- Reference `EXECUTION_STATE_PATH` as authoritative.
- If blocked, use the Standard Hard Block Format.
