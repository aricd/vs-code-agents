# Brainstorming Topologies

Use this reference when the user asks for multiple rounds, multiple delegations, binary pairing, blind analysis, critic structures, or large-scale exploration.

## Shared Role Vocabulary

| Role | Job |
|---|---|
| `analyst` | Explore one option family, assumption set, domain lens, or evidence path. |
| `critic` | Compare artifacts, find flaws, test completeness, and reject weak reasoning. |
| `skeptic` | Try to falsify the frontrunner or consensus frame. Mandatory for important sessions. |
| `synthesizer` | Merge compatible findings, preserve dissent, and prepare convergence. |
| `empiricist` | Produce measurements, prototypes, traces, or other evidence. |
| `domain-specialist` | Apply a named body of expertise or stakeholder lens. |

## `linear-cycles`

Best for a single hard design fork with moderate complexity.

Default shape:

```
Round 0: foundation
Round 1: expand, expand, critic
Round 2: deepen, deepen, critic
Round 3: prune, evidence, skeptic
Round 4: convergence-only synthesis + GO/NO-GO critic
```

Use one shared ledger or per-round artifacts. Every round reads the foundation and prior synthesis.

## `binary-bracket`

Best when the user wants pairwise analyst structures or very large scale. Local synthesis keeps the final artifact readable.

Default shape:

```
Round 1:
  Pair A: analyst A1 + analyst A2 -> critic A3 -> artifact A
  Pair B: analyst B1 + analyst B2 -> critic B3 -> artifact B

Round 2:
  artifact A + artifact B -> critic C1
  independent analyst C2 explores missing space
  synthesizer C3 -> artifact C

Repeat:
  pair artifacts, criticize, merge, and carry forward only compact state
```

Scaling:

- For 8-16 delegations, use two or four brackets.
- For 20+ delegations, create a bracket tree with intermediate critics.
- For 100-round sessions, checkpoint every 5-10 rounds and preserve only compact state between macro-rounds.

Rules:

- Keep at least one independent artifact per macro-round so the bracket does not only refine its own consensus.
- Require the critic to list what changed after falsification.
- Preserve minority reports when they expose a real axis, even if they lose the current scorecard.

## `tournament-bracket`

Best when the user wants a fixed-size, seeded elimination bracket and wants divergence re-injected at every tier rather than only converging. Distinct from `binary-bracket`: the field is a power of two, pairing is strict, and every consolidation is immediately followed by a fresh analyst re-expansion.

Default shape (8 seeds):

```
Tier 0 (expand):      analyst x8 explore independent approaches -> 8 reports
Tier 1 (consolidate): critic merges each pair -> 4 reports
Tier 2 (re-expand):   analyst deepens each merged report -> 4 reports
Tier 3 (consolidate): critic merges each pair -> 2 reports
Tier 4 (re-expand):   analyst deepens each merged report -> 2 reports
Tier 5 (consolidate): critic merges the pair -> 1 report
Tier 6 (review):      final analyst reviews and closes -> convergence artifact
```

Rules:

- Re-expansion analysts must add new options, evidence, or resolved OPENQs, not just polish. If a tier adds nothing, collapse early.
- Each consolidating critic lists what was merged, what was killed, and why.
- Preserve minority reports that expose a real axis, even when eliminated.
- Carry forward only compact state between tiers.
- Scale by choosing seeds = 2^n (4, 8, 16, ...); tiers = 2n + 1.

## `delphi-blind`

Best when independence matters more than build-on-prior learning.

Shape:

```
N blind analysts receive the same foundation and no sibling artifacts.
Synthesizer clusters findings.
Critic checks whether clusters are real or phrasing artifacts.
Optional second round sends only the cluster map, not raw sibling outputs.
```

Use for stakeholder discovery, risk enumeration, opportunity discovery, or when early consensus would be dangerous.

## `tiered-adversarial`

Best for the biggest, most entangled architecture problems.

Shape:

```
Phase 0: historical/context survey
Tier A/B/C: propose variants
Tier A/B/C: critique variants
Tier A/B/C: consolidate variants
Cross-tier synthesis: one ship-set
Final critic: scorecard + OPENQ audit
```

Use tiers for materially different blast-radius levels, architectural layers, or implementation strategies. Collapse to a coherent ship-set, not a menu.

## `campaign`

Best when the honest output is a prioritized backlog rather than one decision.

Shape:

```
N blind analysts inspect distinct slices or question sets.
Synthesizer normalizes repeated opportunities.
Critic checks duplicates, evidence, and confidence bands.
Output: banded backlog + follow-on decision pass.
```

Campaign output is measurement, not closure. Always say what decision pass should follow.

## `direct`

Best for low-risk ideation. Keep it small:

```
options -> tradeoffs -> recommendation -> next step
```

Even in direct mode, use a brief skeptic paragraph before recommending.
