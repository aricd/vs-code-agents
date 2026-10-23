# Worked example 9 — Transition cost masquerading as depth (negative example)

> **Summary**: The canonical anti-example for metric contamination. A scorecard correctly
> identifies B as deeper (InterfaceCost 4 vs 7), but someone recommends A on transition-cost
> grounds. The override gate BLOCKS the override because gap = 3 > 1. A positive control
> demonstrates the gate PERMITTING an override at gap = 1 with a documented large one-time cost,
> with Block 2's verdict unchanged.
>
> **Back-link**: [../SKILL.md](../SKILL.md) § "Override gate"

---

## Background: the failure mode this example freezes

During a design review session, an agent was comparing two API designs where B had lower
InterfaceCost. The agent's final recommendation was A — citing a "large migration effort" as the
reason. The depth verdict (B is deeper) was correct; the recommendation (A) was wrong because the
one-time migration cost was allowed to contaminate the metric output, not merely inform the
non-metric action block. The Block-2 verdict was implicitly overwritten rather than recorded and
then overridden in Block 3 with a gate check.

This example uses the three-block structure to show:
1. **Negative control**: gap = 3 > 1 → override BLOCKED; B remains the Recommended Action.
2. **Positive control**: gap = 1, large documented one-time cost → override PERMITTED; Block-2
   verdict B-is-deeper is unchanged, Recommended Action becomes A.

---

## Scenario: report-builder access layer

**Capability**: Fetch one of several predefined report datasets from a data service.

**A (menu, current system)**: Three dedicated fetch methods:
- `fetchUsageReport(month, connectionConfig)` — returns usage data
- `fetchBillingReport(month, connectionConfig)` — returns billing data
- `fetchStatusReport(month, connectionConfig)` — returns system status

The shared `connectionConfig` object bundles credentials and retry settings that all three methods
require. Callers must pass it on every call.

**B (parameterized, proposed)**: Single entry point:
- `fetchReport(reportType, month)` — returns `ReportData`; connection details are encapsulated
  (read from config file + env vars at init); `reportType` is an enum the caller passes.

---

## Negative control (gap = 3 > 1 → BLOCKED)

### Block 1 — Counts

Caller & baseline: application code; baseline = the host language + standard config-file patterns
Capability held constant: fetch one predefined report dataset by type and month
Equivalence: Yes

Growth unit: report type (3 today: usage, billing, status)

A — ISC: [fetchUsageReport entry-point; fetchBillingReport entry-point; fetchStatusReport
           entry-point; connectionConfig param concept] = 4
  Hard-to-Describe check: "Call the type-specific fetch method for usage, billing, or status,
  passing month and a connectionConfig." — still enumerating methods. Fails. ✗
A — ILC: [connectionConfig leaks internal connection/retry strategy] = 1
A — RCK: [caller must know which method maps to which report type] = 1
A — CHEC: [ConnectionError] = 1
A InterfaceCost = 4 + 1 + 1 + 1 = **7**

B — ISC: [fetchReport entry-point; reportType param concept; month param] = 3
  Hard-to-Describe check: "Given a report type and month, return the report dataset." —
  one sentence, complete. ✓
B — ILC: [connectionConfig encapsulated — not exposed] = 0
B — RCK: [enum values for reportType] = 1
B — CHEC: [ReportUnavailableError] = 0 (unavailable → returns empty dataset, not an error)
B InterfaceCost = 3 + 0 + 1 + 0 = **4**

A — Δinterface per new report type: [one type-named fetch method] = 1   [Projected]
A — Growth slope: rising (linear)
B — Δinterface per new report type: [] = 0   [Projected]
B — Growth slope: flat

Per-guideline judgment:
- Pull complexity down:         B — connectionConfig absorbed; retry/auth internal; encapsulated.
- General + common case simple: B — single entry point vs three type-named methods (use-case naming).
- Errors defined out:           B — unavailable returns empty; CHEC 1→0.
- Complementary code together:  B — all report logic is in one place; A scatters it across 3 methods.

### Block 2 — Depth Verdict  (cites Block 1 ONLY; later blocks MUST NOT alter this)

Deeper by InterfaceCost (the only scored axis): **B**  (4 vs 7).
Trajectory reading (derived, non-summed — never enters InterfaceCost): A rising (linear, +1 method
per report type) vs B flat; G* = n/a — B dominates (lower base AND flatter).
Confidence: High — same capability, declared caller, all items visible.
Blind-spot: this verdict does not establish whether the config-file init seam exists in the
current codebase, or that a single module owns the connection-management policy.

