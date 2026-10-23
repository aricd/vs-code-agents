# Derived Counts — CCT and CA: Full Mechanics

> **Back-link**: [../SKILL.md](../SKILL.md) § "Two derived counts (CCT and CA)"

These two derived counts are **not** added to `InterfaceCost`; they are reported alongside it when
relevant to the comparison. They are used by specific guidelines (CCT by guideline 2, CA by
guideline 4) and do not change the core depth verdict.

---

## CCT — Common-Case Tax

**Definition.** Of the interface items a caller of the **single most common task** must engage,
how many exist only to serve *rarer* tasks? Wrapper objects to construct, flags to set, setup
calls, types to learn that the common path does not need.

CCT > 0 is the signature of **overexposure** (guideline 2). The target for the common case is
**zero-config**: the right thing happens without the caller asking. CCT slices ISC+RCK through the
common case; it is *not* added to the total, it is reported alongside it.

**Counting procedure:**
1. Identify the single most common task (be explicit — name it).
2. List all ISC and RCK items the caller must engage to perform that task.
3. For each item, ask: "Does this item exist only to serve tasks *other* than the common one?"
4. Count the items that answer "yes" — that is CCT.

**CCT = 0** means the common case is zero-config (the right thing happens by default). This is the
target.

**CCT > 0** means the caller pays a tax for rare features on every common call. The fix is usually
to make the rare capability an opt-in that adds ~0 common-case surface.

**Example (from [examples/08-overexposure.md](../examples/08-overexposure.md)):** A logger that
requires the caller to construct a `FormatterConfig` and a `SinkRegistry` object even for basic
`log("message")` calls has CCT = 2 (those two objects exist for rare formatting/routing use cases
that most callers never use).

---

## CA — Change Amplification

**Definition.** For one representative *logical* change (e.g. "the file format gained a field"),
how many separate code or content sites must be edited in lock-step? CA > 1 means a single
decision is spread across sites — usually **repetition** or a **temporal split** (guideline 4).
CA is the maintenance-time face of ILC; report it when comparing a split vs a merge.

**Counting procedure:**
1. Name one representative *logical* change — something that should be "one decision."
2. Count the distinct source/content sites that must be edited to implement that change correctly.
3. If CA > 1, the decision is duplicated: find the site of duplication (same decision in two
   modules? A temporal split? Copy-paste?) and flag it.

**CA = 1** means changes are local — one decision, one site. This is the target.

**CA > 1** means the decision is duplicated. Report CA explicitly and identify the duplication
site. The fix is usually to merge the knowledge into one site or re-cut the boundary to keep the
decision whole (guideline 4).

**Example (from [examples/07-temporal-decomposition.md](../examples/07-temporal-decomposition.md)):**
Splitting a "read → transform → write" pipeline so that the wire format is encoded in the reader
module *and* the writer module gives CA = 2 for any format change: both modules must be edited in
lock-step. Re-cutting the boundary so one module owns the format drops CA to 1.

---

## Relationship to InterfaceCost

CCT and CA are diagnostic lenses, not proxy components:

- **CCT** asks: "Does the common caller pay for rare machinery?" It slices ISC+RCK; the items
  counted by CCT are already counted in ISC and RCK — CCT is not double-counted.
- **CA** asks: "How many sites change together?" It is the maintenance-time face of ILC. A high
  CA usually implies high ILC (a decision leaking across a boundary shows up as both leaked items
  in ILC and multiple-site edits in CA).

When reporting: include CCT beside ISC/RCK when overexposure is the concern; include CA beside ILC
when change amplification is the concern. Neither changes `InterfaceCost`.

---

## Example-08 linkage

[examples/08-overexposure.md](../examples/08-overexposure.md) is the canonical CCT worked example,
showing a logger API where the common case is burdened by rare-feature setup. The example walks
through the full CCT counting procedure and demonstrates the zero-config fix.
