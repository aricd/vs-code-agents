---
ID: <inherit-plan-id>
Origin: <inherit-plan-origin>
UUID: <inherit-plan-uuid>
Status: Active
Type: mini-retro
Plan_Reference: .agent-output/planning/<plan-id>-<plan-name>.md
Date: <YYYY-MM-DD>
Owner_Role: Planner
Gate: satisfied # satisfied | unsatisfied
Authorship: first-hand # first-hand (orchestrator that ran the chain) | reconstructed (later, from artifacts only -- lower fidelity) | resumed (partway handoff -- part first-hand, part reconstructed)
Policy: tier2-applied # tier2-applied | tier1-defaults-only
---

# Mini-Retro <plan-id>: <plan-name>

First-hand record of the orchestrator's experience running this chain (and the significant challenges it observed its subagents hit). Authored by the orchestrator, not a user survey. Goal: improve the agent set (agents / skills / process). Findings are tagged by target tier for later bulk review and fold-in. Non-blocking.

## Context

- **Plan:** <plan-id> — <plan-name>
- **Delegation chain:** <e.g. Planner -> Critic -> Implementer -> Code Reviewer -> QA -> UAT>
- **Pre-release gate:** <UAT> — <satisfied | unsatisfied (reason)>
- **Effective policy source:** <tier2-applied | tier1-defaults-only>

## Effective Policy In Force

Resolved dimension set (Tier 1 ⊕ Tier 2). Records exactly what was self-assessed this run.

| Dimension | Requirement | Source | Notes |
| --- | --- | --- | --- |
| agents | required | tier1 |  |
| skills | required | tier1 |  |
| process | required | tier1 |  |
| policy-fit | required | tier1 |  |
| failure-mode-analysis | <required \| optional \| suppressed> | <tier1 \| tier2> |  |
| gradient-scorecard | <optional \| required \| suppressed> | <tier1 \| tier2> | ON by default; omit row if suppressed |
| improvement | required | tier1 |  |
| <PQ-1 ...> | <...> | tier2 | <project question> |

## Answers

| Dimension             | Answer    | Rationale / evidence |
| --------------------- | --------- | -------------------- |
| agents                | <a/b/c/d> | <...>                |
| skills                | <a/b/c/d> | <...>                |
| process               | <a/b/c/d> | <...>                |
| policy-fit            | <a/b/c/d> | <...>                |
| failure-mode-analysis | <a/b/c>   | <...>                |
| improvement           | free-text | <...>                |

## Findings

Each non-default answer becomes a tagged finding. (If none, write "None — all dimensions at default.")

```yaml
- id: F-1
  dimension: <dimension-id>
  summary: "<one line>"
  detail: "<verbatim rationale + evidence>"
  target-tier: <core | project>
  target: <agent/skill name | process>
  change-type: <add | modify | remove | suppress>
  confidence: <low | med | high>
  fold-in: <yes | needs-bulk-review>
```

## Warnings

- <e.g. unknown dimension id in policy.yaml; required practice not defined; gate unsatisfied>
- <or "None">

## Fold-in Candidates (quick reference)

| Finding | Target tier    | Target | Confidence | Fold-in                 |
| ------- | -------------- | ------ | ---------- | ----------------------- |
| F-1     | <core/project> | <name> | <conf>     | <yes/needs-bulk-review> |

## Gradient Scorecard (optional, ON by default)

> _Render this section when `gradient-scorecard` is active in the effective policy (i.e. not suppressed via Tier-2 `disable`). Omit the entire section if disabled._

Fill in using the standalone blank: [`assets/gradient-scorecard-blank.md`](./gradient-scorecard-blank.md). See [`references/gradient-scorecard.md`](../references/gradient-scorecard.md) for the aspect prompts (Q1–Q20), calibration anchors, sensitivity rule, finding rule, and roll-up format.
