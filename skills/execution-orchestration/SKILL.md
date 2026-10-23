---
name: execution-orchestration
description: Role-agnostic execution orchestration contract for delegating work to subagents with strict gating (`COMPLETE` vs `HARD BLOCK`), reject/redirect enforcement, an execution-state artifact, and a run-to-target contract (no unsolicited stops; only hard-block or unapproved-deferral stop reasons; ambiguity resolved via Analyst then Critic frame challenge).
metadata:
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
- `ARTIFACT_ROOTS`: Allowed output roots for artifacts (e.g., `.agent-output/planning/`, `.agent-output/qa/`).
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
  - `skills/execution-orchestration/references/execution-state.schema.md`
- **Chain identity (MANDATORY on creation)**: set `plan_id` and `uuid` from the originating
  plan's own frontmatter (`ID:`/`UUID:`) verbatim at creation time -- never invented, never
  left absent. The field definitions are owned by the schema referenced above; this is an
  authoring obligation citing it, not a second definition.

---

## Delegation Contract (MANDATORY)

Every subagent request you issue MUST include:

- **Objective**: One clear objective.
- **Scope**: In-scope and out-of-scope items.
- **Inputs**: Links/paths the subagent must read.
- **Constraints**: Tooling constraints, file edit constraints, policy constraints.
- **Deliverables**: Concrete outputs and exact file paths.
- **Acceptance Criteria**: What "done" means.
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
- claims a **Demonstrated** acceptance criterion is satisfied by reasoning, a passing build, or static evidence alone (see below)

### Demonstrated vs Asserted acceptance criteria

Acceptance criteria come in two kinds, **Asserted** and **Demonstrated**. The definition -- the
kind table, the default-classification rule, the hard rule, and the two disqualifying evidence
shapes for a mis-routed or co-derived demonstration -- is owned exclusively by
`structured-labeling`'s Acceptance-Criterion Kind section; this skill does not restate it.

**Owner disposition:** if a subagent reports `COMPLETE` on a Demonstrated criterion without
in-environment runtime evidence satisfying that hard rule, you MUST REJECT & REDIRECT.

### Disposition when a Demonstrated criterion fails at runtime (root-cause-first default)

When a `HARD BLOCK` arises because a Demonstrated criterion failed at runtime (crash, dropped data, back-pressure, timeout, or any required-but-unobserved behavior):

1. **Default disposition is root-cause-first**: re-delegate the same task to fix the defect and produce the demonstration before any dependent task proceeds.
2. **Do not treat "defer the demonstration into a later task" as a co-equal option** for a de-risking criterion; deferring requires explicit user opt-in plus a recorded risk that a downstream task inherits unverified runtime behavior.
3. **Any claim offered as grounds for not re-verifying is a claim that must be proven, not asserted.** An "environmental / external / library" root cause is the canonical instance; infeasibility claims ("not reproducible locally", "impossible") and blocker claims ("blocked on X", as a narrative excuse rather than a `blockers[]` entry) are others. Accept any of them only with **differential evidence**: a minimal known-good path that runs in the same environment, plus a hypothesis explaining why the failing artifact differs (lifecycle, teardown ordering, resource sharing, recreation). Absent that evidence, treat the failure as a defect in the artifact under test and stay root-cause-first. **Routing:** this rule governs re-verification of a runtime demonstration only -- verifying a planning-time premise a plan rests on before any code runs remains owned by `no-silent-assumptions-software-planning`, out of this rule's scope. See `structured-labeling`'s Demonstrated-Evidence Disposition Rule for the chain-wide label this instance now shares, and `code-review`'s `DEMOGATE-*` gates for the review-time check.

   **Worked examples:**
   - *Legitimate*: a demonstration times out only when run inside CI. The Implementer reproduces the same timeout locally by throttling network latency to CI's measured round-trip time and cites that reproduction alongside the environmental claim -- the claim carries differential evidence and is accepted.
   - *Illegitimate*: a demonstration fails once, and the failure is disposed of with 'environmental flake, re-run passed' -- no known-good path is captured, no hypothesis is offered for why the artifact behaves differently run-to-run, and the failure is never revisited. The claim has no adjacent differential evidence and MUST be rejected; the failure stays open as a defect in the artifact under test.

---

## Work-Order Contract

A **work-order** is a YAML artifact the orchestrating owner creates before any delegation that has two or more tasks OR at least one Demonstrated acceptance criterion. The executor reads, executes against, and updates the file. The owner re-validates it before accepting a COMPLETE return.

