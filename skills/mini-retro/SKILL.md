---
name: mini-retro
description: 'Lightweight, automatic mini-retrospective the orchestrating Planner authors FIRST-HAND at the chain''s commit boundary to build a durable, long-term record of the orchestrator''s own execution experience -- plus the significant challenges it observed other agents hit. It records the orchestrator/agent experience, NOT the human user''s, and does NOT prompt the user for input (the orchestrator lived the chain and writes directly from that experience; reasoning about it second-hand or surveying the user is speculative and lower-fidelity). Captures ways-of-working feedback for improving agents, skills, and the overall process, evaluated against a two-tier memory model (core definitions vs project policy), and writes a greppable artifact to .agent-output/mini-retro/ for later bulk review and fold-in. Load when an orchestrated plan/program reaches its commit boundary, or when the user asks for a mini-retro / pre-devops retro / process feedback.'
metadata:
  version: "1.0"
---

# Mini-Retro

A **lightweight, automatic retrospective** the orchestrating owner (normally **Planner**) **authors first-hand** at the chain's commit boundary (by default after UAT approval, immediately before the DevOps handoff). It is the orchestrator's **own first-hand record of running the execution chain** -- what worked, where it struggled, and the significant challenges it observed its subagents hit -- accumulated over time into a durable corpus that makes the *agent set itself* better.

**It records the orchestrator's experience, not the human user's.** The orchestrator lived the chain, so it writes the retro directly from that experience and from the chain's own artifacts. It does **not** ask the user for input. Reasoning about agent challenges second-hand -- or surveying the user about a process they did not run -- is speculative and lower-fidelity; capturing it first-hand while the experience is fresh is the entire point. (If a user volunteers feedback it may be folded in, but the skill never solicits or waits on it.)

It is intentionally **smaller and faster than a full Retrospective agent**: it runs every plan, is a short structured self-assessment, and its *content* never blocks the pipeline — only the *existence* of the artifact is a pre-DevOps gate (see §Orchestration Checklist).

## When to Use

Load and run this skill when **all** of these hold:

- You are the orchestrating owner of an execution chain (normally `Planner`; any owner per `execution-orchestration`).
- The chain has reached the **pre-DevOps gate**: `UAT` has approved (or the project policy's configured final pre-release gate is satisfied).
- DevOps has **not yet** committed/deployed.

Also load when the user explicitly asks for a "mini-retro", "pre-devops retro", "process feedback", or "agent/skill improvement feedback".

### Trigger variants (the pre-DevOps gate is not the only trigger)

The single-plan pre-DevOps gate above is the **default** trigger. It does **not** fire for two common shapes, which historically caused the retro to be skipped until a user asked for it. Treat each of these as an equally-binding trigger:

- **Multi-plan programs / orchestrations.** When an orchestration spans several plans executed as an interleaved sequence of commits, there is no single pre-DevOps moment -- each constituent plan has its own commit boundary. Trigger **(a)** one program-level mini-retro when the program's final constituent plan reaches `Committed` (key the artifact to the program id, e.g. `<program-name>-mini-retro.md`), and **(b)** optionally a lightweight per-constituent-plan retro at each plan's own commit boundary when a plan surfaced its own distinct signal. The program-level retro is mandatory; the per-plan ones are at the owner's discretion.
- **Non-DevOps chains** (Analyst-led work, discovery campaigns handed to a follow-on plan, or any chain the user pushes/commits manually with no DevOps stage). The pre-DevOps trigger never fires here. Trigger instead at **"implementation complete + about to commit"** -- i.e. the last owner-controlled moment before the change is committed.
- **Brainstorming sessions.** At the brainstorming Gate step (Session Protocol step 8) — immediately after the GO / NO-GO / GO-with-OPENQs verdict is stated — the orchestrating agent writes a brainstorming-session retro. This is the brainstorming analogue of the pre-DevOps trigger: a first-hand, no-user-prompt capture authored at the session's natural conclusion boundary. It uses the specialized seven-part question set in [assets/brainstorm-retro-template.md](./assets/brainstorm-retro-template.md); findings convert to the standard mini-retro finding schema and accumulate in the same bulk-review corpus. See §Brainstorming Session Retrospective.

**Artifact-existence is a handoff precondition.** Because the trigger has historically lived only in the owner's memory, make the artifact's existence an explicit checkpoint at the commit boundary: the owner (and, when present, DevOps) does not finalize the commit/handoff until the relevant `<id>-mini-retro.md` exists. If the boundary was already crossed, the **mandatory retroactive write** (Procedure step 7) still applies and the placement gap is recorded as a finding in the artifact itself.

Do **not** run this as a substitute for QA or UAT. It is feedback, not a quality gate — its *content* never blocks the pipeline. The only enforcement is the *existence* of the artifact before the DevOps handoff; a missing artifact is a HARD BLOCK on DevOps (see §Orchestration Checklist).

## Orchestration Checklist

Evaluate at each gate crossing. Write the artifact as soon as the trigger fires — before the next handoff. **Never ask the user; never wait to be asked.**

| Boundary | Trigger | Artifact path |
|----------|---------|---------------|
| UAT approved (standard plan) | Always — write immediately, before DevOps | `.agent-output/mini-retro/<ID>-mini-retro.md` |
| Final plan in a multi-plan program reaches `Committed` | Always — write at program close | `.agent-output/mini-retro/<program-name>-mini-retro.md` |
| Non-DevOps chain (Analyst-led work, manual commit, no DevOps stage) | At "implementation complete + about to commit" | `.agent-output/mini-retro/<ID>-mini-retro.md` |
| Brainstorming session Gate step (step 8) | Always — write immediately after GO/NO-GO verdict, before next handoff | `.agent-output/mini-retro/<session-id>-brainstorm-retro.md` |

**Standard-plan hard gate** (enforced in `planner.agent.md`): DevOps MUST NOT be invoked until the mini-retro artifact exists.
Existence check — PowerShell: `Test-Path .agent-output/mini-retro/<ID>-mini-retro.md` | bash: `test -f .agent-output/mini-retro/<ID>-mini-retro.md`

The multi-plan and non-DevOps variants rely on the Planner evaluating this table at each major boundary. All three variants share the same "never ask" rule — if the trigger condition is met, write it.

## What "automatic" means here

The owner triggers this skill **without being asked**, as a standard step in orchestration, and **authors it without prompting the user**. The orchestrator answers each dimension from its own first-hand experience of the chain plus the chain's artifacts (execution-state, planning, implementation, code-review, QA, UAT, DevOps). The artifact is **always** produced -- automatic ≠ silent -- and is tagged with its **authorship fidelity**: `authorship: first-hand` when written by the orchestrator that actually ran the chain (the ideal), `authorship: reconstructed` when written later purely from artifacts by a context that did not live the chain (explicitly lower-fidelity and to be avoided where possible), or `authorship: resumed` when a chain is handed off mid-execution to a different orchestrating context that lived part of it first-hand and reconstructs the remainder (e.g. a session restart or delegate handoff partway through) -- distinct from pure `reconstructed` because part of the record is still lived experience. The user is never the source.

## Two-Tier Memory Model (core idea)

Feedback is only useful if it lands in the right durability tier. This skill evaluates the just-completed execution against an **effective policy** assembled from two persistent tiers (plus the ephemeral artifacts it emits).

| Tier | Name | Lives in | Durability | Example |
|------|------|----------|------------|---------|
| **Tier 1** | **Core definitions** | the canonical agent + skill repo (`vs-code-agents/agents/*.agent.md`, `vs-code-agents/skills/*/SKILL.md`) | longest-term, cross-project | The Planner agent's default workflow; the baseline mini-retro question bank |
| **Tier 2** | **Project policy** | the project repo at `.agent-output/mini-retro/policy.yaml` | medium-term, project-scoped | "Failure-mode analysis is REQUIRED for every plan; Planner must delegate to Analyst" |
| **(ephemeral)** | **Per-plan artifacts** | `.agent-output/mini-retro/<plan-id>-mini-retro.md` | per-plan, accumulates | This run's findings, tagged by target tier |

**Effective policy = Tier 1 baseline, overlaid by Tier 2 project policy.** The mini-retro evaluates reality against the *effective* policy, never against Tier 1 alone.

The point of the model: a small personal project can **suppress** a dimension in Tier 2 (e.g., `failure-mode-analysis: not-applicable`) so the mini-retro neither self-assesses it nor flags its absence — without changing the core repo. A regulated project can **require** it in Tier 2 so the mini-retro checks it was honored and flags any gap. The core repo (Tier 1) stays neutral and reusable.

See [references/memory-model.md](./references/memory-model.md) for the full resolution rules, precedence, and the bulk-review / fold-in lifecycle.

## Procedure

1. **Confirm the gate.** Verify `UAT_Approved: true` on the plan (or the project's configured final pre-release gate). If not satisfied, do not block — record `gate: unsatisfied` in the artifact, run anyway with reduced scope, and note it.

2. **Resolve the effective policy.**
   - Load Tier 1 baseline from this skill's [references/question-bank.md](./references/question-bank.md). Note the `default-asked` marker on each optional dimension: `optional, default-asked: true` dimensions (currently `failure-mode-analysis` and `gradient-scorecard`) are in the default asked-set for every consumer; `optional, default-asked: false` (or no marker) dimensions are not asked unless Tier-2 `enable`s them.
   - Load Tier 2 project policy from `.agent-output/mini-retro/policy.yaml` if it exists. If it does not exist, use Tier-1 defaults and note `policy: tier1-defaults-only` (this is normal and fine — do not impose Tier 2 on a project that hasn't opted in).
   - Compute the effective dimension set: start from the Tier-1 default asked-set; apply Tier-2 `enable` / `disable` / `require` / `suppress` overrides; append any Tier-2 `project-questions`. See the schema in [references/project-policy.schema.md](./references/project-policy.schema.md).

3. **Recall and gather evidence (read-only).** Draw on your **own first-hand experience** of running the chain, and corroborate it against the execution-state file and the chain's artifacts (planning, analysis, critic, implementation, code-review, qa, uat, devops) — delegation counts, blockers, rework, escalations, and the subagents' own returns where they reported difficulty. This is recall plus evidence, not a survey.

4. **Self-assess each dimension.** Answer the effective dimension set (see the self-assessment rubric below) directly from your first-hand experience and the gathered evidence. **Do not prompt the user.** A dimension with nothing notable is recorded at its default (a-option) and produces no finding.

5. **Tag every finding.** For each issue or improvement, record: `target-tier` (core | project), `target` (agent or skill name, or `process`), `change-type` (add | modify | remove | suppress), `confidence` (low | med | high), and `fold-in` (yes | needs-bulk-review | upstream-candidate). This is what makes later bulk review tractable. `fold-in: upstream-candidate` is for a project-tier practice minted specifically to harden a shared skill's rule -- see [references/memory-model.md](./references/memory-model.md) §Bulk review & fold-in lifecycle for the disposition and its required `patches` marker. See [references/question-bank.md](./references/question-bank.md) §Finding Schema for the base schema.

6. **Write the artifact** to `.agent-output/mini-retro/<plan-id>-mini-retro.md` using [assets/mini-retro-template.md](./assets/mini-retro-template.md). Inherit the plan's `ID`/`UUID`; do **not** increment `.agent-output/.next-id` (this artifact is keyed to its plan, not a new lifecycle document). Create the `.agent-output/mini-retro/` directory if absent.

7. **Hand off to DevOps.** Because the artifact is written *before* the DevOps handoff, it rides the DevOps release commit automatically — no separate commit by the owner is required. If the mini-retro is run outside an orchestrated flow (no DevOps to follow), stage and commit it explicitly so it is not lost. **Retroactive write is mandatory:** if the mini-retro artifact for this plan ID does not exist when DevOps is about to commit (or has just committed), write it now even retroactively — the placement gap is itself a defect the artifact should record.

## Self-assessment rubric

The orchestrator answers each dimension **about its own experience of the chain** — these are reflection prompts the orchestrator puts to *itself*, never questions put to the user. Each dimension has a default (a-option = nothing notable) and named alternatives that become findings. Answer from first-hand recall + evidence:

```md
MINI-RETRO (plan 081) — orchestrator self-assessment (no user prompt)

1 (Agents)     Did every invoked agent earn its place, and did each fulfil its role?
  a) Yes, all necessary and effective (default)   b) One added little value — name it   c) A needed role was missing/late — name it

2 (Skills)     Were the right skills loaded at the right time?
  a) Yes (default)   b) A skill misfired / was noise — name it   c) A missing skill would have helped — name it

3 (Process)    Did sequencing, gating, and handoffs fit? Where did the orchestrator or a subagent struggle?
  a) Smooth (default)   b) Excessive rework / a subagent stalled or returned non-conformingly — describe it   c) A gate was skipped/added/mis-ordered — which

4 (Policy fit) Did the effective project policy match what this work needed?
  a) Yes (default)   b) Something REQUIRED added no value — relax in Tier 2   c) Something ABSENT should have been required — add in Tier 2 / promote to Tier 1
```

Record the chosen option plus verbatim rationale and evidence for every non-default answer; that becomes the finding. **Capturing the significant challenges subagents hit** (stalls, non-conforming returns, repeated rework, recurring hygiene escapes) is a first-class goal of dimension 3 — the orchestrator observed these first-hand and they would otherwise be lost or reconstructed speculatively later.

**Optional gradient dimension.** When `gradient-scorecard` is active in the effective
policy (ON by default; disabled via Tier-2 `disable`), also fill in the 20-question
1–10 scorecard. The rubric (questions, anchors, sensitivity/finding rules) lives in
[references/gradient-scorecard.md](./references/gradient-scorecard.md). Use the standalone
blank [assets/gradient-scorecard-blank.md](./assets/gradient-scorecard-blank.md) to fill in
scores, and append the completed section to the artifact under `## Gradient Scorecard`. Any
aspect scoring ≤ 6 or Δ ≤ −2 must produce a tagged finding. See
[assets/gradient-scorecard-example.md](./assets/gradient-scorecard-example.md) for a
worked walk-through.

## Constraints

- **Never blocks DevOps on content.** This is feedback, not a content gate. Worst case: `gate: unsatisfied`, artifact still written. (The *existence* of the artifact before DevOps is enforced separately — see §Orchestration Checklist.)
- **Never prompts the user.** The orchestrator authors the artifact first-hand; it does not solicit or wait on user input. The record is the orchestrator's (and its observed subagents') experience, not the user's.
- **Read-only on the codebase.** The only file it writes is its own artifact (and, if absent, the `.agent-output/mini-retro/` directory and an example policy on first run if the user opts in).
- **Does not modify agents or skills.** It only *proposes* changes (tagged by tier). Folding findings into Tier 1/Tier 2 is a separate, deliberate step (see memory-model fold-in).
- **Tier-2 is opt-in.** Absence of `policy.yaml` is valid; never invent project requirements the project did not declare.
- **One artifact per plan.** Re-running overwrites/append-updates the same `<plan-id>-mini-retro.md`.

## Brainstorming Session Retrospective

A **specialized retrospective** triggered at the end of every brainstorming session — the brainstorming analogue of the pre-DevOps gate trigger.

**When:** Immediately after the Gate step (Session Protocol step 8) of the brainstorming skill produces a GO / NO-GO / GO-with-OPENQs verdict. Write before handing off to the next agent or returning control to the user.

**Who:** The orchestrating agent that ran the session (normally Planner), authoring first-hand. Never prompts the user; user-volunteered observations may be folded in.

**What:** Seven brainstorming-specific dimensions (framing, scoring integrity, divergence/convergence mechanics, skill friction, ambiguity attribution, mistake ledger, net improvement), each default-able. Only non-default answers become findings. Use [assets/brainstorm-retro-template.md](./assets/brainstorm-retro-template.md) as the artifact template.

**Artifact path:** `.agent-output/mini-retro/<session-id>-brainstorm-retro.md`

**Authorship tag:** `authorship: first-hand` when written by the orchestrator that ran the session; `authorship: reconstructed` when filled later from artifacts (lower fidelity — avoid where possible); `authorship: resumed` when a different orchestrating context picks up a chain already partway lived by a prior one (part first-hand, part reconstructed).

**Finding compatibility:** Every non-default answer converts to a finding using the standard mini-retro finding schema (`target-tier`, `target`, `change-type`, `confidence`, `fold-in`). Brainstorming retros accumulate in the same bulk-review corpus and are eligible for the same Tier-1 / Tier-2 fold-in lifecycle.

**Existence check:** `Test-Path .agent-output/mini-retro/<session-id>-brainstorm-retro.md` (PowerShell) | `test -f .agent-output/mini-retro/<session-id>-brainstorm-retro.md` (bash). The brainstorming skill's Gate step should not be considered complete until this file exists.

**Design rules (inherited):** Every dimension is default-able — the a-option means "nothing notable" and produces no finding. A clean session costs ~2 minutes. Prefer countable answers over taste (brainstorming Load-Bearing Rule 5). Part 0 is a greppable fingerprint enabling cross-session pattern extraction with `grep`/`awk` without re-reading reports.

## Retrospective coverage (post-ADR-013)

The `Retrospective` agent was retired per ADR-013. This skill is now the **primary, automatic, owner-run** lesson-capture mechanism for every plan. It carries the recurring process-improvement signal. Deeper lessons extracted for the next planning cycle are consumed by the `PI` (ProcessImprovement) agent via its Phase 1 Retrospective Analysis intake. Explicit one-off deep dives can still be requested directly via the `PI` agent.

## References

- [references/memory-model.md](./references/memory-model.md) — tier resolution, precedence, bulk-review & fold-in lifecycle
- [references/question-bank.md](./references/question-bank.md) — Tier-1 baseline questions + finding schema
- [references/project-policy.schema.md](./references/project-policy.schema.md) — Tier-2 `policy.yaml` schema
- [references/gradient-scorecard.md](./references/gradient-scorecard.md) — canonical 20-question gradient rubric (single owner of questions + anchors)
- [assets/mini-retro-template.md](./assets/mini-retro-template.md) — artifact template
- [assets/brainstorm-retro-template.md](./assets/brainstorm-retro-template.md) — brainstorming-session retro artifact template
- [assets/gradient-scorecard-blank.md](./assets/gradient-scorecard-blank.md) — standalone blank fill-in template for the gradient scorecard
- [assets/gradient-scorecard-example.md](./assets/gradient-scorecard-example.md) — worked walk-through example (fabricated scores; ILLUSTRATIVE ONLY)
- [assets/project-policy.example.yaml](./assets/project-policy.example.yaml) — worked Tier-2 examples (personal vs regulated vs gradient opt-in)
