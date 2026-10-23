# Visual analogy scorecard

Use this scorecard after generating at least two structurally different candidates. It adapts the
deep-module idea to a visual interface without replacing the canonical comparison contract in
`design-rubrics`.

Use the [`design-rubrics` compact decision template](../../design-rubrics/SKILL.md#compact-decision-template)
as the comparison envelope, including its required lens-applicability declaration and hazard line.
Insert the visual counts below as the domain-specific evidence block; do not emit this reference's
compact table as a standalone substitute for the canonical framing.

## Gate

Declare before counting:

- **Viewer and baseline**: who reads the visual and what vocabulary or conventions they already
  command.
- **Capability held constant**: the explanation every candidate must deliver.
- **Coverage**: the same list of load-bearing propositions for every candidate.
- **Equivalence**: `Yes`, `Shared-only`, or `No`. Normalize before scoring when it is not `Yes`.
- **Growth unit**: the concept, relationship, state, panel, or audience segment the visual family
  may need to add later. State `none` for a one-off visual.
- **Confidence**: High, Medium, or Low, with the evidence basis.

## Hard gates

Evaluate these before totals. A failing candidate does not win on simplicity.

| Gate | Pass condition |
|---|---|
| Semantic fidelity | Every required proposition survives without substitution or reversal. |
| Relationship fidelity | Direction, containment, sequence, causality, and state agree with the source. |
| Physical coherence | Realistic objects behave plausibly unless the abstraction is visibly deliberate. |
| Audience fit | Required knowledge does not exceed the declared baseline without explanation. |
| Criterion fidelity | User-stated terminology, population, or acceptance criterion remains intact. |
| Legibility | The intended reading remains available at presentation or delivery scale. |

## Viewer-interface counts

Count each observed burden once, using the first matching row from top to bottom.

| Order | Proxy | Count when | Deep-modules analogue |
|---:|---|---|---|
| 1 | **AR**: Ambiguous Readings | A plausible wrong reading requires the viewer or presenter to recover. | CHEC |
| 2 | **ML**: Mapping Leakage | A cue implies an unintended mechanism, duplicates one decision in conflicting cues, or exposes irrelevant implementation detail. | ILC |
| 3 | **VS**: Visual Surface | A distinct visual group, label, legend rule, state, or interaction must be parsed. | ISC |
| 4 | **VK**: Viewer Knowledge | Correct interpretation requires knowledge above the declared audience baseline and the visual does not supply it. | RCK |

`AnalogyCost = AR + ML + VS + VK`

Hold explanatory coverage constant. The candidate with lower `AnalogyCost` is deeper because it
delivers the same meaning through a smaller viewer-facing interface. List the items behind every
count; bare numbers are invalid.

### Cross-checks

- **One-sentence mapping**: describe how the analogy works in one complete sentence. A long or
  exception-heavy sentence means VS or VK is undercounted.
- **Speaker-note tax**: count meanings the presenter must repair or introduce verbally before the
  picture works. Clarifying depth is acceptable; repairing the picture is not.
- **Change amplification**: count how many distinct cues must change when one source concept
  changes. More than one may indicate duplicated mapping.
- **Common-reading tax**: count cues needed only for rare edge cases but imposed on every viewer.

## Lean counts

Record these beside `AnalogyCost`; do not add them to it.

- distinct visual groups;
- distinct text groups;
- legend or key entries;
- decorative elements carrying no mapped meaning;
- new elements added relative to an approved prior visual;
- lean ladder rung reached.

## Trajectory

For a visual family, report the marginal viewer surface per growth unit:

- `Delta VS`, `Delta ML`, `Delta VK`, or `Delta AR` for one new growth unit;
- `[Observed, n=3]` when three comparable visuals exist, otherwise `[Projected]`;
- slope: flat, rising linear, rising steep, or compounding;
- crossover when a larger but flatter visual system competes with a smaller but growing one.

For a one-off image, state `Growth unit: none - one-off visual, no trajectory`.

## Compact comparison

```markdown
Viewer and baseline: <audience; what they already know>
Capability held constant: <explanation every option delivers>
Coverage: <load-bearing proposition list>
Equivalence: <Yes | Shared-only | No>
Growth unit: <unit + current count | none - one-off visual>
Confidence: <High | Medium | Low - why>

| Dimension | Option A | Option B | Direction |
|---|---:|---:|---|
| Hard gates | pass/fail | pass/fail | all pass |
| AR | <items = n> | <items = n> | lower |
| ML | <items = n> | <items = n> | lower |
| VS | <items = n> | <items = n> | lower |
| VK | <items = n> | <items = n> | lower |
| AnalogyCost | n | n | lower |
| Text groups | n | n | lower, after coverage |
| Visual groups | n | n | lower, after coverage |
| Speaker-note tax | n | n | lower |
| Marginal surface | <delta + label> | <delta + label> | flatter |

Verdict: <winner and the itemized reason>
Blind spot: <what the visual review has not established>
```

Do not manufacture a weighted total from mixed qualitative and quantitative rows. Hard gates
exclude; `AnalogyCost` compares viewer burden; lean counts explain how much artifact mass remains.