Schema reference: `skills/execution-orchestration/references/work-order.schema.yaml`
Gate scripts: `scripts/run-work-order-gates.ps1` / `scripts/run-work-order-gates.sh`

### When to create a work-order

Create a work-order when the delegation meets **either** condition:

- The delegation covers **two or more tasks**, OR
- The delegation contains **at least one Demonstrated** acceptance criterion (a criterion that requires runtime evidence rather than static reasoning).

Single-task, assertion-only delegations are exempt; the prior honor-system COMPLETE procedure applies.

### Gate-resolution contract

Before running the gate script, resolve it in this order, and stop at the first hit:

1. **Workspace `scripts/`** -- `scripts/run-work-order-gates.ps1` (or `.sh`) inside the current workspace root.
2. **Linked `scripts/`** -- the same file reached through this repo's distribution mechanism (`link_setup.py` / `LINKING.md`), when the current workspace is a consumer with `link_scripts: true`.
3. **`blockers[]` HARD BLOCK** -- if neither location resolves, the gate is **unresolvable**. This is itself a blocking condition, not a reason to skip validation: write a `blockers[]` entry with `status: open` naming the unresolved gate, and do not declare COMPLETE. There is no third, manual-substitution step -- a missing gate script is escalated, never worked around.

### Owner pre-delegation steps

**Re-diff rule:** When the plan has changed in-session (a revision, a `DECISION-*` resolution, a
Critic-requested amendment) since the owner last read it, the owner MUST re-read the plan's
current ratified section before authoring the delegation checklist below -- never proceed from a
summary, a memory of an earlier revision, or a prior work-order's phrasing. This is the
discipline this class of orchestration session has had to apply repeatedly against a plan's own
in-session decisions; skipping it authors a checklist against stale text.

Before issuing the delegation, the orchestrating owner:

1. Creates the file at `.agent-output/handoffs/<plan-id>-<phase-label>.yaml` using the schema at `skills/execution-orchestration/references/work-order.schema.yaml`.
2. Populates `meta` (plan ID, chain `uuid` inherited verbatim from the plan's frontmatter
   `UUID:` field -- field definition owned by the schema, cited here not restated -- phase,
   target role, `status: pending`).
3. Populates `scope.allowed_files` (every path the executor may touch) and `scope.blocked_files` (paths that must not be touched — always include `.agent-output/.next-id` and any security-sensitive files).
4. Populates `environment` with non-obvious runtime facts (canonical test invocation, venv bootstrap) or sets it to null when defaults are obvious.
5. Adds one `checklist` entry per task:
   - Sets `kind: Asserted` or `kind: Demonstrated`.
   - For Demonstrated items: provides a non-null `entry_point` (the wired call-chain that produces evidence) and `disconfirm` (the rule that proves the check fails when the wiring is removed).
6. Adds at minimum three gates:
   - A `file_scope_check` gate with `must_match_only: true` (checks git diff against `scope.allowed_files`).
   - A `label_audit` gate with `paths` targeting the files the executor will create or modify (detects leaked planning-label patterns).
   - A collision gate whose command runs `scripts/check-plan-scope-collision.{ps1,sh}` against the plan document this phase touches -- a read-only check for a shared registry-file entry with another non-closed plan, run as a genuine mechanical gate rather than left to an author's memory.
   - When the phase touches Python source under a measured tree, additionally a `metric_budget` gate whose command runs `crest_metrics.py --diff-base <ref> --budget .agent-output/metrics/<plan-id>-metric-budget.yaml` (schema and reviewer verification protocol: `skills/functional-core/tools/references/metric-budget-template.md`; list the budget file in `scope.blocked_files`).
   - When the phase closes a work chain, additionally a `[Demonstrated]` checklist item whose `entry_point` is the `scripts/check-chain-closure.{ps1,sh} -PlanMoves`/`--plan-moves` invocation for that chain's `uuid`, and whose `disconfirm` is *"delete the manifest and `-Apply`/`--apply` must refuse"*. This routes closure through the same owner-re-runs-the-gate acceptance step every other Demonstrated criterion uses, rather than trusting a narrative claim that a chain was closed.

### Closure-run gate example

A work-order phase whose task is "close chain `<uuid>`" adds this checklist entry:

```yaml
- id: "AC-NNN"
  task_ref: "TASK-NNN"
  criterion: "Chain <uuid> reports clean via -PlanMoves and closes via -Apply."
  kind: Demonstrated
  entry_point: "scripts/check-chain-closure.ps1 -PlanMoves -Uuid <uuid>"
  disconfirm: "Delete the manifest scripts/check-chain-closure.ps1 wrote, then re-run -Apply with the same -Confirm token -- it MUST refuse (manifest not found), proving the check is not a tautology that would pass with the manifest absent."
```

