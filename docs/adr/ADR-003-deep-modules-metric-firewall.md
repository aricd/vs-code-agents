<!-- scorecard-lint: skip -- specification document: defines/discusses the scorecard format rather than instantiating it -->

# Deep-Modules Metric Firewall and Dogfood Prune

## Status

accepted

## Context

During a design-review session, the `deep-modules` skill produced a correct depth verdict
(B deeper by InterfaceCost) but the final recommendation cited A, justified by "a large migration
cost." A one-time, author-paid transition cost was allowed to contaminate the metric output block,
not merely inform a non-metric action block. The Block-2 verdict (B is deeper) was implicitly
overwritten rather than recorded and then overridden in a distinct, gated Block 3.

This revealed three structural gaps in the existing skill:

1. **No firewall between metric and non-metric outputs.** The single-block scorecard template
   emitted "Verdict" and "Recommendation" as a merged line, making contamination invisible by
   construction — there was no distinct slot for each.

2. **Reinstated exclusion clause missing.** A clause explicitly barring one-time / non-interface
   costs from the proxy counts had been present in an earlier draft and was not carried forward
   into the deployed version. Agents had the guideline text in Guideline 1 (transition cost
   discussion) but no first-class rule in the counting section.

3. **Bare numbers permitted.** The scorecard template accepted `TOTAL: 14` without requiring
   named line-items. This made verdicts non-reproducible: a second reviewer could not audit which
   items produced the count.

Independently, the skill had accumulated secondary material (extended CCT/CA mechanics,
seam-validation procedure, two qualitative tie-breaker definitions) that increased the inline
concept count without adding to the instrument's core interface. The dogfood principle requires the
skill to be a deep module itself — minimal inline interface, extended material behind a pointer.

## Decision

### Part 1 — Metric firewall (structural contamination prevention)

The depth-evaluation output is restructured as **three ordered, non-reorderable blocks**:

- **Block 1 — Counts**: itemized proxy counts (CHEC, ILC, ISC, RCK with named line-items); the
  Hard-to-Describe ISC-honesty check (required); per-guideline judgment.
- **Block 2 — Depth Verdict**: cites Block 1 only. Required sentence: "Deeper by InterfaceCost
  (the only scored axis): `<A|B>` (`<n>` vs `<n>`)." Plus a Confidence line and a Blind-spot
  line (conforming to the `design-rubrics` 4-element shared output contract).
- **Block 3 — Non-metric Factors & Recommended Action**: quarantined. Transition cost, schedule,
  risk, and current-N appear here and only here. Block 3 MUST NOT alter Block 2.

Later blocks cannot alter earlier ones. This is enforced by the shape of the work product, not by
prose the agent must remember.

### Part 2 — Reinstated exclusion rule

The counting section gains a first-class rule adjacent to the existing `N-only-in-guideline-1`
clause:

> **One-time and non-interface costs are NEVER proxies.** Transition cost, migration effort,
> schedule, and risk are one-time author-paid costs — not durable per-caller costs. They belong
> only in Block 3. Never count them in Block 1, and never let them alter Block 2.

### Part 3 — Override gate

If Block 3's Recommended Action ≠ Block 2's Depth Verdict, the override must pass a gate:

```
gap = |InterfaceCost_A − InterfaceCost_B|
```

Override permitted **only if** `gap ≤ 1` **AND** the one-time cost is **large** (comparable to or
exceeding `gap × N`, where N = call-site count, with the unit basis of the one-time cost stated
explicitly). If `gap > 1` or the cost is not demonstrably large, the override is **BLOCKED** and
Block 2's verdict stands as the Recommended Action.

The `gap ≤ 1` window coincides with the near-tie / Low-confidence regime, so contamination is
structurally confined to the region where the depth signal is already weak.

Block 2's verdict **survives any override unchanged** — the depth truth is preserved for future
reference.

### Part 4 — Mandatory itemized counts

A bare number is invalid. Every proxy count must be backed by named line-items (`ISC: [entry-point
X; param Y; config knob Z] = 3`). This makes verdicts reproducible and auditable.

### Part 5 — Hard-to-Describe promoted to required

