# Worked example 6 -- high-blast scope/policy (deprecation posture with existing consumers)

> **Summary**: **OPENQ-framing** ambiguous edge case. High blast-radius does NOT imply
> interface-shaping. This example shows a high-blast scope/policy OPENQ (deprecation posture
> for the plan template, with existing agent consumers) that is correctly framed with lean
> cost axes -- not with the four proxies. The classifier is orthogonal to blast-radius. Distinct
> from `deep-modules/examples/` depth-scoring examples: this example shows how to resist the
> temptation to use four proxies when the question is about a policy commitment with existing
> consumers.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** The plan template has been updated from a 14-section to a 16-section format. Several
active agents (Planner, Critic, Implementer, QA) currently emit documents in the 14-section
format. The OPENQ: *what is our deprecation posture for the 14-section format -- migrate atomically
in this release, or maintain a 12-month parallel-support window?*

**The trap -- why this looks interface-shaping:**

The plan template IS a caller-facing surface: agents read the template to know what to produce,
and the validate script enforces the schema. Changing the deprecation posture changes something
about how the surface is managed. A Planner might reach for the four-proxy scorecard here.

**Stage-2 classification -- the diagnostic:**

> *Does the answer determine how a caller-facing surface is shaped?* -> No. The surface shape
> (the 16-section template) is already decided -- the new sections are defined either way. The
> question is: *what do we commit to support?* -- that is a **policy decision** (deprecation
> posture), not a surface-shaping decision.

**Capability-equivalence gate:**

- A (atomic migration): the plan template surface moves to 16 sections immediately; 14-section
  documents become invalid.
- B (parallel support): the plan template surface accepts both 14 and 16 sections during the
  window; 14-section documents remain valid.

Do A and B deliver the same surface capability? **No** -- B delivers continued support for
14-section documents during the window, a capability A does not have. The gate fires "No" on
equivalence. Do NOT score with four proxies.

**Correctly framed OPENQ:**

```
OPENQ-006 (scope/policy -- 14-section deprecation posture) * BLOCKING
Stakes:    Existing agents emit 14-section plans; breaking them silently is a hard failure;
           blast-radius: high (BOUNDARY: plan-template schema; existing consumers)
           + confidence: uncertain (both postures are defensible)
Lean axes: <lean cost axes -- see design-rubrics OPENQ-framing mode>
Precedent: No ADR pre-settles deprecation posture for template format changes.
Serves:    Agent continuity during the template transition period.
a) Atomic migration: migrate all active plans before shipping the new validator (default)
b) Parallel support: maintain 14-section compatibility for 12 months, then hard-cut
```

**Lean axes:**

```
Lean axes: Transition cost = A: requires all active plans migrated first (coordination cost,
           proportional to active plan count); B: no immediate migration needed -- deferred;
           Marginal surface / trajectory = A: flat from day one; B: rising during the window
           (every new plan must still decide which format to emit; dual-format overhead
           accumulates until the window closes);
           Capability-equivalence gate: No -- B provides continued support for 14-section format
           during the window; A does not.
Confidence: Medium -- transition coordination cost depends on active plan count (observable).
Note: AuthorCost = A: 0 extra code (single-format validator); B: ~3 days (dual-format parsing
      + compatibility test suite + deprecation-warning plumbing) (informational — not a decision input)
```

**Why high-blast does NOT make this interface-shaping:**

The blast-radius classification answers *what is at risk* (existing consumers could break).
The interface-shaping vs scope/policy classification answers *what kind of decision this is*
(shaping a surface vs committing to a support policy). High-blast scope/policy questions are
common -- they just require lean cost axes and careful attention to transition cost, not a
proxy scorecard.

**Running the four proxies here would be incorrect:** ILC/ISC/RCK/CHEC measure the *cost of
a surface to its callers*, not the *cost of a policy commitment to the organization*. Applying
them to a deprecation-posture question would produce numbers with no referent.

**Verdict:** A (atomic migration) -- flat trajectory, no deferred removal obligation. Justified when active plan count is small (<=5) and coordination is feasible in one
pre-deployment pass.

**High-blast mitigation:** Announce the migration requirement 1 sprint ahead; enumerate active
in-flight plans and assign owners. This converts the blast-radius from "surprise" to "known
one-time coordination cost."
