# Mini-Retro Memory Model

This file defines how the mini-retro's **two persistent tiers** (plus the ephemeral per-plan artifacts) combine into the **effective policy** the retro evaluates against, and how accumulated findings are reviewed in bulk and folded back into the durable tiers.

## The tiers

### Tier 1 — Core definitions (longest-term)

- **What:** The canonical agent and skill definitions — `vs-code-agents/agents/*.agent.md` and `vs-code-agents/skills/*/SKILL.md` — plus this skill's baseline question bank (`references/question-bank.md`).
- **Durability:** Cross-project, durable. Changing Tier 1 changes behavior **everywhere**.
- **Owner of change:** Deliberate, reviewed edits to the core repo. The mini-retro never edits Tier 1 directly; it only emits `target-tier: core` findings that the bulk-review step later promotes.

### Tier 2 — Project policy (medium-term)

- **What:** A single project-scoped file at `.agent-output/mini-retro/policy.yaml`. It records **this project's modifications** to default agent/skill behavior and to which feedback dimensions matter here.
- **Durability:** Survives across all plans **within the project**; has no effect on other projects.
- **Owner of change:** The project. Edited freely without touching the core repo.
- **Opt-in:** Absence of `policy.yaml` is valid and common. When absent, the mini-retro runs on Tier-1 defaults only and records `policy: tier1-defaults-only`. Never invent Tier-2 requirements a project did not declare.

### Ephemeral — Per-plan artifacts

- **What:** `.agent-output/mini-retro/<plan-id>-mini-retro.md`, one per plan.
- **Durability:** Accumulates over time; this is the raw feedback corpus.
- **Use:** Reviewed in bulk (see below) to find recurring signals worth promoting into Tier 1 or codifying in Tier 2.

## Effective-policy resolution

The mini-retro evaluates reality against the **effective policy**, computed each run:

```
effective = Tier-1 baseline (start from the default asked-set)
            then apply Tier-2 overrides:
              - disable / suppress  → remove a dimension (don't ask, don't flag absence)
              - enable              → add a Tier-1-optional, default-asked:false dimension
              - require             → mark a dimension mandatory; flag any gap as a finding
            then append Tier-2 project-questions (project-specific, never promoted blindly)
```

**Default asked-set (deterministic).** A Tier-1 dimension is included by default when:

- Its `requirement` is `required` (always in the asked-set), **or**
- Its `requirement` is `optional` AND it carries a `default-asked: true` marker.

Optional dimensions with no `default-asked` marker (or `default-asked: false`) are NOT asked unless Tier-2 explicitly `enable`s them. This rule makes the default asked-set unambiguous: an orchestrator resolving Tier-1 alone (no `policy.yaml`) always gets the same set.

**`enable` semantics.** `enable` adds a genuinely `default-asked: false` optional dimension to the asked-set. For dimensions already `default-asked: true` (e.g. `gradient-scorecard`, `failure-mode-analysis`), `enable` is an **idempotent no-op** — the dimension is already asked; no change results.

**`disable` / `suppress` semantics.** These are aliases of the existing opt-out keyword. `disable` removes any dimension — required or optional, default-on or not — from the effective asked-set for this project. For an ON-by-default dimension such as `gradient-scorecard`, a downstream project opts out with a single Tier-2 line: `dimensions.gradient-scorecard: disable`. `disable` and `require` are mutually exclusive per dimension-id; `disable` dominates (removal makes `require` moot).

Precedence rule: **Tier 2 always wins over Tier 1** for the _scope of this project_. Tier 2 can relax (`disable`) or tighten (`require`) any Tier-1 dimension. Tier 2 cannot, however, mark a finding as folded into Tier 1 — promotion to Tier 1 is only ever done by the deliberate bulk-review step.

### Worked example — failure-mode analysis

The dimension `failure-mode-analysis` exists in the Tier-1 question bank as **optional, `default-asked: true`** (asked by default; absence is not a defect; Tier-2 can change either).

