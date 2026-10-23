# Lens-Applicability Compact-Grammar Reformat

## Status

accepted

## Context

`design-rubrics`' Lens-Applicability declaration is a required first line on every user-facing `OPENQ-*`/`ALT-*` comparison (and on ADR Considered-Options entries): `Lens applicability: deep-modules <in|out — reason-if-out> · functional-core <in|out — reason-if-out> · lean-design <in|out — reason-if-out>`. Plan 042 is building a mechanical validator gate for this line and, while scoping its grammar transcription, compared the current wording against compact alternatives. A caller-side measurement (CHEC/ILC/RCK proxies, per `deep-modules`) found the current form carries no self-description cost but is the longest rendering at equal information content; a compact-structured alternative was found to shorten the line by roughly half while being _simpler_, not harder, for a mechanical validator to match (a fixed 3-token grammar vs. free-word + em-dash matching), at the one-time cost of authors learning a 3-letter/glyph legend. Unstructured (prose) alternatives were measured and rejected: one was found to be _longer_ than the current form at equal detail, and the other could not carry the mandatory verbatim canned reason (`not a within-unit decomposition`) without re-introducing a sub-grammar, which would have broken plan 042's own already-approved `REQ-004`/`TEST-003` (reject a non-verbatim reason).

This is a corpus-wide, forward-looking convention change (every future `OPENQ-*`/`ALT-*`/ADR Considered-Option across every plan and every consuming repo), not a plan-042-local detail — `CON-002` in plan 042 is explicit that the validator does not own this rule, `design-rubrics` does. Two existing accepted/proposed ADRs ([ADR-018](ADR-018-subproject-prefixed-adr-identifiers.md) L28, [ADR-021](ADR-021-propagation-test-and-claimed-support-map.md) L26) already cite the current wording verbatim inside their own Considered-Options text. Per the Triple Gate (hard-to-reverse once many more citations accumulate; surprising without context — a shorter, differently-punctuated line is not a "find it in five seconds" change; a real, scored trade-off with rejected alternatives), this decision is ADR-worthy.