### Executor pre-COMPLETE steps

Before declaring COMPLETE, the executor:

1. Resolves the gate script per the gate-resolution contract above (workspace `scripts/` → linked `scripts/` → `blockers[]` HARD BLOCK), runs `scripts/run-work-order-gates.ps1 -WorkOrder <path>` (or the `.sh` equivalent), and captures the output.
2. If the gate script exits non-zero, fixes the underlying issue and re-runs. Does not return COMPLETE until the gate exits 0.
3. Updates each `checklist[*].status` to `satisfied`, `blocked`, or `waived` and records `evidence` for each Demonstrated item.
4. If any issue cannot be resolved, writes a `blockers[]` entry with `status: open` describing the block — this replaces the inline HARD BLOCK prose message for executor-origin blocks. (All other agents and roles keep the prose HARD BLOCK format.)
5. Sets `meta.status: complete` when all items are satisfied (or `waived`, per the rule below) and no blockers are open.

### Owner COMPLETE-acceptance step

When the executor returns COMPLETE, the orchestrating owner:

1. Re-runs `scripts/run-work-order-gates.ps1 -WorkOrder <path>` (or `.sh`).
2. Rejects the COMPLETE and redirects if the gate exits non-zero.
3. Verifies `meta.status: complete` in the file before accepting.
4. Verifies no checklist item is `waived` without non-null `evidence` (see below) — reject and redirect if one is found.
5. Verifies documentation/changelog completeness (e.g. the phase's `CHANGELOG.md` entry, `plugin.json` bump, implementation-doc updates) as part of the **same** acceptance bar as functional correctness — not a follow-on task to check later. A COMPLETE that satisfies every functional checklist item but omits the record-keeping is not accepted.

### Blocker communication

The executor writes structured `blockers[]` entries into the work-order YAML (with `status: open`, `description`, and `raised_date`) instead of returning an inline prose HARD BLOCK. The orchestrating owner reads the blockers list when re-running the gate script (an open blocker causes the gate script to exit non-zero). This channel applies **only** to the executor role; all other agents retain the existing prose HARD BLOCK format.

### Waiver rule

`status: waived` is the **only** route past a criterion the executor did not satisfy as originally stated — there is no other disposition for "skipped" or "deferred" work. A waived item MUST carry:

- **Owner sign-off** recorded in the work-order (who accepted the waiver and when).
- **Non-null `evidence`** stating what was done INSTEAD of the original criterion. `evidence: null` on a `waived` item is invalid — the schema makes `evidence` optional in general, but a waiver that records nothing about its replacement is indistinguishable from a check that was silently skipped, which is exactly the tolerance this contract exists to close.

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

Use this format whenever you cannot proceed. During an approved run, an owner may stop only for a
reason listed in §Run-to-Target Contract.

```markdown
HARD BLOCK

- Stop Reason: [hard-block | unapproved-deferral]
- Blocked On: [What is missing / what prevents progress]
- Impact: [What cannot be completed]
- Required From User: [Exact decision/info/access needed]
- Required From Other Agents: [If applicable]
- Unblocked By: [Concrete next action to unblock]
- Ladder Evidence: [Required when the block arose from uncertainty: Analyst report path + Critic frame-challenge path and verdict]
- Deferral Needed: [Required for unapproved-deferral: the exact scope that would have to be deferred, and why nothing else avoids the block]
- Notes: [Optional]
```

---

## Owner Output Contract

When you report status to the user, you MUST:
- State the current gate and whether it is satisfied.
- State the next handoff (which agent, what prompt summary).
- Reference `EXECUTION_STATE_PATH` as authoritative.
- If blocked, use the Standard Hard Block Format.

Status reports are informational. During an approved run they never pause execution; see
§Run-to-Target Contract.

---

## Run-to-Target Contract (no unsolicited stops)

### Run target

When the user approves orchestration toward a named end state (for example "orchestrate these
plans until closed and fully committed locally", or "execute until completion"), that end state
is the **run target**. Record it verbatim in the execution-state file (`run_target`), along with
the ordered list of plans or phases it covers.

The run is not finished until **every** plan in it has reached the run target. Reaching the
target for one plan, passing a gate, finishing a phase, or completing a subagent return is
**never** a reason to stop. Proceed immediately to the next queued item.

### Status updates: report, don't pause

Status is valuable and expected:
- Announce each plan **starting**: the plan, its position in the run, and the first handoff.
- Announce each plan **completing**: the plan, the state reached, and what comes next.
- Give terse updates at other gates when useful.

Every update is a status line, not a decision point:
- It never ends with a question or a request for permission ("shall I continue", "let me know
  if you'd like anything adjusted", "want me to proceed").
- It never ends the turn while the run target is unreached and no stop reason applies.

### The only two agent-initiated stop reasons

1. **Hard block.** Progress within the approved scope is impossible, and one of these holds:
   - it needs something only the user can supply: access, credentials, an environment, or a
     decision the plan or a recorded ruling reserves to the user; or
   - it arose from uncertainty, and the Ambiguity Resolution Ladder below has run to the end
     without resolving it.
2. **Unapproved deferral.** The only way to avoid a hard block is to defer, drop, waive or
   weaken scope the user has not pre-approved for deferral. That includes:
   - waiving a checklist item;
   - pushing a `[Demonstrated]` criterion to a later task;
   - narrowing acceptance criteria;
   - moving a requirement into a `DEFER-*`.

   Scope the user **has** pre-approved for deferral may be deferred without stopping. Record it
   in the execution-state file and continue.

Both stops use the Standard Hard Block Format with its `Stop Reason` field filled in.

The user can always interrupt, redirect or pause the run; honor that immediately. That is the
user acting, not an agent-initiated stop.

**Self-check before ending any turn during an active run:** Has every plan in the run reached
`run_target`? If not, is this message a Standard Hard Block with a legal `Stop Reason`? If
neither, do not end the turn. Continue with the next queued item.

### Ambiguity Resolution Ladder

Ambiguity, uncertainty or an unverified constraint is **not** a stop reason. Resolve it by
delegation, in order:

1. **Analyst.** Delegate the question, spending from the run's allocated Analyst budget
   (§Analyst Delegation Budget). Frame it as a falsifiable question with the evidence standard
   and "report unknowns; do not guess". If the report resolves the ambiguity with adequate
   confidence, record the resolution in the execution-state file and continue.
2. **Critic frame challenge.** If the Analyst report does not resolve it acceptably, delegate a
   frame challenge to the Critic. This is not a plan review. The brief asks the Critic to
   challenge the entire context of the blocker:
   - **False constraints:** is a constraint being assumed that the plan, the user or the
     environment contradicts? For example, "we can't test against the live server" when the
     plan states work targets a dev server.
   - **Measurement:** are we measuring the right thing? Would the proposed check actually prove
     the claim?
   - **Solution space:** are we narrowing options without cause, or overlooking an approach that
     avoids the ambiguity entirely?
   - **Stated vs assumed:** which premises of the blocker are sourced, and which are assumed?

   The Critic returns `COMPLETE` with one verdict:
   - `resolved`, with evidence;
   - `reframed`, with a new path that stays within approved scope; or
   - `confirmed-block`, with the reason.

   On `resolved` or `reframed`, record it and continue.
3. **Hard block.** Only after a `confirmed-block` verdict, or when both steps leave the question
   genuinely open, stop with a hard block. Cite both reports in `Ladder Evidence`.

A documented safe default (per `no-silent-assumptions-software-planning`) may be applied instead
of climbing the ladder when the ambiguity is low-stakes. Record the default and continue.
Asking the user is never the first response to ambiguity during an approved run.

---

## Analyst Delegation Budget (Authoritative Owner)

This section is the **single authoritative owner** of the Analyst delegation budget formula and tracking rules for the execution phase. The Planner agent cross-references this section and does **not** restate the arithmetic.

### Execution Budget Formula

At execution-state initialization (the moment the orchestrator creates/initializes the plan's execution-state artifact), compute and snapshot the execution budget once:

```
analyst_budget.allocated = 5 + phase_count   (floor: 5 when phase_count = 0)
```

- `phase_count` is the number of implementation phases (GOAL-*) declared in the plan **at that instant**.
- Later plan edits do **not** retroactively change an in-flight budget.
- The creation-phase budget (tracked in plan frontmatter) is **cleared** at this point — it does not roll over.

### Decrement and Report Rules

- **Decrement**: on each **Analyst** subagent invocation, increment `analyst_budget.consumed` by 1.  `Explore` and other read-only research subagents are **excluded** (do not count).
- **Remaining**: `analyst_budget.remaining = allocated - consumed`. Include `remaining` in every handoff summary and state update.
- **Report format** (include in each state update): `analyst_budget: {allocated: N, consumed: M, remaining: R}`