- **Small personal project:** `policy.yaml` sets `failure-mode-analysis: disable`. The mini-retro neither self-assesses it nor flags that the plan skipped failure-mode work. Zero friction; the project never has to care.
- **Regulated project:** `policy.yaml` sets `failure-mode-analysis: require` with a `practice` note like _"Planner MUST delegate to Analyst to review the plan and determine the proper failure mode and associated risk for each task."_ The mini-retro then checks the execution evidence for that delegation and, if missing, records a high-confidence `target-tier: project`, `change-type: modify`, `target: Planner` finding that the required practice was not honored.

### Worked example — gradient scorecard opt-out

The dimension `gradient-scorecard` is **optional, `default-asked: true`** — it ships in the asked-set for every consumer without any Tier-2 action. A downstream project that does not want the 20-question scoring overhead opts out with a single Tier-2 line:

```yaml
dimensions:
  gradient-scorecard: disable
```

This removes the gradient dimension from that project's effective asked-set. The dimension is not asked and its absence is not flagged. The existing categorical dimensions are unaffected.

## Finding tags (what makes bulk review tractable)

Every finding the mini-retro records carries a fixed set of tags so the accumulated corpus is greppable:

| Tag | Values | Purpose |
| --- | --- | --- |
| `target-tier` | `core` \| `project` | Where the change belongs |
| `target` | agent/skill name, or `process` | What to change |
| `change-type` | `add` \| `modify` \| `remove` \| `suppress` | Nature of the change |
| `confidence` | `low` \| `med` \| `high` | Signal strength from this single plan |
| `fold-in` | `yes` \| `needs-bulk-review` \| `upstream-candidate` | Quick win vs needs corroboration across plans vs a project-tier practice minted specifically to harden a shared skill's rule |
| `patches` | a shared (Tier 1) artifact path or rule name -- required when `fold-in: upstream-candidate` | Names the shared skill/rule a project-tier practice was minted to harden, so promotion does not lose the connection back to the shared artifact it patches |

## Bulk review & fold-in lifecycle

1. **Accumulate.** Each plan emits one `<plan-id>-mini-retro.md` into `.agent-output/mini-retro/`.
2. **Aggregate (periodic).** A maintainer (or a future aggregation skill/agent) scans the corpus — e.g. group `target-tier: core` findings by `target` and `change-type`, weight by `confidence`, and surface anything recurring across multiple plans.
3. **Promote.**
   - `target-tier: project` findings → codify into the project's `policy.yaml` (Tier 2).
   - **`fold-in: upstream-candidate` findings are not ordinary `target-tier: project` findings.** A project-tier practice minted specifically to harden a shared skill's rule (a `policy.yaml` `practices` entry, a work-around comment, or any project-local fix built to compensate for a gap in a Tier-1 skill) risks staying stranded at the project tier with no record of what it was built to patch. Tag it `fold-in: upstream-candidate` with a `patches: <shared-artifact>` marker naming the Tier-1 skill/rule it hardens. Aggregate `upstream-candidate` findings by their `patches` target across plans and prioritize them for Tier-1 promotion once corroborated, rather than letting the `target-tier: project` codify-into-`policy.yaml` step consume them and lose the shared-artifact link.
   - `target-tier: core` findings with cross-plan corroboration → deliberate, reviewed edits to the canonical agent/skill repo (Tier 1). Cite the plan ID that raised the finding being promoted — the promoted change traces back to the mini-retro artifact that surfaced it.
   - **A finding that matches an existing `failure-modes/INDEX.md` row is an increment, not a refile.** Before promoting a `target: process` finding as a new row, consult the registry (same consult-and-append hook `document-lifecycle`'s Agent Self-Check runs); a match bumps that row's `recurrence_count` and `last_seen` and appends the citing plan ID to its evidence trail, rather than minting a fresh entry that would fragment the recurrence signal across duplicate rows.
4. **Close the loop.** Once a finding is folded in, the recurring signal disappears from future mini-retros (the behavior is now baseline), which is the success signal for the whole mechanism.

A single high-confidence finding may be promoted immediately (`fold-in: yes`); most should wait for cross-plan corroboration (`fold-in: needs-bulk-review`) to avoid over-fitting the core repo to one plan's idiosyncrasies.
