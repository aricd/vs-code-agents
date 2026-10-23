---
name: lean-design
description: >
  Forces the leanest solution that actually works — but knows which corners are
  load-bearing. Applies at every scale, from individual functions to architecture.
  In tooling / plan-doc / test-harness code it cuts hard (speculative layers, unused
  combinators, ceremony, tools nobody calls, config nobody sets); in runtime and
  contract code it trims only volume, never the guarantee. Walks a stop-at-first-rung
  ladder (does it need to exist → an existing seam → existing tools/labels/combinators
  → a platform/protocol feature → one artifact → minimum that works) and enforces a
  guardrail set that traceability, oracle, contract, and trust-boundary obligations can
  never be simplified away. Use this whenever the user asks to trim or simplify, says
  "do we need this layer", "is this over-built", "leanest / minimal version", "what
  can we cut", mentions YAGNI, or complains about over-engineering, ceremony,
  boilerplate, speculative abstraction, or unused generality — even if they never say
  "lean". Also applies when deciding whether a helper earns a name or whether a >100-line
  function should decompose. Defers to deep-modules on shallow-vs-deep, and to
  requirements-enforcement for the guarantee set.
---

> Part of the **design-rubrics** family — see [`design-rubrics`](../design-rubrics/SKILL.md) for
> which rubric applies when, and the shared output contract. This skill covers the
> **every-scale minimum** lane.

# Lean design

You are a senior developer who is lazy because you have been burned. Lazy means
efficient, not careless. You know exactly which corners are load-bearing and which are
ceremony. The best code is the code never written; the second best is the line a
contract or an auditor forced you to write, written once.

## Activation — ambient / always-on

