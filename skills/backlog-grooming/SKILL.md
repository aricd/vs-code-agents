---
name: backlog-grooming
description: >
  Manually invoked portfolio review that grooms every open plan for execution. Inventories open
  plans, harvests open questions, hidden decisions, deferrals and conflicts with recorded
  decisions, resolves factual unknowns through batched Analyst delegation, scorecards remaining
  design choices with design-rubrics (deep/lean), runs mandatory code-trace, ADR-overlap,
  demonstration-feasibility, necessity and side-effect checks, and produces a goal-anchored
  decision packet with a readiness board and a recommended serial execution order derived from
  the plans' dependency DAG (parallel waves on request). Invoke with /backlog-grooming.
argument-hint: "Goals, e.g. 'G1: <outcome>; G2: <outcome>' -- optional: plan IDs to limit scope"
disable-model-invocation: true
metadata:
  version: "1.0"
---

# Backlog Grooming

Groom every open plan in `.agent-output/planning/` so each one is either **ready to execute**
or has a precise, minimal list of what stands in the way. Facts are resolved by Analysts, design
choices are scorecarded, and scope, policy and priority questions go to the user.
The result is a **decision packet**, not plan edits.

## When and who

- **Manual only.** Run it when the user invokes `/backlog-grooming`. Never self-trigger.
- **Run as Planner.** The workflow needs Analyst delegation. If the active agent cannot
  delegate to subagents, say so and stop. Do not substitute your own unverified reading for
  delegated analysis.
- **Scope.** Every non-terminal plan outside `closed/` (terminal statuses per
  `document-lifecycle`), or only the plan IDs passed as arguments.

## Operating rules

1. **Goal-anchored.** Every plan, open item and deferral is scored against the user's stated
   goals. Work that serves no goal is parked, not groomed.
2. **Facts before opinions.** A question answerable by reading code, config or docs goes to an
   Analyst before it is scored or shown to the user (the Stage-0 routing gate in
   `no-silent-assumptions-software-planning`).
3. **Never decide for the user.** Scope, priority, policy and any new primitive or mechanism
   are user decisions. This holds even when one option looks obviously better. Present a
   recommendation, then wait.
4. **Evidence standard.** Every finding cites file:line against the source of truth the
   project has pinned (branch, tag or commit). Label confidence as **Verified**,
   **High-confidence inference** or **Hypothesis**. Report unknowns as unknowns.
5. **Mechanical fixes only.** You may fix stale tables, frontmatter drift, duplicate entries,
   malformed rows and broken citations, recording each fix in the plan's changelog.
   Anything that changes scope, design, requirements or approvals goes in the packet.
6. **Don't re-litigate.** An item already decided (recorded user decision, accepted ADR, closed
   analysis) is marked settled with its citation. Reopen it only on new evidence, and say what
   the evidence is.

## Stage 0 -- Setup

1. **Goals.** Take them from the argument. If absent, ask once, offering any goals found in the
   roadmap, `CONTEXT.md` or the plans themselves. Label them `G1`, `G2`, and so on.
2. **Recorded decisions.** Collect the sources that bind this run: `docs/adr/`, `CONTEXT.md`,
   user decisions (`UD-*`) recorded in critiques and previous grooming packets, and any memory
   or rulings files the workspace keeps.
3. **Skills.** Load `design-rubrics` (it routes to `deep-modules` and `lean-design` on demand),
   `structured-labeling`, `no-silent-assumptions-software-planning` and
   `execution-orchestration` (for the delegation contract). Load `literal-intent-fidelity` if
   the goals state a testable criterion.
4. **Budget.** Up to **10 Analyst delegations** per run without asking, per the Planner's
   delegation-budget rules. Ask before exceeding it. Record consumption per plan in the packet.

## Stage 1 -- Inventory

For each plan, record: ID, title, status, `Review_State`, approvals, goal served (or
"neither"), and dependencies on other plans and ADRs.

Flag inconsistencies as you go:
- frontmatter that disagrees with the approval table or changelog;
- duplicated or malformed changelog entries and tables;
- claims contradicted by a later revision of the same plan.

## Stage 2 -- Harvest open items

Collect from every plan, not just the `OPENQ-*` section:

- `OPENQ-*` items, resolved or not, whose resolution is still unverified;
- `DEFER-*` items and their triggers;
- `ASSUMPTION-*` items and claims marked unverified or inferred;
- anything left to **"Implementer discretion"** that is really a design decision;
- conflicts with recorded decisions, with ADRs (including options an ADR already rejected),
  or with other plans.

Classify each item exactly once:

| Class | Meaning | Route |
| --- | --- | --- |
| **F** | Fact: reducible by reading code, config or docs | Stage 3 (Analyst) |
| **D** | Design: two or more viable designs for the same capability | Stage 5 (scorecard) |
| **U** | User: scope, priority, policy, or a new primitive or mechanism | Decision packet |
| **S** | Settled: already decided | Cite it; no action |

Triage every deferral into **keep** (the trigger is still right), **re-trigger** (the goals
changed its relevance), **park** (serves no goal), **drop** (obsolete or duplicate) or
**re-home** (belongs to another repository or owner).

## Stage 3 -- Reduce uncertainty (eager, batched)

1. **Batch** F items by source area (same repository, service or subsystem), so one Analyst
   reads each area once. Run independent batches in parallel.
2. **Brief** each batch with the `execution-orchestration` delegation contract. Add these
   grooming-specific fields:
   - for each question: the exact question, and which plan and item the answer changes;
   - the pinned source of truth, and the citation and confidence-label requirement;
   - "report unknowns; do not guess; do not propose designs".
3. **Skip** anything a closed analysis already answers. Cite that analysis instead.
4. **Reclassify** after results return. An answered F item often becomes S, or turns out to
   hide a D or U item. Record the answer, confidence and citation against the item.

## Stage 4 -- Mandatory checks, every plan

Run all eight checks in [references/grooming-checks.md](./references/grooming-checks.md). Each
names its question, how to run it, and the failure signatures to look for. Summary:

| # | Check | Blocking when |
| --- | --- | --- |
| C1 | Code trace: one concrete request or message end to end, including failure, retry, locks and notification | A traced path does not do what the plan claims |
| C2 | ADR overlap: every ADR in the problem space is cited and reconciled | The plan re-introduces an ADR-rejected option or duplicates an ADR-owned mechanism |
| C3 | Demonstration feasibility: each `[Demonstrated]` criterion observes something real, and its trigger exists | It cannot pass as written |
| C4 | Necessity: supply **and** demand evidence for any new primitive or mechanism | Either side is missing and the item is in task scope |
| C5 | Side effects: outbound calls declare their effect, are gated, cannot replay on retry, and fail visibly | A mutation can occur ungated or silently |
| C6 | Internal consistency after revisions | Sections contradict each other on scope or mechanism |
| C7 | Approval-state consistency | Approvals predate a material change or recorded user decision |
| C8 | Recorded-decision conformance | The plan contradicts a recorded user decision without raising it |

Grade findings **Blocking / High / Medium**. Any Blocking finding makes the plan **Needs rework**.

## Stage 5 -- Scorecard the D items

Use `design-rubrics` exactly as it prescribes: Lens Applicability declaration first, then the
compact decision template or OPENQ-framing mode, and the mandatory Hazard probe.

Every proxy count cites file:line. Each scorecard ends with a recommendation, a confidence
level, and the single piece of evidence that would flip the verdict. Do not invent a scoring
format; `design-rubrics` owns it.

## Stage 6 -- Mechanical fixes

Apply only the fixes that operating rule 5 permits. Record each one in that plan's changelog
("mechanical fix during backlog grooming: ...") and list it in the packet.

## Stage 7 -- Recommended execution order (DAG)

Recommend the order in which to execute the plans in scope. Parked plans are left out.

1. **Build the dependency graph.** Cite evidence for every edge (`DEP-*`, `FILE-*`,
   `CONTRACT-*`, or an Analyst result).
   - **Hard edge (A before B):** B consumes something A produces, such as a component, a
     contract, an ADR ratification, data, or the trigger a demonstration needs. B cannot
     succeed if A is not done.
   - **Soft edge (A before B, overridable):** A and B edit the same files, seams or ADRs, so
     running them in this order avoids rework or merge churn. Where the project provides
     `scripts/check-plan-scope-collision.ps1` and its plans use the registry format that
     script reads, use it; otherwise compare the plans' Files sections directly.
   - **Decision gate:** B waits on a user decision (`UDQ-n`). This is a start condition, not
     an edge.
2. **Cycles are findings, not scheduling problems.** A cycle of hard edges is a **Blocking**
   finding. Report the edges involved, and raise the proposed cut (usually splitting one plan)
   as a user decision. Never order around a cycle silently.
3. **Serial by default.** Topologically sort into one sequence, one plan at a time. Break ties
   between plans with no ordering edge using these rules, in this order:
   1. goal priority (G1 before G2, unless the user said otherwise);
   2. readiness (Ready, then Ready-after-decisions, then Needs rework);
   3. unblocking power (the plan that unblocks more downstream plans goes first);
   4. risk retirement (the plan that retires a major unknown or validates a risky assumption
      goes first);
   5. smaller first, only if the plans state their size.

   Record which rule placed each plan.
