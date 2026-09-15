---
ID: 4
Origin: 4
UUID: d3f7a92e
Status: Committed

# Approval Tracking
User_Approved: true
User_Approved_Date: 2026-03-24
Critic_Approved: true
Critic_Approved_Date: 2026-03-24
UAT_Approved: true
UAT_Approved_Date: 2026-03-24
DevOps_Committed: true
DevOps_Committed_Date: 2026-09-15
---

# Plan 004 — Remove Handoffs & Elevate Planner to Default Orchestrator

| Date | Change | Summary |
|------|--------|---------|
| 2026-03-24 | Initial draft | Plan created from user request |
| 2026-03-24 | Rev 1 — Critic findings | Address M-001 (split TASK-014), M-002 (standardize grep), M-003 (add delegation contract reminder), L-001 (normalize section headings) |
| 2026-03-24 | Rev 2 — QA complete | QA executed TEST-001..TEST-005 and additional checks; QA status set to QA Complete |
| 2026-09-15 | Document closed | Status: Committed (DevOps closure; changes committed in ab38bc6) |

---

## Value Statement and Business Objective

As a user of the agent framework, I want all manual handoff UI elements removed from agents and the Planner updated to act as a true orchestrator that delegates work to subagents when asked to "execute until completion," so that I no longer need to manually switch between agents and the workflow runs end-to-end when I grant permission.

---

## Objective

Eliminate the legacy `handoffs:` YAML blocks from all 13 agent frontmatter definitions, update the Planner agent to treat orchestration as its **default post-approval mode** (not optional), and reframe all inter-agent references in body text from "handoff to X" / "switch to X" to subagent delegation language — so the framework operates as a coordinated pipeline rather than a manual relay.

---

## Requirements & Constraints

### Requirements (REQ-*)

- REQ-001: All `handoffs:` YAML blocks MUST be removed from every agent frontmatter (13 agents total: analyst, architect, code-reviewer, critic, devops, implementer, pi, planner, qa, retrospective, roadmap, security, uat)
- REQ-002: The Planner agent MUST treat execution orchestration as the **default mode** after Critic approval when the user indicates they want execution to proceed — not as an optional capability
- REQ-003: The Planner MUST recognize user phrases such as "execute until completion," "proceed," "go ahead," "run it," or similar as implicit permission to orchestrate the full workflow chain via subagent delegation
- REQ-004: The Planner MUST NOT tell the user to "switch to" another agent or suggest manual agent handoffs — it MUST delegate directly via subagent invocation
- REQ-005: All agents' body text MUST be updated to replace "handoff to X" / "hand off to X" / "switch to X" language with subagent-delegation or orchestrator-reporting language appropriate to each agent's role
- REQ-006: The canonical source for all agent files is `vs-code-agents/`; after edits, `scripts/sync-plugin.sh` MUST be run to sync to `agents/`

### Security Requirements (SEC-*)

- SEC-001: No security implications — changes are limited to agent instruction text

### Constraints (CON-*)

- CON-001: Edits MUST target `vs-code-agents/*.agent.md` only (canonical source); `agents/` is populated by sync script
- CON-002: The `agent` tool capability MUST already be listed in each agent's `tools:` array for subagent invocation to work — verify this and add where missing
- CON-003: Changes MUST NOT alter agent `model:`, `description:`, `target:`, or `argument-hint:` fields
- CON-004: The Planner MUST still require Critic approval before entering orchestration — this gate is NOT being removed
- CON-005: All other agents (non-Planner) MUST NOT attempt to self-orchestrate; they report completion/blocks back to the orchestrating Planner

### Guidelines (GUD-*)

- GUD-001: Body text should use "delegate to X" or "invoke X as subagent" where previously "handoff to X" was used
- GUD-002: Agents invoked as subagents should describe their output as "report back to orchestrator" rather than "handoff to next agent"
- GUD-003: Keep the Planner's orchestration language concise — the existing execution-orchestration and planner-execution-orchestration skills already define the behavioral contract

---

## Contracts (CONTRACT-*)

None — no new public interfaces or boundaries are being created. This plan modifies agent instruction text only.

---

## Backwards Compatibility (BACKCOMPAT-*)

- BACKCOMPAT-001: Not applicable — the `handoffs:` YAML blocks are a VS Code UI convenience feature that generates suggestion buttons. Removing them removes the buttons but does not break any programmatic interface. Users who previously clicked handoff buttons will now rely on the Planner's orchestration or direct agent invocation. No migration or shim is needed.

---

## Testing Scope (TEST-SCOPE-*)

