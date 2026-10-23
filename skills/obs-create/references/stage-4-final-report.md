<!-- scorecard-lint: skip -- specification document: defines/discusses the scorecard format rather than instantiating it -->

Contents: [Required sections](#stage-4--final-obs-report) · [Output at end of Stage 4](#output-at-end-of-stage-4) · [Vocabulary target](#vocabulary-target)

## Stage 4 — Final OBS Report

Save to `.agent-output/analysis/<ID>-<service>-obs-final.md`. Required sections:

**1. Value Statement and Business Objective**
"As a [caller], I want to [objective], so that [value]."
State the IC reduction (raw surface IC → OBS IC, % improvement).

**2. Partitioning by Independence**
Table: all in-scope verbs grouped by axis.

**3. Eliminating Pseudo-Primitives**
Table: derivable verbs, their composition expressions, and verdicts.

**4. Result: N Orthogonal Primitives**
State N, list primitives, resolve key design tensions
(especially: create/update/delete collapse, render axis split, undo derivability).

**5. Interface Schema**
Typed interface in the caller's client language (default: TypeScript-style pseudocode).
Required: constructor, each primitive as a typed method, all input types, all return shapes,
read-only state property (if any), design notes on what the facade absorbs.

**6. Verb Derivation Table**
Every in-scope verb → primitive + composition expression. Coverage = 100%.

**7. Honest Scorecard**

Declare the **growth unit** above the table — the countable thing the requirement multiplies in
("a year from now we will have more ______": verbs, message types, resource kinds). State the
current count if known, or `none — one-off decision, no trajectory`.

| Proxy | Raw surface | OBS | Delta |
|---|---|---|---|
| Entry points | | | |
| ISC | | | |
| ILC | | | |
| RCK | | | |
| CHEC | | | |
| **IC** | | | |
| CA | | | |
| CCT | | | |
| Δ per growth unit `[Observed, n=3 \| Projected]` | | | |
| Growth slope (derived) | | | |
| Lean rung | | | |

The Δ / slope rows are **required** whenever a growth unit exists — a raw-surface-vs-OBS comparison
is a menu-vs-substrate case, where flat-vs-rising marginal surface is typically the *dominant*
driver, not a footnote. Prefer `[Observed]` counts from the last three real verb additions over
`[Projected]` ones; never blend the two into one number, and never state a slope band without the Δ
behind it. Full convention: [`deep-modules` Trajectory rows](../../deep-modules/SKILL.md#trajectory-rows-required-in-every-comparison-scorecard).
`IC` sums only ISC+ILC+RCK+CHEC; Δ, slope, CA, and CCT are derived signals and never enter it.

Include critic-anticipation buffer: +1–3 borderline items a reviewer could add, with IC band.

**8. Comparison Table**
OBS vs raw surface. Reference any prior OBS analyses in `.agent-output/analysis/*-obs-final.md`.

**9. Mapping to Existing API**
For each primitive: exact bus/DDS/file/DB calls it issues and the response channels it awaits.
This is the adapter contract.

**10. The Orthogonality Argument**
Prove each primitive non-derivable from the union of all others.
For the render axis specifically: cite the exact source lines that prove the rendering
service does NOT subscribe to the service's data topics (i.e., it can only be updated via
its own scene channel). This must be source-verified, not assumed.

**11. Render Path Analysis** _(always present, even if render is out of scope)_
- 3D viewport: independent axis? Source evidence (file + line).
- GUI panel: independent axis? Auto-propagation present or broken?
- Indirect paths via workflow controllers: document them, but note they are conditional on
  task-active state — a headless adapter cannot rely on them.
- OBS recommendation: explicit `render` primitive / implicit via controller / N/A

**12. Open Questions / Remaining Gaps**
Table: unknown | blocker | required action | owner.

**13. Candidate terminology** _(for CONTEXT.md / glossary)_

---

## Output at end of Stage 4

Present to the user:
1. One-paragraph executive summary (N primitives, IC reduction, key design decisions)
2. Full interface schema (typed notation block)
3. Verb derivation table
4. Honest scorecard
5. Link to the saved analysis file

Ask: **"Does this OBS meet your needs? Would you like to adjust scope or explore any alternative?"**

---

### Vocabulary target

Save to `.agent-output/analysis/<ID>-<vocabulary>-obs-final.md` and write all thirteen sections.
Sections 1–4, 6–8 and 12–13 are unchanged, with "verb" read as an operation the vocabulary lets
an author express and the coverage in section 6 measured against the capability baseline. These
sections change:

- **5. Interface Schema** becomes a **grammar/IR sketch**: the new constructs as grammar
  productions and IR node kinds, with their attributes, in place of a typed client-language
  interface. Include the old → new construct mapping of the selected finalist.
- **9. Mapping to Existing API** becomes the **mapping onto the existing IR and codegen**: for
  each primitive, the existing IR node kinds and code generators it reuses or changes, and the
  front-end changes needed to accept it. This is the adapter contract for the realization.
- **10. The Orthogonality Argument** is unchanged except that the render-axis source-line
  citation is N/A.
- **11. Render Path Analysis** is stated as "N/A — vocabulary target"; do not investigate
  render paths.
