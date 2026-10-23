---
name: visual-analogy
description: Design, compare, critique, and iteratively refine visual analogies for slides, diagrams, explainers, and paired failure/mitigation visuals. Use when translating an abstract concept into a metaphor, choosing between analogy candidates, simplifying a busy explanatory image, preserving semantic or physical fidelity during rendering, or applying deep-and-lean criteria to visual communication. Do not use for statistical chart selection (use draco2) or Mermaid syntax and rendering (use mermaid-diagrams).
---

# Visual Analogy

Treat a visual analogy as an interface between a source concept and a viewer. A deep analogy
compresses many load-bearing relationships into a small, coherent visual surface. A lean analogy
uses the fewest marks and words that preserve those relationships.

This skill owns the visual-semantic workflow. It does not own general design-comparison mechanics,
image generation, presentation file formats, statistical charts, or Mermaid syntax.

## Compose the related skills

- Load [`../design-rubrics/SKILL.md`](../design-rubrics/SKILL.md) before presenting two or more
  candidates. It owns lens applicability and comparison framing.
- Load [`../deep-modules/SKILL.md`](../deep-modules/SKILL.md) when comparing analogy surfaces.
  Treat the viewer as the caller, the visual as the interface, and the intended explanation as the
  capability held constant.
- Keep [`../lean-design/SKILL.md`](../lean-design/SKILL.md) active. It owns the
  minimum-that-works ladder and the rule that simplification must not cut a guarantee.
- Load [`../brainstorming/SKILL.md`](../brainstorming/SKILL.md) when the user requests broad
  exploration, several rounds, critics, or multiple metaphor families.
- Load [`../literal-intent-fidelity/SKILL.md`](../literal-intent-fidelity/SKILL.md) when the user
  states a testable criterion or corrects a mapping. Their criterion remains the test.
- Route statistical chart selection to [`../draco2/SKILL.md`](../draco2/SKILL.md) and Mermaid
  authoring or validation to [`../mermaid-diagrams/SKILL.md`](../mermaid-diagrams/SKILL.md).

Use the available image, presentation, document, or browser skills for the final artifact. This
skill governs the analogy, not the rendering backend.

## Meaning contract before imagery

Write a compact meaning contract before proposing a metaphor:

1. **Audience and baseline**: what viewers already know without explanation.
2. **Learning objective**: the one conclusion or mental model the visual must leave behind.
3. **Load-bearing propositions**: facts, relationships, states, directions, and distinctions the
   visual must preserve.
4. **Criterion fidelity**: exact user criteria, terminology, ordering, and scope that must not be
   replaced by an easier proxy.
5. **Permitted simplifications**: details the visual may omit without changing the explanation.
6. **Format constraints**: slide size, pair or sequence structure, approved palette, style, and
   time the audience will have to read it.

If the source concept is not yet stable enough to state this contract, clarify the concept before
choosing an analogy. Do not use a metaphor to conceal conceptual uncertainty.

## Map semantics explicitly

For each candidate, record the mapping before rendering:

| Source concept | Visual element | Relationship or state | Viewer inference |
|---|---|---|---|
| `<concept>` | `<object, position, color, motion>` | `<what the cue means>` | `<intended reading>` |

Every salient visual cue needs one stable meaning. Reusing a color, direction, or object for two
unrelated meanings creates mapping leakage. Realistic imagery also creates a physical contract:
water flows, barriers stop motion, signals agree with gates, containers contain, and arrows point
in the claimed direction. If physical behavior would contradict the lesson, either correct it or
use a deliberately abstract representation.

## Design it twice

For a new analogy or a material reframe, generate at least two structurally different candidates
before converging. Include a direct diagram or non-metaphoric baseline when analogy may add more
interpretation cost than value. A candidate must differ in explanatory structure, not merely color
or illustration style. Do not restart broad exploration for a narrow edit to an approved analogy
unless the correction invalidates its underlying mapping.

Common useful shapes include:

- one system shown in failed and mitigated states;
- a progressive sequence in which each stage adds a control;
- one shared outcome produced by several distinct mechanisms;
- a contained physical system whose parts correspond directly to concepts;
- a diagnostic view that emphasizes how the system knows, rather than dramatizing the failure.

When a failure and its mitigation compete for attention, split them into a pair. The second visual
should build on the first by preserving the same scene and adding only the mitigating mechanism.

## Compare for depth and leanness

Read [references/scorecard.md](references/scorecard.md) whenever two or more candidates survive
initial screening. Hold explanatory coverage constant, then prefer the lower viewer-interface cost.
Apply the hard semantic gates before reading totals.

Read [references/worked-examples.md](references/worked-examples.md) when a concrete pattern would
help distinguish a progression, a shared-outcome diagnostic, or a failure/mitigation pair.

Run the lean ladder in visual terms:

1. Does this idea need an analogy, or would direct depiction be clearer?
2. Can an approved metaphor or visual language already carry it?
3. Can existing objects, positions, or labels carry the new meaning?
4. Can the delivery format's existing grammar carry it?
5. Can one composition do the work?
6. Only then add the minimum new visual machinery.

Do not remove a load-bearing relationship, oracle, boundary, direction, or audience cue merely to
make the image cleaner.

## Specify before rendering

Describe the selected design in text before generating or editing the image. The specification
must name:

- composition and reading order;
- exact text, including capitalization and punctuation;
- semantic role of every color;
- source-to-visual mapping;
- elements to add, remove, and preserve;
- physical or directional constraints;
- explicit avoid-list of plausible wrong readings;
- speaker-note dependency, if any.

If a non-obvious mapping requires a long explanation, improve the visual first. Speaker notes may
deepen an analogy; they must not rescue a contradiction the audience can see.

## Render and revise

Read [references/render-loop.md](references/render-loop.md) before generating an image, editing an
existing visual, or embedding a result in a deck or document.

Treat feedback as evidence about the mapping, not merely as a pixel request. When the user points
out one incorrect cue, inspect every cue produced by the same assumption. Preserve approved parts
with explicit invariants and make the next edit as narrow as the semantic correction allows.

Stop when the visual passes all hard gates, the intended reading wins at presentation scale, and
another iteration would change style rather than meaning.

## Output contract

For design-only work, provide:

1. the meaning contract;
2. candidate descriptions;
3. the visual-analogy scorecard and verdict;
4. the selected text specification;
5. unresolved risks or audience assumptions.

For render work, also provide the final artifact path, the rendering mode or tool family, and the
final prompt or edit brief. Keep temporary files and validation screenshots out of the handoff.