**Propagation disclosure** (mirroring [ADR-018](ADR-018-subproject-prefixed-adr-identifiers.md)'s point 4): `design-rubrics/SKILL.md` distributes to every consuming repo via the same whole-directory `skills/` linking mechanism ADR-018 names. This decision takes effect immediately and non-opt-in for any consuming repo on next sync. `BACKCOMPAT-002` (plan 074) verifies "no validator for either grammar has shipped" only against **this** repo's plan 042; it cannot, from this repo's vantage, rule out a consuming repo already having built tooling or in-flight plans against the old wording. No such tooling is known to exist at decision time; none is asserted to not exist elsewhere.

## Decision

Adopt the compact-structured grammar as the new single canonical format for the Lens-Applicability declaration, superseding the current wording in `design-rubrics/SKILL.md`'s `### Lens Applicability declaration` section:

```
Lens[DM<+|-(reason)> FC<+|-(reason)> LD<+|-(reason)>]
```

Fixed order: `DM` (deep-modules), `FC` (functional-core), `LD` (lean-design), always in that sequence, space-separated, wrapped in `Lens[...]`. `+` = in, `-` = out. Reason is required immediately after `-` in parentheses (e.g. `FC-(not a within-unit decomposition)`), optional after `+`. `functional-core` keeps its existing constant-`-` rule and exact canned reason text (`not a within-unit decomposition`), unchanged by this decision — only the surrounding rendering changes.

The update to `design-rubrics/SKILL.md` covers every place that renders a literal example of the grammar, not only the canonical code block: the derivation-invariant (C1) table's token values, the "fixed canned token" quote, and the Capability Admission Record override paragraph. Every other reference in that file is already a slot-link (per its own "Single canonical format" rule) and needs no change.

**Forward-only.** No existing plan text, critique, or ADR that already cites the old wording is rewritten. [ADR-018](ADR-018-subproject-prefixed-adr-identifiers.md) L28 and [ADR-021](ADR-021-propagation-test-and-claimed-support-map.md) L26 keep their original Considered-Options text verbatim as frozen decision records (same precedent as `document-lifecycle`'s frozen-record convention and plan 040's `Created`-field backfill decision) — this ADR does not amend either, and the discrepancy between their text and the new canonical form is disclosed here rather than left for a future reader to discover unexplained.

Lens[DM+ FC-(not a within-unit decomposition) LD+]

Zone declaration: tooling — a documentation/authoring-convention change with no runtime or contract-zone effect; no production code, API, or data schema is touched. (Inline form chosen over `ADR-018`'s single-sub-question escape-hatch text, per Architect `N-1`, because it states the actual zone rather than deferring to a generic pointer. Scoped to this ADR only — not binding on future ADRs; `adr-authoring/SKILL.md`'s own escape-hatch text is unchanged by this decision, per Critic `M-1`.)

## Lens Applicability & Scorecard

_(Conditionally required — this Decision compares 5 options in Considered Options, per `adr-authoring`'s trigger condition. Reuses `design-rubrics`' OPENQ-framing compact-scorecard contract verbatim, per Critic `H-1`.)_

Gate: Caller = the mechanical validator (plan 042) and the human reading any `OPENQ-*`/`ALT-*`/ADR Considered-Option entry. Baseline = caller already knows the 3 lens names and the in/out concept (one-time, from `design-rubrics`). Capability held constant = communicate, per lens, applicability + reason-if-out. Equivalence: Yes. Growth unit: one line authored per `OPENQ-*`/`ALT-*`/ADR-Considered-Option entry — already dozens in this repo, growing with every future plan/ADR. Confidence: Medium — no live parser exists yet; counts below are itemized reasoning, not a measured trace. Hazard: Options 3 and 4 (unstructured) threaten plan 042's own already-approved `REQ-004`/`TEST-003` (reject a non-verbatim `functional-core` reason) — Option 4 is exactly the disconfirmed fixture case (`lens-c-paraphrased-canned-reason.md`), not a hypothetical.

All proxies: lower is better. (.) = leader; (+n) = points behind leader.

| Option | ISC | ILC | RCK | CHEC | ‖ | TOTAL | Attention |
| --- | --: | --: | --: | --: | :-: | --: | --- |
| 1 — keep current (rejected) | 3 | 0 | 0 | 2 | ‖ | (.) 5 | Interface-cost leader — no legend to learn |
| **Chosen — compact-structured** | 3 | 0 | 1 | 2 | ‖ | (+1) 6 | One-time 3-token/glyph legend; otherwise matches the leader |
| 2 — order-reliant glyph (rejected) | 3 | 0 | 2 | 2 | ‖ | (+2) 7 | Drops lens identity; RCK rises further for no further capability |
| 3 — compact unstructured (rejected) | 3 | 0 | 0 | 4 | ‖ | (+2) 7 | CHEC rises — validator can't reliably disambiguate "no reason" from "informally reasoned" |
| 4 — telegraphic unstructured (rejected) | 3 | 0 | 2 | 4 | ‖ | (+4) 9 | Worst on both axes; also fails `REQ-004`/`TEST-003` as written |

**CA (Change Amplification):** 0 — no shared decision duplicated across a boundary by any option. **Author:client asymmetry:** N/A — single author-is-reader scenario (the same two readers, validator and human, for every instance). **Schema-stability:** this ADR itself versions the grammar; a future change would again require the forward-only adoption this ADR establishes (`REQ-006` precedent).

Growth unit: one line authored per `OPENQ-*`/`ALT-*`/ADR-Considered-Option entry — already dozens in this repo, growing with every future plan/ADR. Marginal surface: `Δ` on each of the four scored proxies (`ISC`/`ILC`/`RCK`/`CHEC`) is **0 for every option** — no option's per-entry cost depends on, or is coupled to, any other entry already authored. Slope: **flat, for every option** (per deep-modules' own band table: `Δ = 0` → flat). **No crossover exists and none is computed** — a crossover requires a base/slope divergence on the scored proxies, and here the slopes agree (all flat) even though the bases differ. The deep-modules metric alone is therefore **static, not a trajectory argument**: it is, and remains, `(.) 5` for Option 1 vs. `6` for the Chosen option, at every instance count.

