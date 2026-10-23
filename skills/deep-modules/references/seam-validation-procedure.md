# Seam-Validation Procedure

> **Back-link**: [../SKILL.md](../SKILL.md) § "What a depth verdict does NOT establish"

A depth score is auditable but bounded. It tells you whether a surface is *justified*; it does
**not** establish seam fidelity. This procedure runs **after** a depth verdict, for any design
touching ≥2 existing seams.

---

## When to run

Run this procedure when:
- the depth verdict recommends a design that crosses ≥2 existing seams; and/or
- the scored design emits or consumes a shared signal (a contract field, a backlog row, a
  correction emitted across a module boundary).

A clean `0 new surface` verdict can be correct *and* blind to all three failure modes below.

---

## The three failure modes this catches

**1. Seam does not exist.** The emit-point / extension-point / boundary named in the scorecard
is absent in the actual code. The verdict scored a plausible seam that was never built. A previous
session shipped a depth verdict over a non-existent seam, producing a correct score and a broken
implementation.

**2. Ownership is not singular.** A shared signal (a correction, a contract field, a backlog row)
has its *definition* split across two modules — its kind declared in one, its emit-point in
another. This is ILC even when a no-duplication contract test passes. The no-duplication test
catches *collisions* (both sides declare it) but **not** *orphans* (each side assumes the other
owns it). Orphaned ownership produces a passing test and silent gaps at runtime.

**3. Cross-unit sequencing does not hold.** The units this design depends on are not yet
committed or ordered so the boundary can be built as scored.

---

## Procedure

For each seam the design crosses:

**Step 1 — Confirm the seam exists.** Read the live code at the named emit-point /
extension-point. Verify it is actually present. If absent: HARD BLOCK — the seam must be built
before the design can be implemented as scored.

**Step 2 — Confirm single ownership.** For each shared signal the design produces or consumes:
- Name the signal and its kind (type, field, correction, event name).
- Identify which module declares its *kind* and which module declares its *emit-point*.
- Verify they are the **same** module (single owner for both).
- If they are different modules: assign one owner for both, flag the split as ILC, and record
  the ownership assignment in the plan.

**Step 3 — Confirm sequencing.** For each module this design depends on (as a producer or
consumer), verify that module is committed or sequenced *before* this design's implementation
boundary. If any depended-on module is uncommitted or unordered: return to Planner to add the
sequencing precondition before implementation.

---

## Output

For each seam checked, record:

```
Seam: <name or description>
  Step 1 — exists: yes / no [if no: HARD BLOCK]
  Step 2 — single owner: yes / no [if no: assigned owner = <module>; ILC flagged]
  Step 3 — sequencing holds: yes / no [if no: add precondition before implementation]
```

A seam-validation pass with all three steps confirmed is **necessary but not sufficient** for
correctness — it does not replace testing, but it removes a class of integration failures that
depth scores cannot see.
