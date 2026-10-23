# Worked example 5 -- looks interface-shaping but is scope/policy

> **Summary**: **OPENQ-framing** ambiguous edge case. The question looks like it is shaping a
> caller-facing surface (adding a parameter to an output contract), but the capability-equivalence
> gate reveals it is actually a scope/policy question (the answer adds a new capability, not a
> different shape for the same capability). Misclassifying this as interface-shaping would produce
> confident-but-meaningless proxy scores. Distinct from `deep-modules/examples/` depth-scoring
> examples: this example shows how to use the capability-equivalence gate to catch a
> misclassification trap before running the scorecard.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** A Planner is designing the output format for a skill verdict. The question arises:
*should we add a `format` parameter to the output so agents can request `json` vs `markdown`?*

At first glance this looks **interface-shaping** -- adding a `format` parameter changes the surface
shape. The Planner runs the Stage-2 classifier.

**Stage-2 classification -- the trap:**

> *Does the answer determine how a caller-facing surface is shaped?* -> Yes, adding `format` would
> change the output surface shape.

This passes the interface-shaping *syntax* test -- but the substance test must follow.

**Apply the capability-equivalence gate before scoring:**

```
Gate: Caller = agents consuming the skill verdict output.
      Baseline = Markdown + JSON (both are baseline-competent for agents in this repo).
      Capability held constant = ???
      Equivalence: ???
```

**The gate reveals the misclassification:**

"Capability held constant" requires both options to deliver the *same capability*. But:

- Without `format`: the skill delivers a Markdown-formatted verdict.
- With `format`: the skill delivers a Markdown-formatted OR JSON-formatted verdict.

These are NOT the same capability. JSON output enables downstream programmatic consumption
(structured parsing, tooling integration) -- a capability the Markdown-only option does not
provide. The gate fires **"No"** -- capability equivalence does not hold.

**Consequence:** This is NOT an interface-shaping question. The question is: *do we build
multi-format output at all?* That is a **scope/policy** question (capability inclusion). The
surface shape is a downstream detail.

**Correctly framed OPENQ:**

```
OPENQ-005 (scope/policy -- multi-format output) * BLOCKING
Stakes:    Adds programmatic-consumption capability; blast-radius: low (no existing consumers)
           + confidence: uncertain (neither format is pre-committed)
Lean axes: <lean cost axes -- see design-rubrics OPENQ-framing mode>
Precedent: No ADR commits to a single-format output contract.
Serves:    Downstream tooling integration is a stated future need; not the current plan goal.
a) Markdown only for now -- add JSON in a follow-on plan if tooling need materializes (default)
b) Support both Markdown and JSON output now
```

**Lean axes:**

```
Lean axes: Transition cost = none (no existing consumers to migrate);
           Marginal surface / trajectory = B: rising (each new output field must be handled in
           both renderers, plus a format-negotiation mechanism);
           A: flat (one renderer to maintain);
           Capability-equivalence gate: No -- B adds programmatic-consumption capability.
Confidence: Medium -- tooling integration need is stated but not yet concrete.
Note: AuthorCost = dual-format rendering + output-contract versioning is ~2 extra days
      (informational — not a decision input)
```

**Why the misclassification matters:**

If a Planner had run the four-proxy scorecard on "format parameter vs no format parameter", the
result would have been meaningless -- the two options don't deliver the same capability, so
ISC/ILC/RCK/CHEC comparisons are not comparing like-for-like. A "lower ISC" verdict would have
answered the wrong question (surface shape of a given capability) when the real question was
whether to build the capability at all.

**Verdict (scope/policy):** A (defer) -- flat trajectory, no current consumer to justify the investment. If a concrete tooling integration is identified, reopen as a follow-on.