### Block 3 — Non-metric Factors & Recommended Action  (quarantined; MUST NOT alter Block 2)

Non-metric factors: migration requires updating ~50 call sites and updating the integration
test harness. Estimated 3 developer-weeks.
Recommended Action: **B**.
Override gate: cost = migration effort (3 developer-weeks); gap = |7 − 4| = **3**.
large? **No** — gap = 3 > 1. **Override BLOCKED.**
Block-2 verdict (B deeper) stands as the Recommended Action.

Note the trajectory makes the blocked override look worse still: A's gap does not merely persist,
it *widens* by one method per report type added. But that reasoning stays in Block 2 — it is a
durable per-caller cost, not a Block-3 factor, and it is **not** a second route around the override
gate. Migration effort is the only thing being gated here, and it loses on its own terms.

---

### What went wrong in the original session

The agent wrote:

> "B has a cleaner interface, but migration costs are significant. Recommend A."

This is the contamination failure: the transition cost (a one-time, Block-3 factor) was placed
*before* and *above* the depth verdict, effectively overwriting Block 2 without a gate check. The
gap of 3 means the depth signal is strong — B is clearly deeper — and the override gate blocks
the one-time cost from reversing it.

**The correct output** is above: Block 2 records B-is-deeper; Block 3 quarantines the migration
cost and checks the gate; gate fails (gap 3 > 1); Recommended Action = B.

---

## Positive control (gap = 1 → PERMITTED with documented large cost)

**Same scenario, smaller gap.** Suppose a lower-effort refactor brings A's interface down to:

A' — ISC: [fetchReport entry-point; reportType param; month param; connectionConfig param] = 4
  Hard-to-Describe check: "Given a report type, month, and connection config, return the dataset."
  — one sentence, but connectionConfig is an explicit param. Borderline. ✗ (confirms ISC 4)
A' — ILC: [connectionConfig still leaks connection details] = 0 (now caller-provided deliberately)
A' — RCK: [enum values for reportType; connectionConfig construction] = 1
A' — CHEC: [ReportUnavailableError] = 0
A' InterfaceCost = 4 + 0 + 1 + 0 = **5**

B (unchanged): InterfaceCost = **4**

gap = |5 − 4| = **1**

Per-guideline judgment: B still wins (one fewer concept; connectionConfig absent from B's interface).

### Block 2 — Depth Verdict  (positive control)

Deeper by InterfaceCost (the only scored axis): **B**  (4 vs 5).
Confidence: Medium — gap = 1; tie-breaker zone. Hard-to-Describe: B's comment is one clean
sentence; A' needs to mention connectionConfig. B still wins tie-breaker.
Blind-spot: same as negative control.

### Block 3 — Non-metric Factors & Recommended Action  (positive control)

Non-metric factors: N = 50 call sites; migration to B requires updating each site's dependency
injection setup plus 2 weeks for integration-test harness rework. Total: ~80 developer-hours.
Recommended Action: **A'**.
Override gate: cost = migration effort (80 developer-hours); gap = |5 − 4| = **1**.
large? **Yes** — gap × N = 1 × 50 = 50 call-site-updates; 80 developer-hours is comparable to
or exceeds the durable cost savings from the 1-unit gap (stated basis: developer-hours vs
call-site-update-equivalents, roughly comparable in magnitude for this N).
Override **PERMITTED** (gap ≤ 1 AND large one-time cost documented with unit basis).
Block-2 verdict (B deeper) is **unchanged**.

---

## Lessons

1. **Block 2 is immutable.** The override in the positive control does not change the depth
   verdict — B is still recorded as deeper. Block 3 records the pragmatic recommendation; the
   depth truth is preserved for future reference (when N grows, the migration math flips).

2. **The gap is the gate.** Gap = 3 blocks any transition-cost override, however large. Gap = 1
   opens the gate — but only when the cost is demonstrably large against `gap × N` with a stated
   unit basis.

3. **State the unit basis.** "Large" requires comparison across incommensurable units (developer-
   hours vs call-site-complexity units). Name both sides; do not assert "large" bare.

4. **Confidence matters.** At gap = 1 (positive control), confidence is Medium — the depth signal
   is weak enough that a large one-time cost can legitimately shift the recommendation. At gap = 3
   (negative control), confidence is High — the depth signal is strong; non-metric factors are
   noted but cannot reverse it.