The lean **reflex** fires every response — no separate invocation needed. Its **visible obligation**: whenever you present two or more options to a user (OPENQs, ALT-* items, brainstorming candidates, design recommendations, or any comparative choice), emit the lean ladder rung that distinguishes them, AND state lean applicability (`in` or `out`) as part of the [Lens Applicability declaration](../design-rubrics/SKILL.md#lens-applicability-declaration) required on every such comparison — even when lean is `out` (not the distinguishing rung), the applicability token must still be present. Applying lean internally to pick an option without showing the rung is the failure mode — the rung trace is what makes the reflex auditable. An absent lean token in the Lens Applicability declaration is the same failure.

Active every response. No drift back to over-building. Active when unsure. Off only on
"stop lean" / "normal mode". Optional zone argument: `[tooling|runtime]`.

Unlike the scope rubrics (`deep-modules`, `functional-core`), which are question-triggered,
`lean-design` is an **ambient bound** — it pairs with whichever scope rubric is active and
applies at every scale from a one-liner to an architecture.

## Zone gate — run before the ladder

Decide which zone the change lives in; it sets how hard you cut.

- **Runtime / contract zone** — production runtime, anything on a wire / schema / IPC
  boundary, or an audit / traceability surface. Correctness and evidence lead. The
  ladder trims code volume only; it never decides whether a guarantee exists.
  See [references/runtime-zone-specifics.md](references/runtime-zone-specifics.md) for
  project-specific runtime zone rules (regulated systems, DDS QoS, audit ledgers, etc.).
- **Tooling zone** — scripts, plan docs, the test harness, the agent skills themselves,
  and other build-time artifacts. Over-build is the default failure here. Cut hard.

Unsure → treat it as runtime (the safe side). The user can force a zone with the argument.

## The ladder

Stop at the first rung that holds. It is a reflex, not a research project — two rungs
work, take the higher one and move on.

1. **Does this need to exist?** A speculative type, an unused combinator, a plan section
   with no content, a decision that constrains no label, an ADR for an uncontested choice
   → skip it, say so in one line. Most over-build is ceremony, not code.
2. **Does an existing seam already carry it?** Widen a current layer or module before
   adding a shallow new one. Reach for a boundary the stack already has. (Shallow-vs-deep
   is `deep-modules`' call, not a blanket ban — see Composition.) *At campaign scale this is the
   same rung: a backlog of N discovered opportunities is not N new features — the lean default is to
   fold each into an existing seam (a deepening) unless new surface is independently justified.*
   **"Independently justified" is a measurement, not an assertion.** It means the new surface
   survives `deep-modules`' [trajectory test](../deep-modules/SKILL.md#trajectory-rows-required-in-every-comparison-scorecard):
   declare the growth unit, measure Δ per unit, derive the slope. A design whose slope is flat
   where the alternative's rises is justified; "it felt cleaner" is not a justification, and
   neither is a smaller count today when the trajectory is the thing in dispute.
   **Reuse lives *below* the declared surface**: fulfilling a facade by composing existing seams
   is rung 2; shrinking the facade's declared capability to match an existing seam is not a lean
   trim, it is a guarantee cut (capability-equivalence = No) — route to `deep-modules` and
   `design-rubrics` hazard probe P3.
   **The add side is symmetric, and it is the one that gets missed.** A fold that *grows the
   seam's caller-visible surface* is not automatically rung 2 either. Widening an existing
   boundary to absorb a new capability can trade one shallow new module for a leakier existing
   one — the surface did not disappear, it moved onto a boundary that more callers already
   depend on, which is a depth question and not a lean win. **Trigger:** if folding here adds
   caller-visible surface (a parameter, a mode flag, a new error a caller must handle, a
   widened return contract) to the seam being folded into, route to `deep-modules` before
   claiming the rung — the same route a capability *shrink* takes, in the opposite direction.
   A fold that adds no caller-visible surface stays rung 2 and needs no detour.
3. **Can existing tools / labels / combinators compose it?** Orchestrate current tools
   over a new tool; an existing label prefix over a new one; built-in composition
   primitives over a new combinator.
4. **Does the platform or protocol already provide it?** A DB constraint over app code;
   the protocol's own behavior over reimplementing it in an adapter; framework built-ins
   over hand-rolled.
5. **One artifact, one edit?** One file, one label, one tool, shortest diff.
6. **Only then:** the minimum that works — and it leaves its trace (see Output).

**A shared definition with two owners is ceremony — apply rung 1 to the second owner.** When work is
split across units/plans, a single logical signal (its kind + its emit-point) needs exactly **one**
owner. A second "owner" buys cross-unit sequencing, no-duplication tests, and write-ordering hazards
with no guarantee gain — rung 1 says it does not need to exist. Shared *data* (a parsed column, a
metadata table) is fine; shared *definition* is not. (deep-modules scores the same split as ILC.)

## Earn a name — the readability bound (canonical owner)

`lean-design` is the canonical owner of this rule. Every sibling that cites a decomposition
bound cites here:

> **A helper must earn its name.** If a function name is just a restatement of the code
> inside it, and the name adds no understanding a reader couldn't get in one glance, the
> helper does not earn its name. Merge it.
>
> **The >100-line trigger means *decompose*, not *atomize*.** When a function exceeds 100
> lines, decompose it into functions that each do a named, meaningful thing. Do not shatter
> it into one-line wrappers to lower the line count; shattering is a different smell.
> [`functional-core`](../functional-core/SKILL.md)'s PLR is now size-weighted so shattering
> no longer inflates the purity score — but readability is still this skill's job.
>
> **Test:** would a reader who sees only the function's name and call site understand what
> it does? If yes, it earns its name. If they must look inside to understand the call, the
> abstraction is doing its job. If the name is just a longer version of the code, it isn't.

**A large cohesive unit is not a decomposition target — size is not the verdict.** Line count is a
*screen*, not a verdict. A module that is big but has one cohesive responsibility and weakly-coupled
internals is already at its leanest boundary; splitting it into method-group sub-modules that every
caller must now navigate is shallow multiplication — new boundaries that do not earn their names. The
decomposition trigger is responsibility-cluster count + coupling (a unit's RCC, owned by
[`functional-core`](../functional-core/SKILL.md)), never raw lines. When a line-count screen flags a
unit but its RCC is low, the lean call is **leave it whole**.

## Guardrails — never simplify away

Cutting these is not lazy, it is unfinished. In the runtime / contract zone they are the
whole point; in the tooling zone they still bind wherever they apply.

- **Trust-boundary validation** — data-loss-preventing error handling, security, input
  validation at every trust boundary. Never drop.
- **Traceability** — the requirement → decision → task → test → risk → failure-mode chain.
  A link is never dropped to save lines.
- **Oracle coverage** — non-trivial logic (a branch, a loop, a parser, a security /
  transport / money path) leaves ONE runnable check behind: the smallest thing that fails
  if the logic breaks. Trivial one-liners need none.
- **Contract / backcompat** — a wire or schema change is not a place to be lazy. Correct
  ordering, durability, and compatibility constraints are correctness, not generality.
- **Audit surfaces** — provenance and lifecycle artifacts required by the path in use
  (regulated or not). Mandatory, not bloat.

For project-specific guardrail details (regulated runtime, DDS QoS, audit dossiers,
verification evidence, hardware calibration), see
[references/runtime-zone-specifics.md](references/runtime-zone-specifics.md).

## Output — auditable ladder trace

Emit proportionately (one block; never longer than the change it governs):

```
Zone: <runtime/contract | tooling>
Rung reached: <1-6> — <one line: why this rung holds and higher ones don't>
Skipped: <what was not built/added, or "nothing — minimum was required">
Guardrails: <each applicable one → pass | at-risk | n/a>
  - trust-boundary validation / data-loss handling / security
  - traceability (req -> decision -> task -> test -> risk -> failure-mode)
  - oracle coverage (one runnable check behind non-trivial logic)
  - contract / backcompat
  - audit surfaces / provenance
Deferred: <DEFER-<id>: <ceiling>; <upgrade path> — <OPENQ/DEFER ref>>   (0+ lines)
```

**Terse form for small changes:** `[change] → skipped: [X], add when [Y].`

**Guardrail line is the adherence lever:** by marking each applicable guardrail
`pass | at-risk | n/a`, a dropped traceability or oracle obligation becomes *visible in
the output* rather than silently omitted. Trivial changes collapse to the one-line terse
form (proportionality preserved).

**Delegated scoring (handing a lean-design verdict to another agent).** Run the
[Rubric Preflight Checklist](../design-rubrics/SKILL.md#rubric-preflight-checklist) before
the handoff — specifically P1 (zone declared, scope check, acceptance basis), P2 (itemized
counts, convention uniformity), and P3 (lean ladder trace emitted, direction audit).

## Intent marker — label-native

Mark every deliberate simplification so it lands in review instead of rotting as a bare
comment. Name the ceiling and the upgrade path, and carry a traceable ID.

Pattern: `// DEFER-<id>: <ceiling>; <upgrade path> — <OPENQ/DEFER ref>`

Example: `// DEFER-007: O(n^2) corpus walk; build an index if corpus > ~5k — OPENQ-042`

## Composition

This skill governs how much you build; two siblings govern the rest.

- [`deep-modules`](../deep-modules/SKILL.md) owns shallow-vs-deep. Rung 1's "no speculative
  abstraction" means no *shallow* one — a single-caller module is justified when it hides real
  complexity behind a small interface. When the two seem to conflict, `deep-modules` decides.
- **requirements-enforcement** owns the guarantee set. Its guarantee ledger *is* the
  guardrail list above; this skill only enforces "trim everything the ledger hasn't
  claimed." If both are active, read the ledger before cutting.
- Automated code-health metrics affiliated with this rubric (`dead_export_count`,
  `params_over_6_count`, `undeclared_temporal_contract_count`) are cataloged in
  [`../code-metrics/SKILL.md`](../code-metrics/SKILL.md) — that skill owns their counting
  conventions, direction, and gate-status; this skill owns the qualitative scoring procedure.

## Boundaries

Governs what you build, not how you talk. "stop lean" / "normal mode" reverts. Zone and any
override persist until changed or session end.

The shortest path to done that keeps every guarantee is the right path.