- TEST-SCOPE-001: Manual verification required — validate that all `handoffs:` blocks are removed from frontmatter, the Planner orchestration language is updated, and body text no longer contains legacy handoff language
- TEST-SCOPE-002: Verify `scripts/sync-plugin.sh` runs successfully after edits and both directories are in sync

---

## Implementation Plan

### Phase 1 — Remove Handoff YAML Blocks from All Agents

GOAL-001: Eliminate all `handoffs:` YAML frontmatter blocks from all 13 agent files

| Task | Description | Status | Owner |
|------|-------------|--------|-------|
| TASK-001 | Remove the entire `handoffs:` block (including all child entries) from `vs-code-agents/analyst.agent.md` frontmatter | not-started | implementer |
| TASK-002 | Remove the entire `handoffs:` block from `vs-code-agents/architect.agent.md` frontmatter | not-started | implementer |
| TASK-003 | Remove the entire `handoffs:` block from `vs-code-agents/code-reviewer.agent.md` frontmatter | not-started | implementer |
| TASK-004 | Remove the entire `handoffs:` block from `vs-code-agents/critic.agent.md` frontmatter | not-started | implementer |
| TASK-005 | Remove the entire `handoffs:` block from `vs-code-agents/devops.agent.md` frontmatter | not-started | implementer |
| TASK-006 | Remove the entire `handoffs:` block from `vs-code-agents/implementer.agent.md` frontmatter | not-started | implementer |
| TASK-007 | Remove the entire `handoffs:` block from `vs-code-agents/pi.agent.md` frontmatter | not-started | implementer |
| TASK-008 | Remove the entire `handoffs:` block from `vs-code-agents/planner.agent.md` frontmatter | not-started | implementer |
| TASK-009 | Remove the entire `handoffs:` block from `vs-code-agents/qa.agent.md` frontmatter | not-started | implementer |
| TASK-010 | Remove the entire `handoffs:` block from `vs-code-agents/retrospective.agent.md` frontmatter | not-started | implementer |
| TASK-011 | Remove the entire `handoffs:` block from `vs-code-agents/roadmap.agent.md` frontmatter | not-started | implementer |
| TASK-012 | Remove the entire `handoffs:` block from `vs-code-agents/security.agent.md` frontmatter | not-started | implementer |
| TASK-013 | Remove the entire `handoffs:` block from `vs-code-agents/uat.agent.md` frontmatter | not-started | implementer |
| TASK-014 | Audit each agent's `tools:` array — produce a list of agents missing the `'agent'` capability | not-started | implementer |
| TASK-036 | For every agent identified in TASK-014 as missing `'agent'`, add `'agent'` to that agent's `tools:` array | not-started | implementer |

### Phase 2 — Elevate Planner Orchestration to Default Mode

GOAL-002: Update Planner agent instructions so orchestration is the default post-approval behavior, not optional

| Task | Description | Status | Owner |
|------|-------------|--------|-------|
| TASK-015 | In `vs-code-agents/planner.agent.md`, update the "Execution Orchestration" section header and opening paragraph: change "may optionally run" to position orchestration as the **default mode** when the user grants permission to proceed | not-started | implementer |
| TASK-016 | Add a new "Orchestration Triggers" subsection to the Planner that defines user phrases ("execute until completion", "proceed", "go ahead", "run it", etc.) as implicit permission to orchestrate | not-started | implementer |
| TASK-017 | Update the Planner's "Agent Workflow" section: replace "Handoff to critic" / "Handoff to implementer" language with "Delegate to Critic/Implementer via subagent invocation" | not-started | implementer |
| TASK-018 | Add explicit instruction to the Planner that it MUST NOT tell the user to "switch to" another agent — it must delegate directly or explain why it cannot | not-started | implementer |
| TASK-019 | Update the Planner's post-critic approval flow: after user approves the plan, if user indicates execution should proceed, Planner enters orchestration mode automatically | not-started | implementer |
| TASK-037 | Add an explicit reminder in the Planner's orchestration instructions that every subagent delegation MUST follow the delegation contract from the `execution-orchestration` skill (Objective, Scope, Inputs, Constraints, Deliverables, Acceptance Criteria, Return Format) | not-started | implementer |

### Phase 3 — Update Body Text Across All Non-Planner Agents

GOAL-003: Replace all legacy handoff/switch language in agent body text with subagent-delegation or orchestrator-reporting language