4. **Parallel only on request.** Do not optimize for parallel execution. If the user asks for
   it, group the serial order into waves whose members share no hard or soft edge, and name
   any contention risk (shared runtime lock, shared test environment, same reviewer).
5. **Present the order as a table**, one row per plan, in execution order:

   | # | Plan | Goal | Readiness | Depends on (hard) | Sequenced after (soft) | Unblocks | Start gate | Why this position |
   | --- | --- | --- | --- | --- | --- | --- | --- | --- |
   | 1 | `<ID>` `<short title>` | G1 | Ready | -- | -- | `<IDs>` | -- | Tie-break 1: G1 before G2 |
   | 2 | `<ID>` `<short title>` | G1 | Ready-after-decisions | `<ID>` | -- | -- | `UDQ-2` answered; `<ID>` committed | Hard edge from `<ID>` |

   - **Start gate:** everything that must be true before the plan starts. That means the hard
     dependencies are committed, the user decisions are answered, and the approvals are
     current.
   - **Why this position:** either the edge that forces it or the tie-break rule that placed
     it.

   List parked plans below the table under **Not scheduled**, each with its reason. A Mermaid
   flowchart of the hard edges may follow the table (`mermaid-diagrams` validates it), but the
   table is the deliverable.

## Stage 8 -- Decision packet, then stop

Write the packet from [assets/decision-packet-template.md](./assets/decision-packet-template.md)
to `.agent-output/critiques/<ID>-backlog-grooming.md`, taking its ID and header from
`document-lifecycle`. Then present in chat:

- the readiness board;
- the recommended execution order table (Stage 7);
- the user-decision table, highest impact first, with related decisions batched.

Also give the path to the full packet. **Stop.** Do not start implementation, re-submit plans
for approval, or fold decisions until the user replies.

### Definition of Ready

A plan is **Ready** only if **all** of these hold:

- Its approvals are current and consistent (C7).
- It has no Blocking finding and no open blocking U or D item.
- Every `[Demonstrated]` criterion is feasible (C3).
- Its dependencies are met, or it is sequenced after them.
- Every deferral has a trigger and an owner.
- It traces to at least one goal.

Otherwise the plan is one of:
- **Ready-after-decisions:** only U items block it.
- **Needs rework:** a Blocking finding, or a D item needing Planner work.
- **Park:** it serves no goal.

## Stage 9 -- After the user replies

1. Record each answer in the packet as `UD-<n>` with its date. Record a plan approval only when
   the user states it explicitly.
2. Fold decisions into the affected plans and ADRs. A **material** change resets
   `Architect_Approved`/`Critic_Approved` and re-routes the plan through the normal Planner
   review flow. A non-material change (e.g. a clarified wording) does not.
3. Recompute the Stage 7 order, since decisions can add, remove or re-weight edges. Update the
   readiness board and execution order in the packet, then present what changed. If the user
   asked for parallel waves, regroup them now.
4. Stop before implementation. Execution starts only through the normal Planner orchestration
   trigger.

## Anti-patterns

- **Approving on template compliance alone.** Section order, labels and citations can all pass
  while the mechanism is broken. C1 and C3 exist because review passes that checked form
  missed runtime defects.
- **Treating "Implementer discretion" as settled.** It is often where the real design decision
  is hiding. Harvest it (Stage 2).
- **Checking necessity on one side only.** Proving data is only available through a new
  channel does not show that anything needs it (C4).
- **Silently resolving a conflict** with a recorded decision or ADR, in either direction (C8).
- **Demonstrations that observe nothing.** For example, a success criterion read from an
  endpoint that returns an empty acknowledgement (C3).
- **Owning other repositories' work** in a deferral list. Re-home it.
- **Re-analysing settled items**, or delegating what a closed analysis already answers.

## Related skills

- `design-rubrics`, `deep-modules`, `lean-design`: scorecards for D items (Stage 5).
- `no-silent-assumptions-software-planning`: the Stage-0 routing gate; the OPENQ classifier.
- `execution-orchestration`: the delegation contract for Analyst batches (Stage 3).
- `structured-labeling`: label families and section order the checks rely on.
- `document-lifecycle`: packet numbering and header; terminal statuses.
- `system-integration-gate`: the composition-root expectations behind C1 and C3.
- `plan-status-reporting`: a plain status snapshot only. Use it when no grooming is wanted.
