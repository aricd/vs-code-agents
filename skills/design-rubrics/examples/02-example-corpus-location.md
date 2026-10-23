# Worked example 2 -- example corpus location: single home vs split across skills

> **Summary**: Happy-path **OPENQ-framing** example, scope/policy branch. Demonstrates a clean
> scope/policy classification -- lean cost axes only, no four proxies. The question determines
> *what to build and where to put it*, not how to shape any caller-facing surface. Distinct from
> `deep-modules/examples/` depth-scoring examples: this example shows how to *frame a scope/policy
> OPENQ at planning time* using lean cost axes.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** A Planner is deciding where to put a new worked-example corpus for OPENQ framing.
Two options: **A** -- a single corpus under `skills/design-rubrics/examples/` with one index in
`design-rubrics`; **B** -- split the corpus across `deep-modules/examples/` (interface-shaping
examples) and `lean-design/examples/` (scope/policy examples), with a federating index in
`design-rubrics`.

The OPENQ is: *where do the corpus files live?* This determines what we build and where -- it is
**scope/policy** (feature placement and authoring policy), not an interface-shaping question.
The surface an agent consumes (the index in `design-rubrics`) is the same in both options.

**Classification check:** capability equivalence test -- do both options deliver "a pull-able,
indexed corpus of OPENQ-framing worked examples"? Yes, equally. But this is not interface-shaping:
the answer doesn't reshape any caller-facing surface; it reshapes the file-system layout and
authoring convention. Correctly classified as scope/policy.

```
OPENQ-002 (scope/policy -- example corpus home) * BLOCKING
Stakes:    Affects where corpus files live and authoring convention;
           blast-radius: low  +  confidence: uncertain
Lean axes: <lean cost axes -- see design-rubrics OPENQ-framing mode>
Precedent: deep-modules/examples/ is the established format precedent; no ADR pre-settles
           whether a new framing skill uses the same folder or a new one.
Serves:    "One place to look and maintain" from the plan's Value Statement.
a) Single corpus in design-rubrics/examples/ + one index (default)   b) Split across two folders
```

**Lean axes (full):**

```
Lean axes: Transition cost = none for A (new corpus, no existing files to move); low for B (same);
           Marginal surface / trajectory = A: flat (add one file + one index entry per example);
           B: rising (each new example may require updating two partial indexes, one per folder);
           Capability-equivalence gate: Yes -- both deliver the same indexed corpus to an agent
           looking for framing examples.
Confidence: High -- new corpus, no migration cost, trajectory is observable from the two folder
            models.
Note: AuthorCost = A is lower (one index to maintain vs two; no routing decision per new example)
      (informational — not a decision input)
```

**Per-axis reasoning:**

- *AuthorCost (informational):* A is lower -- one index to maintain vs two; no routing decision per new example.
- *Transition cost:* equal -- brand new corpus in both cases.
- *Marginal surface / trajectory:* A is flat (one file + one line in one index). B is rising --
  each example's type must be assessed to determine the folder, and both partial indexes must
  stay consistent. When a new "boundary" example arises (fits neither folder cleanly), B requires
  a routing judgment and two-index update per addition.
- *Capability-equivalence:* both deliver the indexed corpus. A has flatter trajectory.

**Verdict:** A (single home) -- flat trajectory. B's split adds a routing decision and index-consistency obligation for zero capability gain.

**Recommendation:** A; establish `skills/design-rubrics/examples/` as the single corpus home.
Ensure the index header notes these are OPENQ-framing examples (distinct from
`deep-modules/examples/` depth-scoring examples) to prevent conflation of the two sibling trees.
