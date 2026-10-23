# Worked example 4 -- backcompat shim scope: include in this plan or defer?

> **Summary**: **OPENQ-framing** variation demonstrating the scope/policy branch with a
> trajectory analysis. The question is whether to include a backcompat shim layer in the current
> plan. This is scope/policy (capability inclusion decision), not interface-shaping. The lean
> trajectory axis is the deciding factor: the shim has a falling marginal cost once built but
> carries immediate authoring and testing overhead. Distinct from `deep-modules/examples/`
> depth-scoring examples: this example shows how to frame a capability-inclusion decision at
> planning time.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** A Planner is working on a plan to update the plan template from 14 to 16 sections.
Several agents (Planner, Critic, Implementer) emit plans against the existing 14-section schema.
Two options for this plan's scope: **A** -- add the new sections and require immediate adoption
(no shim); **B** -- add the new sections AND include a backcompat shim that allows the 14-section
format to continue loading until a follow-on migration plan is executed.

The OPENQ is: *do we build the shim in this plan?* This determines what capability we build --
**scope/policy**. The surface shape of the new template sections is the same in both options; the
question is about what else to build alongside.

**Classification check:** Is this interface-shaping? No -- both options produce the same new
16-section template surface. The difference is whether backcompat preservation is a
*capability delivered in this plan*. Capability-equivalence test: A and B deliver different
capabilities (B adds backcompat preservation). The gate fires "No" for equivalence -- this is
scope/policy, not interface-shaping. Do NOT score with four proxies.

```
OPENQ-004 (scope/policy -- backcompat shim inclusion) * BLOCKING
Stakes:    Affects agents with in-flight plans in the 14-section format; blast-radius: med
           (existing consumers of the template validator) + confidence: uncertain
Lean axes: <lean cost axes -- see design-rubrics OPENQ-framing mode>
Precedent: No ADR requires shims for plan template changes; prior template changes (v1.0->v2.0)
           migrated atomically without shims.
Serves:    Existing in-flight plans must not break when the new template validator ships.
a) No shim -- require adoption by all active plans before this ships (default)
b) Include a backcompat shim for 14-section plans in this plan
```

**Lean axes (full):**

```
Lean axes: Transition cost = without shim: in-flight plans must be migrated manually before
           deploy -- low if there are <=3 active plans; with shim: no migration needed now but
           the shim code becomes an ongoing maintenance obligation until removed;
           Marginal surface / trajectory = shim: rising during the transition window (every
           plan addition may trigger dual-format checks); without shim: flat (single format from
           day one; migration is a one-time fixed cost);
           Capability-equivalence gate: No -- B adds backcompat preservation capability; A does
           not.
Confidence: Medium -- number of active in-flight plans (the transition cost driver) is observable
            but not enumerated here; shim removal timing is uncertain.
Note: AuthorCost = shim adds ~2-3 days (parsing, dual-format validator, test coverage for both
      paths); no shim is 0 additional days (informational — not a decision input)
```

**Per-axis reasoning:**

- *AuthorCost (informational):* B is significantly higher (shim + dual-path testing vs none).
- *Transition cost:* A has a one-time migration cost that scales with the count of active plans.
  B defers that cost but accumulates shim maintenance cost until explicitly removed. If active
  plans are few (<=3), A's migration cost is lower than B's shim cost over any horizon.
- *Marginal surface / trajectory:* A is flat (single format forever). B is rising during the
  shim window (dual-format complexity); once removed, it reverts to flat. But removal requires
  a follow-on plan -- a deferred cost that is easy to forget.
- *Capability-equivalence:* No -- B adds a genuine capability (backcompat preservation), which
  is why the cost is real and not just complexity overhead.

**Verdict:** A (no shim) -- flat trajectory from day one, no deferred removal obligation. Justified if active in-flight plans are few and can be migrated in one pass before
deploy.

**Qualification:** If active plans number >5 or migration window is constrained by parallel
sprint work, B is defensible -- the shim amortizes across a larger transition population.
The key evidence needed: count active in-flight plans before committing to A.

**Recommendation:** A by default; verify active plan count before finalizing. If >5 active plans,
revisit with B or plan a pre-migration sweep as a predecessor task.
