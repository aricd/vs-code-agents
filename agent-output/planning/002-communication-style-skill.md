---
ID: 2
Origin: 2
UUID: b7c2a91f
Status: Superseded
---

# Plan: Communication Style Skill (Eliminate “Continue-Button” Cliffhangers)

Superseded By: `agent-output/planning/003-unified-labeled-planning-and-approval.md`

Target Release: TBD (requires roadmap/release tracker)
Epic Alignment: Agent UX / human-in-the-loop control / reduced narration friction

## Value Statement and Business Objective
As a user collaborating with VS Code agents, I want agents to avoid “continue-button” cliffhangers (pausing work just to say what they’ll do next) and instead only pause for my guidance when decisions are ambiguous or high-impact, so that agents work autonomously without training me to keep them moving while still deferring to me on consequential choices.

Secondarily, I want agents (especially Planner) to never silently assume scope/constraints that were not explicitly stated, so that planning stays aligned with my intent even when ambiguity exists.

## Objective
Create a reusable skill that standardizes agent communication across this repo to:
- Eliminate “continue-button” cliffhangers where the agent stops and waits after announcing future steps.
- Explicitly allow lightweight within-task narration when the agent continues working (no user action required).
- Introduce a deterministic “Guidance Gate” that forces a pause + questions only when ambiguity or high-impact tradeoffs exist.
- Introduce a deterministic “Assumption Disclosure” protocol: if any assumption is made (scope, constraints, terminology, success criteria), it must be explicitly labeled as an assumption and either confirmed via a guidance question (when impactful) or recorded as a non-blocking default.
- Preserve concise, present-tense progress updates only when they improve user comprehension.
- Ensure “strict-format outputs” (e.g., `plan-status-reporting`) emit the final required format without preambles.

## Non-Goals / Out of Scope
- Changing underlying model behavior outside what agent definitions + skills can reasonably constrain.
- Modifying VS Code/Copilot product behavior.
- Adding QA test cases or automation (QA agent owns test strategy).

## Key Definitions
- **Continue-button cliffhanger**: the agent pauses work to announce what it will do next (often future-tense) in a way that implicitly awaits user input, despite no guidance being required.
- **Silent assumption**: the agent treats an inferred interpretation of scope/constraints as explicit without labeling it and without giving the user a chance to correct it.

## Decisions (Recorded)
- Skill scope: **Always-on** across all agents in this repo.
- Status reporting: **No preamble**. When producing a strict-format status report, output **only** the final required report format.
- “Next I’ll…” scope: Only disallow when used as a stop-and-wait cliffhanger (treating the user as a continue button). Do not try to eliminate harmless within-task narration where the agent continues working.

## Assumptions
- The largest source of “Next I’ll…” phrasing is generic assistant behavior, not explicit repo text.
- Skills + agent Response Style sections can materially reduce this behavior.
- Some scenarios still benefit from short progress updates, but they should be present-tense and non-directive.

## OPEN QUESTION (Blocking for finalization)
1. OPEN QUESTION [RESOLVED]: Should the new skill be “always-on” (referenced by every agent) or selectively activated? → **Always-on**.
2. OPEN QUESTION [RESOLVED]: For status-reporting invocations, is the requirement “report only” or “one short present-tense line allowed”? → **Report only** (no preamble).
3. Target Release: what is the repo’s release/versioning convention for plans? No `agent-output/roadmap/product-roadmap.md` exists yet in this workspace.

## Plan

### 1) Establish release tracking (minimal) so Target Release is not ad hoc
**Owner**: roadmap (Roadmap agent)

**Objective**: Create the minimal roadmap/release tracker artifact needed to assign `Target Release: vX.Y.Z` consistently.

**Work**:
- Create: `agent-output/roadmap/product-roadmap.md` with an “Active Release Tracker” section.
- Assign this plan (002) to a release version and/or delivery cycle label.

**Acceptance Criteria**:
- Roadmap file exists and includes a release→plan mapping.
- This plan’s Target Release is updated from `TBD` to a concrete value.

### 2) Create a new skill: no-silent-assumptions (software planning)
**Owner**: implementer

**Objective**: Provide a single authoritative skill that prevents silent scope/contract assumptions during software planning.

**Work**:
_Authoritative content is user-provided and should be copied verbatim (with only Markdown fence correctness fixes if needed)._\
Create folder-based skill:
- Path: `vs-code-agents/skills/no-silent-assumptions-software-planning/SKILL.md`
- Skill frontmatter `name`: `no-silent-assumptions.software-planning`

