---
name: executive-summary
description: 'Defines the executive summary artifact: its required fields, glyph convention, and MUST NOT list, plus its own MANDATORY auto-trigger conditions -- fires automatically at the Architect-approval and Critic-approval Review_State transitions, and on any explicit user ask ("executive summary", "executive summary of plan <ID>", "summarize plan <ID>", "give me a summary of this plan"). Load when producing, or asked for, an executive summary of a plan.'
metadata:
  version: "1.0"
---

# Executive Summary

The **executive summary** is the plan-status artifact rendered in chat (never a file) that gives the
user everything needed to approve, or stay oriented on, a plan -- without re-reading the plan
document. This skill is the single source of truth for **when** it fires, **what** it must contain,
and **how firing is verified**. It exists as its own skill, mirroring `mini-retro`'s proven
self-triggering pattern, so that trigger conditions are not buried inside an unrelated skill's
description where they are never matched.

## When to Use (Trigger Conditions)

Load this skill, and produce an executive summary, whenever **any** of the following hold. None of
these require the user to ask first -- see §Auto-Trigger below for the two that are MANDATORY.

- **Auto-Trigger A -- Architect approval** (ARCH-REQUIRED plans only; snapshot, non-final)
- **Auto-Trigger B -- Critic approval** (all plans; final, includes the approval prompt)
- **Auto-Trigger C -- HARD BLOCK during orchestration** (snapshot of the current blocked plan, per `planner.agent.md`'s HARD BLOCK handling)
- **Explicit ask** -- the user asks for an "executive summary", an "executive summary of plan `<ID>`", to "summarize plan `<ID>`", or an equivalent direct request naming a plan

## Auto-Trigger (MANDATORY -- self-triggering, never ask)

The executive summary is not an on-request-only artifact. Firings A and B below fire automatically
at their `Review_State` transition; the orchestrating Planner MUST NOT wait for the user to ask, and
MUST NOT ask permission before producing one -- this is the identical non-negotiable framing as the
`mini-retro` MANDATORY trigger. Both firings render the same field schema (§Required Fields); only
Firing B retains the closing approval prompt and the frontmatter write.

| Firing | When | Registry Ask | Approval prompt | Frontmatter write |
|--------|------|---------------|------------------|--------------------|
| **A -- Architect approval** | `Review_State` advances toward `critic-review` (ARCH-REQUIRED plans only), before Critic review begins | No | No | No -- snapshot only |
| **B -- Critic approval (final)** | Critic feedback fully addressed, plan ready for user approval | Yes, when applicable (see `planner.agent.md` P-0) | Yes -- ends with "The plan is ready for approval. Do you approve?" | Yes -- see §Enforcement |

Firing A explicitly does **NOT**: include the Registry Ask; end with the approval-prompt sentence; or
update `User_Approved`/`Critic_Approved`/`Executive_Summary_Fired` frontmatter. It is a status
snapshot only, produced before Critic review starts so ARCH-REQUIRED plans get visibility one step
earlier.

Firing B is the final, canonical firing. On completion it updates plan frontmatter:
`Executive_Summary_Fired: true`, `Executive_Summary_Fired_Date: [ISO-8601]` (see §Enforcement) --
this happens whether or not the user approves in the same turn, because the artifact itself was
produced; `User_Approved`/`User_Approved_Date` are set separately, only on actual user approval.

**Also fires (non-`Review_State`-transition case):** per `planner.agent.md`'s HARD BLOCK handling,
produce a snapshot executive summary of the currently blocked plan alongside the block details, so
the user has full situational awareness. This firing does not touch `Executive_Summary_Fired`
frontmatter (only Firing B does).

## Glyph Convention (Convention 5 / Chosen)

Every tagged section header pairs a `[TAG]` with its emoji, both together, in the heading itself:
Risk ⚠️ `[RISK]` · Deferred ⏸️ `[DEFER]` · Blocking 🛑 `[BLOCK]` · Assumption 🧩 `[ASSUME]` ·
Alternative 🔀 `[ALT]` · USER-TASK 🙋 `[USER]`. This is the sole canonical glyph set -- do not
substitute ad-hoc emoji or invent new tags.

## Required Fields

Rendered per the user-approved design (analysis 029, Variation 3: Cross-Referenced, Always-Visible).
Every field is always fully visible -- no `<details>`/`<summary>` or other collapsing HTML anywhere
(confirmed non-functional, rendering as literal text, in the live target chat surface).

| Field | Description |
|-------|-------------|
| Plan Identity | ID, title, last-updated, current Status |
| Top Glance Line | One line of flat counts -- Deferred / top Risk / Blocking / high-risk Assumption / Alternative / USER-TASK -- each paired with its `[TAG]` + emoji |
| ⏸️ [DEFER] Deferred Items | **Forced-visibility, same rigor as USER-TASK Highlight.** Own dedicated section, placed first right after the header -- never folded into Scope Snapshot or Alternatives. Full `DEFER-*` table (ID / Item / Why now / Revisit trigger / Owner). Each origin point (Scope Snapshot, Alternatives) carries only a short inline cross-reference back to the relevant `DEFER-*` ID |
| Scope Snapshot | REQ/SEC/CON items -- no item cap. Any item narrowed or withdrawn by a Deferred Item carries an inline `⏸️ [DEFER]` cross-reference to it |
| Phases Overview | For each phase: phase name + GOAL-* + phase status, with that phase's own TASK-* items nested directly as a sub-list under its line |
| 🙋 [USER] USER-TASK Highlight | List prominently with justification summary; MUST be shown before approval prompt |
| 🧩 [ASSUME] Assumptions | List ASSUMPTION-* (at least titles); highlight high-risk ones |
| 🔀 [ALT] Alternatives | List ALT-* with 1–3 sentence rationale each; carries an inline `⏸️ [DEFER]` cross-reference where a rejected alternative relates to a Deferred Item |
| ⚠️ [RISK] Risks | Include top RISK-* with the ⚠️ marker |
| Open Questions | List any OPENQ-* remaining; mark blocking ones with 🛑 `[BLOCK]` BLOCKING |
| Traceability Matrix | Condensed cross-reference table: `Requirement \| Tasks \| Risk \| Failure Mode \| Guarantee` (omits Tests, which stays in the plan's own Traceability Map section). A requirement fully withdrawn -- not merely deferred-in-place -- structurally has no row here; it surfaces only in Deferred Items |

## Age-Triggered Mandatory Escalation

An `OPENQ-*` whose origin document has aged past 10 days (per `document-lifecycle`'s OPENQ
Staleness Sweep) MUST be marked `BLOCKING` the next time it is listed in an Executive Summary or
Open Questions section, regardless of its original non-blocking disposition -- reusing the same
mandatory-escalation channel already proven by `USER-TASK-*` highlighting above. This does not
reopen the question's substance; it forces renewed visibility on the person who can resolve it
before it erodes into unexamined settled fact.

## Executive Summary MUST NOT

- Copy the entire plan verbatim
- Introduce new requirements
- Hide USER-TASK-* items
- Omit the Deferred Items field, or render it with less visibility than USER-TASK Highlight
- Use `<details>`/`<summary>` or any other collapsing HTML
- Wait to be asked for Firings A or B (see §Auto-Trigger)

## Enforcement (HARD BLOCK Backstop)

Mirroring `mini-retro`'s `Test-Path`/HARD BLOCK enforcement, Firing B's completion is tracked in
plan frontmatter -- owned and defined in `structured-labeling`'s Approval Tracking Frontmatter
Schema, semantics owned here:

| Field | Type | Set by | When |
|-------|------|--------|------|
| `Executive_Summary_Fired` | boolean | Planner | Firing B (Critic-approval executive summary) has been produced |
| `Executive_Summary_Fired_Date` | ISO-8601 / null | Planner | Same moment as above |

**Hard gate (enforced in `agents/critic.agent.md`'s TEMPLATE VALIDATION step):** once `Critic_Approved`
is `true`, `Executive_Summary_Fired` MUST also be `true`. If `Critic_Approved: true` and
`Executive_Summary_Fired` is absent or `false`, this is a template-compliance finding -- the plan
must not proceed to the user-approval prompt until the executive summary is actually produced and
the field updated.

## Related

- `structured-labeling` -- owns label prefixes, plan template ordering, and the Approval Tracking
  Frontmatter Schema (including the `Executive_Summary_Fired`/`_Date` field definitions this skill's
  enforcement relies on). This skill owns the executive summary's content and trigger semantics;
  `structured-labeling` owns where its completion is recorded.
- `mini-retro` -- the sibling MANDATORY, self-triggering, never-ask pattern this skill's
  §Auto-Trigger and §Enforcement directly mirror.
- `plan-status-reporting` -- the multi-plan, cross-plan status report; distinct from this
  skill's single-plan executive summary, and often produced alongside it during a HARD BLOCK
  (see Auto-Trigger C).