The Hard-to-Describe check is promoted from optional tie-breaker to a **required ISC-honesty
check in Block 1** of every scorecard. It closes the config-object gaming hole (collapsing ten
parameters into one struct does not make a module deep; the honest interface comment exposes the
real ISC).

### Part 6 — Prune to references (progressive disclosure)

Extended material that is not part of the instrument's core decision loop moves to `references/`:

- `references/derived-counts.md` — full CCT/CA mechanics + Example-08 linkage
- `references/qualitative-tiebreakers.md` — Naming precision and Obscurity definitions
- `references/seam-validation-procedure.md` — seam-validation step-by-step procedure

Inline: a one-line CCT/CA gloss with pointer; a one-paragraph Hard-to-Describe (now required);
one-line naming/obscurity notes with pointer. The four design-philosophy guidelines, the
menu-vs-substrate reframe core + guardrails, and the seam-validation blind-spot statement remain
inline. Net effect: fewer inline concepts, same decision-loop capability.

### Amendment (2026-07-07, plan 024) — Option-3 presentation firewall

Plan 024 (committed `1cee4dc`) transposed all 12 deep-module / `design-rubrics` scorecard tables
to the "Option-3" presentation format: options as ROWS; columns are the raw scored proxies -> a
`‖` divider -> `TOTAL` -> a `‖` divider -> the non-summed derived signals (`Growth/req`, `CA`,
`CCT`) -> `Attention`; with delta-to-leader `(.)`/`(+n)` markers and a single "lower wins"
direction statement. This is a **presentation-only** change: proxy semantics and the three-block
firewall (Parts 1-6 above) are unchanged. The Option-3 format is now the **governed presentation**
of the three-block firewall, and it introduces two presentation-surface guardrails that are
firewall-relevant:

1. **`TOTAL` is the four scored proxies only.** `TOTAL` sums ONLY CHEC + ILC + ISC + RCK.
   `Growth/req`, `CA`, and `CCT` are non-summed **derived signals**, held to the right of the `‖`
   divider, and NEVER enter `TOTAL`. The transpose therefore cannot manufacture a phantom fifth
   scored axis — the divider is the visual enforcement of the "InterfaceCost is the only scored
   axis" rule from Block 2.

2. **`Attention` restates Block-1 / Block-2 content only.** The `Attention` column (and the
   derived-signal columns) may restate ONLY Block-1 (counts) or Block-2 (verdict) material. It
   MUST NOT surface Block-3 material — one-time, transition, migration, schedule, or risk costs —
   into the scorecard table. This is the **same firewall as Part 2**, now extended to the new
   presentation surface: the `Attention` / derived columns were the specific contamination vector
   identified in the plan-024 review, so the exclusion rule is explicitly carried onto them.

The guardrail text for both points now lives in the `design-rubrics` authoritative template
(TASK-014). The deep-modules Block-1..Block-3 **narrative** format (inline Worked Example 1) is
unchanged and remains the canonical teaching form; Option-3 is the tabular presentation layer over
that same firewall, not a replacement for it.

### Amendment (2026-08-10) — Trajectory rows as a derived Block-2 reading

The `deep-modules` rubric gained three **required** Block-1 rows — growth unit, marginal surface
(`Δ<proxy>` per growth unit, labeled `[Observed, n=3]` or `[Projected]`), and the derived growth-slope
band — plus a crossover computation (`G*`) and optional gate rows citing pre-existing stated
constraints. This amendment records their status **relative to the firewall**, because trajectory
material touches every Part above.

1. **Parts 1 and 3 are unchanged and remain binding.** Block 2's required sentence is still
   *"Deeper by InterfaceCost (the only scored axis): `<A|B>` (`<n>` vs `<n>`)."* — verbatim.
   `InterfaceCost` remains the only **scored** axis and `TOTAL` still sums only the four proxies.
   The trajectory reading is a **derived, non-summed** line in Block 2, consistent with the
   2026-07-07 amendment that already classified `Growth/req` as a non-summed derived signal held to
   the right of the `‖` divider.

