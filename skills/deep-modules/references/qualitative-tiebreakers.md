# Qualitative Tie-Breakers — Naming Precision and Obscurity

> **Back-link**: [../SKILL.md](../SKILL.md) § "Qualitative tie-breakers"
>
> **Note on Hard-to-Describe**: The first tie-breaker (Hard-to-Describe) has been promoted to a
> **required ISC-honesty check** in Block 1 of every scorecard. Its definition and application
> rule live inline in the main SKILL.md. This file documents the remaining two tie-breakers.

These checks fire **only when the counts tie (within ~1) or Confidence is Low**. They never
override a clear count delta — a design that is 14 vs 4 on InterfaceCost does not get rescued
because it has a nicer name.

---

## 2. Naming Precision (Vague Name / Hard to Pick Name)

**Test.** Try to give each design's central method, type, element, or section a precise, intuitive
name. Ask: "What is the single clearest name for what this thing does?"

- A name that **comes easily and reads cleanly** signals a clean abstraction — the boundary is
  in the right place, the responsibility is singular.
- A name that **stays vague** (`data`, `process`, `handle`, `manager`, `item`) signals the entity
  is doing two things or sits on the wrong boundary.
- A name that you can **only make accurate by making it long and compound**
  (`UserSessionStateTransitionEventHandler`) signals the entity has accreted multiple concerns.

**Rule.** Prefer the design that names easily and precisely. The naming difficulty is evidence that
the boundary is wrong — not a reason to go with the vaguely-named design, but a signal to re-cut.

**Non-code surfaces.** For sections, folders, or templates: try to describe the section's purpose
in a short, precise title. A section that resists a clear title is the documentation-world
equivalent of a class that resists a clear name — the boundary is likely wrong.

**Why this comes second.** Naming difficulty often reflects the same information as Hard-to-Describe
(both signal the abstraction is wrong) but at a coarser granularity. Use naming as a
quick first screen and Hard-to-Describe as the definitive ISC cross-check.

---

## 3. Obscurity / Unknown Unknowns

**Test.** For one representative *future* change, ask: can a competent maintainer make it
*correctly* by reading only the code or content at and near the change site?

Count the *distant* locations they must also consult or just *know about* with nothing local
pointing there. Fewer is deeper.

**What "distant" means.** A distant location is one where:
- nothing at the change site *links* to it (no `import`, no `see also`, no cross-reference);
- yet getting the change right requires knowing about it;
- a competent maintainer might miss it and produce a subtly broken result.

**Why this is the hardest tie-breaker.** It looks past the interface into maintainability — it
guards against a tiny-interface module that is an unreadable tangle inside (*depth-on-paper*).
Depth of interface ≠ clarity of implementation. A god-module with a one-method interface and an
unmaintainable interior scores deep on the counts but is a maintenance trap. This tie-breaker
catches that.

**Rule.** When two designs tie on counts, prefer the one with fewer unknown unknowns. If a design
has a smaller interface but a denser interior where changes require knowing distant facts, the
obscurity score can override the count tie.

**Caveat.** This is the one check that looks *inside* the module. Apply it only when counts tie
or confidence is Low — it is not a reason to prefer a shallower design that has a more readable
interior. The module's interior complexity is the *point* of a deep module, provided it is
*encapsulated* (unknown unknowns are about facts the *caller or maintainer must know to use/change
the system*, not about the complexity of the implementation itself).

---

## When all three tie-breakers also tie

If Hard-to-Describe, Naming, and Obscurity all tie (or are all inapplicable), record
`Confidence: Low` and let the simpler implementation decide. Do not manufacture a winner from
insufficient evidence — that is the false-precision failure mode this skill guards against.
