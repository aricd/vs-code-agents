# Worked example 3 -- agent output contract: normalized equivalence (Shared-only gate)

> **Summary**: **OPENQ-framing** variation demonstrating the "Shared-only" capability-equivalence
> case. When option B adds capabilities beyond option A, the gate fires "Shared-only" -- score
> only the shared capability, flag B's extras for justification, and recommend unbundling rather
> than choosing A or simplifying B. Distinct from `deep-modules/examples/` depth-scoring
> examples: this example shows how the capability-equivalence gate changes OPENQ framing when
> the two options are not fully equivalent.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** A Planner is deciding the output contract shape for a Critic agent. Two options:
**A** -- emit a structured verdict block only (findings list + verdict + confidence);
**B** -- emit verdict block + all raw evidence items enumerated + a narrative explanation paragraph.

The OPENQ is: *what does the Critic's output contract include?* This shapes the surface downstream
agents (Code Reviewer, QA) consume -- **interface-shaping**.

```
OPENQ-003 (interface-shaping -- Critic output contract scope) * BLOCKING
Stakes:    Shapes the surface Code Reviewer + QA bind to; downstream agents must parse this;
           blast-radius: med  +  confidence: uncertain (no existing consumers yet)
Deeper:    <compact deep-module scorecard -- see design-rubrics OPENQ-framing mode>
Precedent: No ADR pre-settles the Critic output contract shape.
Serves:    Downstream agents need enough structure to act on findings; not more.
a) Verdict block only (default)   b) Verdict block + raw items + narrative paragraph
```

**Gate: run before scoring.**

```
Gate: Caller = Code Reviewer and QA agents consuming the Critic output.
      Baseline = Markdown + structured label conventions (baseline for agent callers in this repo).
      Capability held constant = receive actionable findings to act on.
      Equivalence: Shared-only -- both deliver actionable findings (shared); B adds raw evidence
      enumeration and narrative (extras). Score shared capability only.
Growth unit: evidence field kind (the Critic's reasoning surface grows as new check types land).
Confidence: Medium -- no real call sites yet; extras have unknown consumers.
```

*Note the interaction with the Shared-only gate: the trajectory is scored on the **shared**
capability, exactly as the base counts are. A "Mostly" equivalence narrows what gets a trajectory
row; it never exempts the comparison from having one.*

**Normalize first -- score shared capability only.**

B's extras: (1) raw evidence items enumerated separately, (2) narrative paragraph. Neither current
consumer (Code Reviewer, QA) is known to require these; they are extras. Enumerate each extra and
ask: does a *current* caller require this capability? If not, the extra is unjustified surface.

**Scorecard (shared capability: receive actionable findings):**

```
All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option              | CHEC | ILC  | ISC  | RCK  | ‖ | TOTAL | ‖ | Growth/req     | Slope           | Attention                                            |
|---------------------|-----:|-----:|-----:|-----:|:-:|------:|:-:|:--------------:|:---------------:|:-----------------------------------------------------|
| A: verdict only     |  (.) |  (.) |  (.) |  (.) | ‖ |   (.) | ‖ | 0 [Projected]  | flat            | --                                                   |
| B: verdict + extras |  (.) | (+1) | (+2) | (+2) | ‖ |  (+5) | ‖ | +1 [Projected] | rising (linear) | ! dominant: RCK(+2); ILC(+1): evidence schema leaks  |
```

**Trajectory reasoning:** every new evidence field kind the Critic learns to emit becomes another
field B's consumers must decide to read or ignore (RCK +1 per kind), because the raw evidence
schema is part of B's public surface. A's verdict block absorbs new evidence kinds behind the same
synthesized shape -- Δ = 0. Both `[Projected]`; the Critic has no addition history to count yet.
**Crossover: not applicable** -- A is both lower-base and flatter, so A dominates.

**ILC (B=1):** raw evidence items are an intermediate representation of the Critic's internal
reasoning -- leaking it into the output surface means callers become coupled to the evidence
schema, which may change as the Critic's reasoning evolves.

**RCK (B=2):** callers must learn (1) which evidence fields to read vs ignore for their task,
and (2) how the narrative relates to the verdict (is it additive? Can it contradict the structured
verdict?). Both are implicit contracts above baseline.

**ISC (B=3):** verdict block (1 concept) + raw items schema (1 concept) + narrative field (1 concept).

**Per-guideline judgment:**

- *Pull complexity down:* A wins -- synthesizing raw evidence into a verdict is the Critic's job.
  B pushes the synthesis decision partly back to the caller.
- *General + common case simple:* A wins -- B overexposes: the common path (read the verdict, act
  on findings) must engage two fields that exist only for rare or diagnostic needs.
- *Errors defined out:* equal.
- *Complementary code together:* A wins -- raw evidence and verdict are complementary; keeping them
  merged forces synchronized changes, but B's schema is already synthesized into the verdict
  block. Separating them creates a split that requires callers to reconcile two representations.

**Verdict for shared capability:** A is deeper (1 vs 6).

**Recommendation:** Keep A as the core output contract. Expose raw items and narrative as
**opt-in extras** (e.g., a `details: true` flag or a separate verbose endpoint) so the rare
diagnostic need is served without charging every caller. This is the *unbundle* recommendation
-- neither "pick A and drop the extras" nor "simplify B in place" -- the extras have a use case;
they just should not burden the common path.

The trajectory row also sharpens *why* unbundling is the right shape rather than a compromise:
behind an opt-in flag, new evidence field kinds land on the rare path only, so the common path
stays flat as the Critic's reasoning grows. Bundled, every new kind taxes every caller forever.