| Task | Description | Status | Owner |
|------|-------------|--------|-------|
| TASK-020 | Update `vs-code-agents/analyst.agent.md` body text: replace "Handoff to Planner" with "Report findings back to orchestrator" or equivalent delegation language | not-started | implementer |
| TASK-021 | Update `vs-code-agents/architect.agent.md` body text: replace handoff references with delegation language | not-started | implementer |
| TASK-022 | Update `vs-code-agents/code-reviewer.agent.md` body text: replace "handoff to Implementer" / "handoff to QA" with delegation language | not-started | implementer |
| TASK-023 | Update `vs-code-agents/critic.agent.md` body text: replace "Handoff to implementer" with delegation language | not-started | implementer |
| TASK-024 | Update `vs-code-agents/devops.agent.md` body text: replace "Hand off to Retrospective" / "Hand off to Roadmap" and "Acknowledge handoff" with delegation language | not-started | implementer |
| TASK-025 | Update `vs-code-agents/implementer.agent.md` body text: replace "handoff" references with "report completion to orchestrator" | not-started | implementer |
| TASK-026 | Update `vs-code-agents/pi.agent.md` body text: replace handoff analysis language with delegation-pattern analysis language | not-started | implementer |
| TASK-027 | Update `vs-code-agents/qa.agent.md` body text: replace "Handoff back to Implementer" with delegation language | not-started | implementer |
| TASK-028 | Update `vs-code-agents/retrospective.agent.md` body text: update handoff analysis metrics to use delegation terminology | not-started | implementer |
| TASK-029 | Update `vs-code-agents/roadmap.agent.md` body text: replace any handoff references with delegation language | not-started | implementer |
| TASK-030 | Update `vs-code-agents/security.agent.md` body text: replace handoff references with delegation language | not-started | implementer |
| TASK-031 | Update `vs-code-agents/uat.agent.md` body text: replace "handoff to retrospective" and related language with delegation language | not-started | implementer |

### Phase 4 — Sync and Verify

GOAL-004: Sync canonical files to plugin directory and verify consistency

| Task | Description | Status | Owner |
|------|-------------|--------|-------|
| TASK-032 | Run `scripts/sync-plugin.sh` to copy `vs-code-agents/` to `agents/` and `skills/` | not-started | implementer |
| TASK-033 | Verify all 13 files in `agents/` are identical to their `vs-code-agents/` counterparts (diff check) | not-started | implementer |
| TASK-034 | Verify no file in either directory contains a `handoffs:` YAML block | not-started | implementer |
| TASK-035 | Verify no agent body text contains legacy handoff language using: `grep -riE "(switch to|hand\s*off\s*to)" vs-code-agents/*.agent.md` — retrospective analysis/metrics references are acceptable only if reworded to delegation terminology | not-started | implementer |

---

## Alternatives (ALT-*)

- ALT-001: **Keep handoff blocks but hide them** — Rejected. The handoff YAML blocks serve no purpose once the Planner orchestrates via subagents. Keeping dead configuration is confusing and could mislead future contributors.
- ALT-002: **Make orchestration opt-in via a flag** — Rejected. The user's explicit request is to make orchestration the default. An opt-in flag adds complexity without value. The Critic gate already prevents premature execution.

---

## Dependencies (DEP-*)

- DEP-001: `scripts/sync-plugin.sh` — existing sync script must work correctly (already verified)
- DEP-002: `execution-orchestration` skill — existing skill defines the orchestration contract (no changes needed to the skill itself)
- DEP-003: `planner-execution-orchestration` skill — existing Planner preset for orchestration parameters (no changes needed)
- DEP-004: VS Code `agent` tool capability — must be available in the runtime for subagent invocation to work

---

## Files (FILE-*)

- FILE-001: `vs-code-agents/analyst.agent.md` — remove handoffs block, update body text
- FILE-002: `vs-code-agents/architect.agent.md` — remove handoffs block, update body text
- FILE-003: `vs-code-agents/code-reviewer.agent.md` — remove handoffs block, update body text
- FILE-004: `vs-code-agents/critic.agent.md` — remove handoffs block, update body text
- FILE-005: `vs-code-agents/devops.agent.md` — remove handoffs block, update body text
- FILE-006: `vs-code-agents/implementer.agent.md` — remove handoffs block, update body text
- FILE-007: `vs-code-agents/pi.agent.md` — remove handoffs block, update body text
- FILE-008: `vs-code-agents/planner.agent.md` — remove handoffs block, update orchestration + workflow sections
- FILE-009: `vs-code-agents/qa.agent.md` — remove handoffs block, update body text
- FILE-010: `vs-code-agents/retrospective.agent.md` — remove handoffs block, update body text
- FILE-011: `vs-code-agents/roadmap.agent.md` — remove handoffs block, update body text
- FILE-012: `vs-code-agents/security.agent.md` — remove handoffs block, update body text
- FILE-013: `vs-code-agents/uat.agent.md` — remove handoffs block, update body text
- FILE-014: `agents/*.agent.md` — synced copies of all 13 files (via sync script)

---

## Tests (TEST-*)