The skill must encode:
- No silent assumptions (core rule)
- Hard-gate ambiguity domains: contracts + backwards compatibility
- Proposed Contract concept + labeling requirements
- Soft-default domains (test scope, performance posture, alternatives)
- Batch question UX with defaults (including “defaults” shorthand)
- Required plan section ordering + prefixes
- Assumption hygiene + OPENQ handling + forbidden anti-patterns

**Acceptance Criteria**:
- Skill exists at `vs-code-agents/skills/no-silent-assumptions-software-planning/SKILL.md` with correct frontmatter.
- Markdown renders correctly (no broken/unbalanced code fences).
- Planner can load and follow it without adding new terminology.

### 2b) (Optional) Create a separate communication micro-skill: continue-button cliffhangers
**Owner**: implementer

**Objective**: Address the separate concern of “continue-button cliffhanger” updates without constraining harmless within-task narration.

**Work**:
- If needed after adoption of the no-silent-assumptions skill, create a small skill focused only on:
  - disallowing stop-and-wait cliffhangers
  - allowing within-task narration when the agent continues working

**Acceptance Criteria**:
- Micro-skill is short, unambiguous, and does not overlap the software-planning scope above.

### 3) Integrate skill into agent definitions
**Owner**: implementer

**Objective**: Ensure behavior is actually used by agents (skills don’t help if nothing references them).

**Work**:
- Update agent definitions to reference and comply with the new skill, at minimum:
  - `vs-code-agents/planner.agent.md`
  - `vs-code-agents/analyst.agent.md`
  - `vs-code-agents/implementer.agent.md`
  - `vs-code-agents/qa.agent.md`
  - `vs-code-agents/critic.agent.md`
  - (Optional but recommended) all other agents for consistency.
- Where agents already have “Response Style” sections, reconcile them so they do not encourage future-step narration.

**Acceptance Criteria**:
- Agent docs explicitly instruct “no Next I’ll” and define when to ask guidance questions.
- Guidance Gate is consistently described across agents.

### 4) Align strict-format skills with “Strict Output Mode”
**Owner**: implementer

**Objective**: Prevent the common pattern of preambles before strict-format reports.

**Work**:
- Update: `vs-code-agents/skills/plan-status-reporting/SKILL.md`
  - Add a short “Strict Output Mode” instruction: do not print interim narration; emit only the final raw report.
  - Ensure the Worked Example contains no “I’m going to…” preamble.

**Acceptance Criteria**:
- Status-reporting runs produce only the strict plain-text report (plus any required final section already mandated by the skill).

### 5) Documentation and changelog
**Owner**: implementer

**Objective**: Make the new skill discoverable and explain intent.

**Work**:
- Update: `USING-AGENTS.md` (Skills list + brief description of communication-style skill).
- Update: `AGENTS-DEEP-DIVE.md` (optional: add a short “Communication Contract” subsection under customization/troubleshooting).
- Update: `CHANGELOG.md` with an entry describing the new skill + integration.

**Acceptance Criteria**:
- New skill is discoverable from at least one entry point doc.
- Changelog records the change.

## Validation (Non-QA)
- Manual smoke-check: invoke Planner with a status-reporting request and confirm it emits only the strict report (no narration).
- Manual smoke-check: prompt an agent with an ambiguous request; confirm it pauses with guidance questions instead of assuming.

## Risks and Mitigations
- Risk: Some models still narrate future steps despite instruction → Mitigation: reinforce bans in both skill and agent Response Style; keep examples explicit.
- Risk: Over-triggering the Guidance Gate makes agents too hesitant → Mitigation: keep rubric narrow and anchored to “non-local consequences” and genuine ambiguity.

## Traceability Map
| Milestone | Expected Files/Globs |
|----------:|----------------------|
| 1 | `agent-output/roadmap/product-roadmap.md` |
| 2 | `vs-code-agents/skills/no-silent-assumptions-software-planning/SKILL.md` |
| 3 | `vs-code-agents/*.agent.md` |
| 4 | `vs-code-agents/skills/plan-status-reporting/SKILL.md` |
| 5 | `USING-AGENTS.md`, `AGENTS-DEEP-DIVE.md`, `CHANGELOG.md` |

## Changelog
| Date | Agent | Change | Notes |
|---|---|---|---|
| 2026-02-08 | Planner | Document closed | Status: Superseded (consolidated into Plan 003) |
