# Worked example 7 -- trivial pick collapses to a one-liner

> **Summary**: **OPENQ-framing** ambiguous edge case demonstrating the proportionality guardrail.
> When a pick is obviously dominated -- capability-equivalent options with a single clear winner
> under L2 -- the OPENQ collapses to a one-line rationale. Emitting a full scorecard or lean
> axes block here is over-engineering the framing process itself. Distinct from
> `deep-modules/examples/` depth-scoring examples: this example shows when NOT to run a full
> OPENQ framing, and how to record the result as a labeled ASSUMPTION-*.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** A Planner is naming the new example-index section heading in `design-rubrics`. Two
options arose during drafting: **A** -- `### OPENQ Framing Example Index`; **B** -- `### OPENQ
Framing -- Worked Examples`.

At first, the Planner considers emitting an OPENQ for this. Stage-0 routing fires first.

**Stage-0 routing -- collapse before emission:**

**Outcome 2 test (agent-resolvable design call):** Does one option strictly dominate under the
L2 deep-modules capability-equivalence test?

- Both options produce the same heading content and the same navigable anchor.
- Both are capability-equivalent: an agent navigating to the section gets the same index.
- Under ISC: "OPENQ Framing Example Index" (A) is shorter and more precise -- it names
  the thing directly. "OPENQ Framing -- Worked Examples" (B) is vaguer (the section is an
  index, not just a collection of worked examples -- the *index* is the navigable artifact).
- Under RCK: A carries zero additional knowledge; B introduces a mild ambiguity (is this the
  index of examples, or the examples themselves?). RCK slightly favors A.
- L2 fires: A strictly dominates on naming precision at ~0 ISC (cosmetic naming). The
  capability-equivalence holds (same anchor content either way).

**Collapsing-lens citation:** `deep-modules` capability-equivalence -- A is strictly more precise
at the same capability level.

**Result:** This is NOT a blocking OPENQ. Record as a vetoable `ASSUMPTION-*`:

```
ASSUMPTION-008 (confidence: landslide; blast-radius: trivial; lens: deep-modules naming precision)
-- Section heading: "OPENQ Framing Example Index" (A). Shorter, names the artifact directly
(the index), no ambiguity with the examples themselves. Veto: reply "heading: worked-examples".
```

**Why this matters -- the proportionality guardrail:**

The proportionality rule says: *"A trivial pick collapses to a one-line rationale; do not emit
a full scorecard when the decision is obvious."* Emitting a blocking OPENQ, running a full
Stage-1 ask-worthiness analysis, and producing a scored framing block for a section heading
name would waste a conversation turn, force the user to review a question that has an obvious
answer, and violate the lean-design principle (it would add ceremony with no clarity benefit).

**Anti-pattern this avoids:**

Every naming or placement cosmetic decision that has a sensible default and no downstream
contract impact should be batched or auto-resolved -- not itemized as a blocking OPENQ. The
risk is not zero (a bad name can persist), but the mitigation is a `Veto:` line in the
`ASSUMPTION-*`, not a full framing process.

**Proportionality escape hatch conditions (all must hold):**

1. Options are capability-equivalent (same navigable anchor, same section content).
2. One option clearly dominates under naming precision or another single low-cost dimension.
3. No downstream contract is committed (no existing consumers bind to this heading name yet).
4. The blast-radius is trivial (renaming later costs one find-and-replace).

If ANY of these conditions fails -- e.g., the heading name becomes part of a published URL schema
with existing callers -- the question is no longer trivial and requires full framing.