- TEST-001: After Phase 1, run `grep -r "^handoffs:" vs-code-agents/*.agent.md` — expect zero matches
- TEST-002: After Phase 2, verify Planner body text contains "default mode" or equivalent orchestration-default language and does NOT contain "may optionally run" in the orchestration section
- TEST-003: After Phase 3, run `grep -riE "(switch to|hand\s*off\s*to)" vs-code-agents/*.agent.md` — expect zero matches (all legacy handoff language including retrospective metrics should be updated to delegation terminology)
- TEST-004: After Phase 4, run `diff` between each `agents/X.agent.md` and `vs-code-agents/X.agent.md` — expect all identical
- TEST-005: Verify all 13 agents' `tools:` arrays include the `'agent'` capability — run `grep -c "'agent'" vs-code-agents/*.agent.md` and expect count of 13

---

## Risks (RISK-*)

- RISK-001: **Agents lose context in subagent mode** — Subagent invocations are stateless; the orchestrating Planner must pass sufficient context in each delegation prompt. Mitigation: The execution-orchestration skill already mandates a delegation contract with Objective, Scope, Inputs, Constraints, Deliverables, and Acceptance Criteria.
- RISK-002: **Removing handoffs breaks user muscle memory** — Users accustomed to clicking handoff buttons lose that UI affordance. Mitigation: The Planner now orchestrates automatically, which is strictly better UX. Users can still invoke any agent directly by name in chat.
- RISK-003: **Body text grep misses a handoff reference** — Some handoff language may be phrased differently than expected patterns. Mitigation: TASK-035 performs a comprehensive search; Code Review should also verify.

### Failure Modes (FM-*)

- FM-001: Sync script fails after edits — Impact: `agents/` directory is stale, users on the plugin path get old agent definitions. Mitigated by: TASK-032, TASK-033, TEST-004
- FM-002: An agent missing the `'agent'` tool capability cannot be invoked as subagent — Impact: Planner orchestration silently fails for that agent. Mitigated by: TASK-014, TEST-005
- FM-003: Planner still produces "switch to X" language due to incomplete instruction update — Impact: User sees the exact behavior this plan is meant to eliminate. Mitigated by: TASK-017, TASK-018, TEST-003

---

## Assumptions (ASSUMPTION-*)

- ASSUMPTION-001: The VS Code `agent` tool is the mechanism for subagent invocation and is available at runtime
- ASSUMPTION-002: Removing `handoffs:` YAML blocks does not affect any other VS Code Copilot functionality beyond removing the suggested handoff buttons
- ASSUMPTION-003: All 13 agent files in `vs-code-agents/` are the canonical source and are currently in sync with `agents/` (verified: all identical as of 2026-03-20)
- ASSUMPTION-004: The existing execution-orchestration and planner-execution-orchestration skills do not need modification — only the Planner's agent file instructions need updating

---

## Open Questions (OPENQ-*)

- OPENQ-001 [RESOLVED]: Should the Planner self-handoff entries (Current Plan Status, Consolidate Plan, Create Git Commit Message) also be removed? → **Yes, remove all handoffs blocks entirely.** The Planner can still perform these actions via its own instructions without YAML handoff buttons.
- OPENQ-002 [RESOLVED]: Should the retrospective agent's handoff analysis metrics (Total Handoffs, Handoff Chain, Handoff Quality Assessment) be renamed to delegation terminology? → **Yes, update to delegation terminology** as part of TASK-028.

---

## Approval & Sign-off

| Role | Status | Date | Notes |
|------|--------|------|-------|
| User | ✅ Approved | 2026-03-24 | User approved with instruction: implement through DevOps commit, no push |
| Critic | ✅ Approved | 2026-03-24 | All findings (M-001, M-002, M-003, L-001) resolved in Rev 1 |

---

## Traceability Map

| Requirement | Tasks | Tests | Risk | Failure Mode |
|-------------|-------|-------|------|--------------|
| REQ-001 (Remove handoffs YAML) | TASK-001 through TASK-013 | TEST-001, TEST-004 | RISK-002 | FM-001 |
| REQ-002 (Default orchestration) | TASK-015, TASK-019, TASK-037 | TEST-002 | RISK-001 | FM-003 |
| REQ-003 (Recognize trigger phrases) | TASK-016 | TEST-002 | — | FM-003 |
| REQ-004 (No "switch to" language) | TASK-017, TASK-018 | TEST-003 | — | FM-003 |
| REQ-005 (Update body text) | TASK-020 through TASK-031 | TEST-003 | RISK-003 | — |
| REQ-006 (Sync canonical source) | TASK-032, TASK-033 | TEST-004 | — | FM-001 |
| CON-002 (Agent tool capability) | TASK-014, TASK-036 | TEST-005 | — | FM-002 |