2. **Trajectory sits on the metric side of the firewall (Block 2), not in Block 3.** Marginal
   surface is a *durable per-caller* cost measured over growth units — categorically unlike the
   *one-time author-paid* costs (transition, migration, schedule, risk) that Part 2 excludes. It is
   therefore Block-2 material. When the trajectory reading contradicts the today-reading, **Block 2
   resolves the divergence internally** via the crossover arithmetic and records both readings.

3. **No new Block-3 escape hatch.** An earlier draft of this change permitted a Recommended Action
   to diverge from the Block-2 verdict "on trajectory grounds" *without* passing the override gate.
   That was rejected during review: it reopens precisely the contamination vector Part 3 closes,
   because a one-time cost can be relabeled "trajectory" to bypass the `gap ≤ 1` window. The
   override gate is unchanged and remains the **only** path for a Block-3 divergence.

4. **Part 4 (itemized counts) extends to the Δ row.** A marginal-surface figure requires named
   line-items and an evidence label; `[Observed]` and `[Projected]` may never be blended into one
   number, and a slope band without its Δ is invalid on the same grounds a bare `TOTAL: 14` is.

Rationale for requiring the rows at all: a scorecard reporting only today's `InterfaceCost` answers
"which is cheaper to adopt," not "which is cheaper to live with." The second question is usually the
one being decided, and omitting the growth axis silently favors the option with more surface today.

## Considered Options

**Seed A (structural scorecard firewall, chosen and extended):** Replace the single-block
scorecard with three ordered blocks. Adopted as the primary mechanism. Extended with the override
gate (from Seed B's structured-declaration insight) and the prune (from Seed D's proxy-reduction
insight).

**Seed B (formal tooling / "deep-lint"):** Introduce a maintained script + input schema to
enforce the scorecard shape. Rejected — adds a maintained script + input schema (new surface that
shallows the instrument itself), relocates subjectivity into the declaration, and is brittle on
the skill's non-code surfaces. Its transferable element (structured itemized declaration) is
absorbed tool-free via the itemized-counts mandate.

**Seed C (dual-review process):** Every A-vs-B call reviewed by two agents independently. Rejected
— 2× cost on every call (disproportionate for small inline judgments), shared blind spots leave
gaming unaddressed, and grows the process the agent must run rather than the instrument itself.

**Seed D (collapse to Surface + Leakage only):** Replace the four proxies with two
(ISC+ILC only), simplifying the metric. **Rejected as a capability-equivalence failure under the
gate (S2):** the four-proxy model delivers more than the two-proxy model for the same interface
question — the proxy→guideline mapping (CHEC→errors-out, ILC→complementary-code, ISC→general-
interface, RCK→shared-vocabulary) makes verdicts prescriptive; collapsing to two proxies loses
this prescriptivity. Since capability is not equivalent, the "smaller instrument" score is invalid.
Seed D's pruning insight is partially adopted: extended CCT/CA mechanics move to `references/`
while a one-line gloss stays inline.

## Consequences

### Positive

- Metric contamination is structurally impossible: the three-block shape enforces the separation
  that prose guidance could not.
- Verdicts are reproducible: named line-items make counts auditable and reviewable.
- The transition-cost failure mode is permanently encoded as Example 09 with a gate demonstration.
- The skill applies its own philosophy (deep module: small interface, powerful functionality).
- The `design-rubrics` 4-element shared output contract is satisfied (Convention + Items +
  Confidence/proportionality + Blind-spot, with depth verdict as skill-specific output).
- The three-block firewall now has an explicit presentation-surface analogue (plan 024): the
  Option-3 `‖` divider structurally segregates the four scored proxies from non-summed derived
  signals, and the `Attention`-column exclusion rule extends Part 2's contamination barrier to the
  tabular format. Firewall integrity is preserved across both the narrative and tabular surfaces.

### Negative (recorded)

- The three-block template is slightly more verbose than the previous single-block template for
  trivial decisions. Mitigated by the S3 carve-out: a trivial pick may collapse to one line.
- Prior scorecard outputs (single-block format) remain readable but are now visibly non-conformant.
  They are treated as historical artifacts; no migration required.

## Related ADRs

- [ADR-001](ADR-001-adr-and-context-conventions.md): ADR and CONTEXT.md conventions this ADR follows.
- [ADR-002](ADR-002-failure-mode-model-replacement.md): Failure-mode model this repo uses.
