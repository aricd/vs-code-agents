---
name: planner-execution-orchestration
description: Planner-specific execution orchestration preset (copy/paste template). Provides recommended runtime parameters and workflow gating, without assuming skill-to-skill imports are supported.
license: MIT
metadata:
  author: aricd
  version: "1.0"
---

# Planner Execution Orchestration (Preset)

This is a **Planner-specific preset/template** for using the base `execution-orchestration` skill.

Important:
- This preset MUST NOT assume skill-to-skill imports are supported.
- Treat this as **copy/paste guidance for humans**.

---

## When to Use

Use after:
- A plan exists under `agent-output/planning/`, AND
- The plan has passed the **Critic** gate (do not bypass Critic).

---

## How to Invoke (No Import Assumptions)

1. Load the base skill: `execution-orchestration`.
2. Provide the runtime parameters below (copy/paste and fill placeholders).

If your environment does not support structured parameter passing, paste the parameters block into the chat and proceed.

---

## Runtime Parameters (Copy/Paste)

```yaml
OWNER_ROLE: Planner
PHASE_NAME: EXECUTION-ORCHESTRATION
MISSION: "<one sentence mission>"

# IMPORTANT: keep a single authoritative state file for this work chain.
# Prefer: agent-output/planning/<ID>-execution-state.yaml
EXECUTION_STATE_PATH: "agent-output/planning/<ID>-execution-state.yaml"

# Provide DoD as a numbered list.
DEFINITION_OF_DONE:
  - "<DoD item 1>"
  - "<DoD item 2>"

# Repo workflow order (do not bypass Critic).
WORKFLOW_ORDER: "Planner -> Critic -> Implementer -> Code Reviewer -> QA -> UAT -> DevOps"

# Output roots allowed for artifacts.
ARTIFACT_ROOTS:
  - "agent-output/planning/"
  - "agent-output/critiques/"
  - "agent-output/code-review/"
  - "agent-output/qa/"
  - "agent-output/uat/"
  - "agent-output/releases/"

# Subagents used during execution.
SUBAGENTS:
  - Critic
  - Implementer
  - Code Reviewer
  - QA
  - UAT
  - DevOps

# Planner constraints during orchestration.
OWNER_CONSTRAINTS:
  - "Planner MUST NOT edit source code, config files, or tests. Planning artifacts only."
  - "Planner MUST NOT bypass Critic approval gate."
  - "Planner MUST keep execution-state updated after each handoff."
```

---

## Notes

- The authoritative behavior contract (gating, redirects, hard-block format) lives in the `execution-orchestration` skill.
- This preset exists only to reduce setup friction and keep Planner behavior consistent.