Verdict (deep-modules only): **Option 1 is the strict InterfaceCost leader** (`TOTAL` 5 vs. the Chosen option's 6) — the one-time `RCK` legend cost is real, is not waived, and is not offset by any compounding proxy effect (none of the four proxies has a nonzero slope here). **Deep-modules' own metric, taken alone, does not mandate the reformat.** Options 2–4 remain dominated outright regardless (worse or equal on every proxy vs. the Chosen option, with no compensating effect) and are rejected on InterfaceCost grounds alone.

### Lean axes (this decision's `lean-design: in` lens, scored separately — not blended into the table above)

`design-rubrics`' Lens-Applicability line for this decision (above) declares **both** `deep-modules` and `lean-design` as `in` — each lens is scored in its own lane, per ADR-003's firewall, which quarantines `InterfaceCost` as the _only_ scored axis inside the deep-modules table, but does not forbid a second, independently-reported lens from carrying the decision when the first is a near-tie.

```
Lean axes: AuthorCost = one-time, ~zero (no new primitive, mechanism, or tooling — a documentation
             re-render);
           Transition cost = one-time (this plan's `REQ-002`-`REQ-007`; no retroactive sweep per
             `REQ-006`);
           Growth unit: one line authored per `OPENQ-*`/`ALT-*`/ADR-Considered-Option entry
             (same unit as above — already dozens, growing);
           Marginal surface / trajectory = characters typed/read per instance (a lean-axis-native
             measure, not one of the four deep-modules proxies — it is reported here, in its own
             lane, specifically because ADR-003 forbids reporting it inside the table above):
             Option 1 ≈109 chars/instance [Projected, worst-case worked example]; Chosen ≈51
             chars/instance [Projected, worst-case worked example] → Chosen is ~53% lower, flat per
             instance for both (not a rising/falling slope — each instance is independent), so the
             saving is a constant per-instance delta multiplied by a growing instance count, not a
             compounding rate;
           Capability-equivalence gate: Yes — both options communicate identical information (see
             deep-modules Gate above); this lean-axis comparison is the same-capability case, not
             example 5's misclassification trap.
Confidence: Medium — the character counts are a single worst-case worked example, not a corpus
             measurement across the already-dozens of real instances.
Hazard: none beyond the deep-modules Hazard line above (Options 3/4) — probes P1-P4 applied.
```

**Combined verdict (both lenses, reconciled explicitly):** deep-modules' own metric is a **near-tie favoring the status quo** (`gap = 1`, flat on every proxy — no trajectory argument available on that axis). `lean-design`'s axis — declared `in` for this exact decision — shows a real, constant, per-instance character-economy saving (~53%) multiplied by an already-large and growing instance count, at an authoring/transition cost this ADR assesses as near-zero (a documentation re-render, no new mechanism). **The reformat is adopted on the `lean-design` axis, with the `deep-modules` near-tie disclosed honestly rather than hidden or smuggled into the proxy table as a false trajectory.** This is the correct, rubric-compliant resolution per Critic `H-3`: a one-time or per-instance cost outside the four proxies belongs in its own declared lens's lane, never inside deep-modules' firewalled `TOTAL`.

## Considered Options

1. **Keep the current wording (`Lens applicability: deep-modules <in|out...> · ...`), instead of reformatting.** Rejected: measured as the longest rendering at equal information content among the candidates considered (compact-structured candidate ~53% shorter at identical detail). Hazard: none — probes P1-P4 applied; no construction-time state, no per-call validation change.
2. **A very-compact, order-reliant glyph form with no `DM`/`FC`/`LD` labels (e.g. `Lens: + -(reason) +`), instead of keeping the labels.** Rejected: drops lens identity entirely, forcing a reader to memorize a fixed position to know which judgment belongs to which lens — a real regression in self-description (RCK rises) for a marginal further length saving over the chosen option. Hazard: none — probes P1-P4 applied.
3. **A compact, unstructured prose form (e.g. "deep-modules and lean-design apply; functional-core doesn't (reason)."), instead of a fixed grammar.** Rejected: measured _longer_ than the current wording at equal detail, and a mechanical validator must additionally disambiguate "no reason given" from "reason phrased informally" — a genuine CHEC increase with no compensating length win. Hazard: a looser grammar widens what a validator must accept, risking false negatives on the very omissions plan 042 exists to catch; no mitigation available short of re-introducing a sub-grammar, which defeats the "unstructured" premise.
4. **A very-compact, unstructured telegraphic form (e.g. "DM/LD yes, FC no (not within-unit)."), instead of a fixed grammar.** Rejected: same ambiguity as Option 3, plus the reason is paraphrased rather than verbatim — this would fail plan 042's own already-approved `TEST-003` (reject a non-verbatim `functional-core` reason) as a matter of definition, not merely risk. Hazard: as Option 3, compounded — this option is a disconfirmed fixture case (`lens-c-paraphrased-canned-reason.md`) by plan 042's own test design, not a hypothetical.
5. **Retroactively rewrite existing citations of the old wording (plan text, this repo's own ADR-018/ADR-021), instead of forward-only adoption.** Rejected: both already-accepted/proposed ADRs are frozen decision records under this repo's existing frozen-record convention; rewriting their Considered-Options prose to match a later convention would misrepresent what was actually decided and cited at the time. Matches the precedent already set by plan 040's `Created`-field backfill decision (forward-only, explicitly disclosed, not silently inconsistent). Hazard: none — probes P1-P4 applied; no existing citation is altered either way, so no consumer of either ADR is affected.

## Consequences

### Positive

- Every future `OPENQ-*`/`ALT-*`/ADR Considered-Option authored after adoption carries a shorter, equally-informative declaration, compounding across however many are written going forward.
- The mechanical validator plan 042 is building matches a simpler, fixed-token grammar instead of free-word + em-dash matching — lower implementation and maintenance cost for that check.
- The trade-off and the rejected alternatives (including the two that were measured, not merely assumed, to cost _more_ at equal detail) are recorded once, auditably, instead of re-litigated per plan.

### Negative

- Authors must learn a small one-time legend (`DM`/`FC`/`LD`, `+`/`-`) that the fully-spelled-out prior wording did not require. Accepted as a one-time cost against a recurring, compounding saving.
- `ADR-018` and `ADR-021` now visibly cite a superseded wording inside their own frozen text; a future reader unfamiliar with the forward-only convention could mistake this for an unnoticed inconsistency rather than a deliberate, disclosed one. Mitigated by this ADR's own explicit cross-reference in the Decision section above.

## Related ADRs

- [ADR-018](ADR-018-subproject-prefixed-adr-identifiers.md): cites the superseded wording verbatim in its own Considered-Options text (L28); not amended by this decision (forward-only, see Decision).
- [ADR-021](ADR-021-propagation-test-and-claimed-support-map.md): cites the superseded wording verbatim in its own Considered-Options text (L26); not amended by this decision (forward-only, see Decision).
