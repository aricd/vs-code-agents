---
ID: <next-id>
Origin: <next-id>
UUID: <8-hex>
Status: Active
Date: <YYYY-MM-DD>
Review-Pass: Backlog Grooming
Scope: <all open plans | plan IDs>
---

# Backlog Grooming Packet -- <YYYY-MM-DD>

## Changelog

- <YYYY-MM-DD>: Grooming pass. <n> plans in scope; <n> Analyst delegations used.

## Goals

| ID | Goal |
| --- | --- |
| G1 | <outcome> |
| G2 | <outcome> |

## Summary

<One paragraph: what is Ready, what is blocked and on what, and the single most important
decision for the user.>

## Readiness Board

| Plan | Title | Goal | State | Readiness | Blocking items | Next action |
| --- | --- | --- | --- | --- | --- | --- |
| <ID> | <title> | G1 / G2 / neither | <Review_State> | Ready / Ready-after-decisions / Needs rework / Park | <UDQ-n, F-n, C-finding> | <one action> |

## Recommended Execution Order

Serial by default; see Stage 7 of the skill for the edge types and tie-break rules. Parallel
waves only if the user requested them.

| # | Plan | Goal | Readiness | Depends on (hard) | Sequenced after (soft) | Unblocks | Start gate | Why this position |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | <ID> <short title> | G1 | Ready | -- | -- | <IDs> | -- | <edge or tie-break rule> |

**Dependency edges** (evidence for each):

| From | To | Type | Evidence |
| --- | --- | --- | --- |
| <ID> | <ID> | hard / soft | <DEP-*, FILE-*, CONTRACT-*, analysis> |

**Cycles:** <none, or the edges involved and the proposed cut (see User Decisions Requested)>

**Not scheduled:** <parked plans, each with its reason>

<Optional: a Mermaid flowchart of the hard edges.>

## User Decisions Requested

Highest impact first. Related questions are batched.

| ID | Plan(s) | Question | Options | Recommendation | Confidence | Goal impact | Unblocks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UDQ-1 | <IDs> | <question> | a) ... b) ... | <option + one-line why> | High / Med / Low | G1 / G2 | <plans/items> |

Reply format: `UDQ-1: a, UDQ-2: b, approve: <plan IDs>`.

## Check Findings

| Plan | Check | Severity | Finding | Evidence |
| --- | --- | --- | --- | --- |
| <ID> | C1-C8 | Blocking / High / Medium | <one sentence> | <file:line> |

## Design Scorecards

<One block per D item, in the design-rubrics format: Lens Applicability line, proxy counts with
file:line references, Hazard probe, verdict, confidence, and flip condition.>

## Analyst Results

| Item | Plan | Question | Answer | Confidence | Evidence | Changed |
| --- | --- | --- | --- | --- | --- | --- |
| F-1 | <ID> | <question> | <answer> | Verified / Inference / Hypothesis | <file:line or analysis ID> | <plan item it changed> |

Analyst delegations used: <n> of <budget>. Per plan: <ID>: <n>, ...

## Deferral Triage

| DEFER | Plan | Disposition | Rationale | Trigger / new owner |
| --- | --- | --- | --- | --- |
| <DEFER-x-y> | <ID> | keep / re-trigger / park / drop / re-home | <why, against goals> | <trigger or owner> |

## Settled Items

| Item | Plan | Settled by |
| --- | --- | --- |
| <item> | <ID> | <UD-*, ADR, analysis> |

## Mechanical Fixes Applied

- <plan ID>: <fix> (changelog entry added)

## Recorded User Decisions

<Filled after the user replies: UD-n, date, decision, plans affected, fold status.>
