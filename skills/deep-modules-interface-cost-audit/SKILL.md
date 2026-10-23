---
description: "Run a rigorous, evidence-based deep-modules interface-cost audit (CHEC/ILC/ISC/RCK + evidenced growth-trajectory rows) across a codebase subsystem you scope by an explicit, literal criterion — using independent forward/reverse delegations, cross-checked critiques, and a disciplined reconciliation step. Scales to large scopes via batching."
name: deep-modules-interface-cost-audit
argument-hint: "Describe the subsystem/scope criterion, and optionally a delegation budget"
metadata:
  version: "1.2"
---

# Deep-Modules Interface-Cost Audit

You are about to run a **snapshot audit** — not an A-vs-B design comparison — of a codebase subsystem's interface cost, module by module, using the `deep-modules` skill's CHEC/ILC/ISC/RCK proxies plus its evidenced growth-trajectory rows. Follow this procedure exactly; it is designed to avoid two specific, previously-observed failure modes (see Guardrails).

## Step 0 — Elicit and lock the inputs

Before doing anything else, confirm with the user (do not assume defaults silently):

1. **The literal scope criterion**, in the user's own words, verbatim. Do not paraphrase it into your own framing. Quote it back to them for confirmation.
2. **The delegation budget** — how many subagent delegations (of any kind) they authorize for this run. If they don't state one, propose a number based on Step 2's file-count estimate and ask for confirmation before proceeding.
3. **Whether evidenced growth-trajectory rows are wanted** alongside the snapshot CHEC/ILC/ISC/RCK values, or a snapshot-only audit is sufficient.

## Step 1 — Scope Confirmation (its own delegation; do not skip)

Delegate a read-only research subagent to:

- Quote the scope criterion verbatim in its own output before evaluating anything.
- Enumerate every candidate file and test it **against that literal criterion**, with cited evidence (a docstring, an import statement, a traced call site) — never a paraphrase, and never a narrower proxy criterion (e.g., "does this file understand the domain's own vocabulary" is NOT the same test as "may this file's code execute as part of the traced behavior" — do not substitute one for the other without saying so explicitly).
- Flag, rather than silently resolve, any file where the evidence is genuinely ambiguous — return these to the user as explicit questions.
- Produce the final, confirmed file list, plus a proposed **module order** for auditing it (e.g., dependency order from shared/low-level modules outward to entry points) — this order will be used as-is for the "forward" pass and reversed for the "reverse" pass in Step 3.

**Guardrail (read this before running Step 1):** the single most common way this kind of audit gets mis-scoped is an agent silently substituting a narrower, more familiar scoping test for the user's actual, literal, stated criterion — especially when a narrower framing from a *different, prior* task is still fresh in context. If you notice yourself reaching for a proxy test instead of the user's own words, stop and name that explicitly before finalizing scope, rather than let it silently narrow the result.

## Step 2 — Determine batching from the confirmed file count

One **audit unit** (defined in Step 3) is sized for roughly 15-20 files that one delegation can thoroughly cover in a single pass. Compute the number of batches:

```
batches = ceil(confirmed_file_count / ~18)
```

- If `batches == 1`: run one audit unit (6 delegations) over the whole scope.
- If `batches > 1`: split the confirmed file list into `batches` roughly-even, architecturally-coherent groups (e.g., along a natural seam like "core engine" vs. "delivery/transport layer" — pick a seam that actually exists in the codebase, don't split arbitrarily by file-name order). Run one audit unit **per batch**, plus one additional **Cross-Batch Assembly** delegation and one **Cross-Batch Assembly Review** delegation (below).

State the resulting total delegation count and confirm it fits the user's authorized budget from Step 0 before proceeding — if it doesn't fit, either propose a larger budget or propose merging/dropping batches, and let the user decide; do not silently trim scope to fit the budget.

## Step 3 — The audit unit (6 delegations, repeated once per batch)

For each batch (or once, if `batches == 1`):

1. **Audit A (forward order)** — independent read-only Analyst delegation. For every module in the batch, in the order Step 1 produced: declare the `deep-modules` gate (caller, baseline, capability held constant, confidence) **specific to that module** — different modules in one subsystem often have genuinely different natural callers; a single blanket gate across all of them produces meaningless comparisons. Emit one YAML code-fence per module, shaped per the **raw single-pass** schema in `references/line-item-yaml-schema.md` — a content-addressed `uid` per line-item (not a sequence number), `proxy_claimed` with only this pass's own direction filled (the other side `null`), `description`, `evidence`, and `found_by` naming only this pass; `critique_status` and `reconciliation` MUST be absent at this stage. Explicitly check for **cross-module ILC within the batch** — a decision independently re-implemented in two different files in this batch, not just within one file's functions. Emit any such findings as a top-level `cross_module_line_items` list (sibling to this batch's per-module `line_items`), per the Cross-Module Findings section of `references/line-item-yaml-schema.md`: each item names every implicated module in a required `modules: [...]` field (>=2 entries). Within this single raw report, no evidence-tuple set (the complete `{file, line}` set an item cites) may be claimed by more than one item across the union of a module's own `line_items` and this report's `cross_module_line_items` — unconditionally, whether or not a `cross_module_line_items` entry for it currently exists; if the same evidence plausibly reads as two different buckets, resolve that ambiguity into one item before emitting, never emit two. If trajectory rows were requested (Step 0.3): declare a growth unit per module (complete the sentence *"a year from now we will have more ______"* for that specific module — do not assume it's the same growth unit as any other module without re-deriving it) and report marginal-surface/slope, every growth event cited to a real, named reference (a changelog, a linked design doc, a commit where history exists) — never asserted from reasoning alone, and labeled `[Observed]` / `[Projected]` / `[Hypothesis]`, never blended. Growth-trajectory rows are expressed in the same per-module YAML code-fence, following the `growth_trajectory` shape in `references/line-item-yaml-schema.md`, with each row's citation captured in its `reference` field.
2. **Audit B (reverse order)** — a second, independent Analyst delegation, same instructions, same batch, but given the module list in **exact reverse order**. This is deliberate de-biasing: an anchoring or fatigue effect that favors whichever module a reviewer sees first (or last) is caught by running the same audit in both directions, rather than trusting one order.
3. **Critique A (forward order)** — a Critic delegation reviewing both raw audits from this batch, in forward order, verifying counts against source (not taking either audit on faith), and flagging any occurrence of the Reconciliation Guardrail violation below. For every item in **both** raw manifests, add a `critique_status: { critic_a: confirmed|rejected|not_reviewed }` verdict, keyed by `uid`, per the critique-annotated schema in `references/line-item-yaml-schema.md` — a reviewed item silently skipped reads as `not_reviewed`, not absent. Critiques annotate only: do NOT alter `proxy_claimed`, `evidence`, or `description`.
4. **Critique B (reverse order)** — a second, independent Critic delegation, same batch, reviewing in the opposite order from Critique A, adding its own `critique_status: { critic_b: confirmed|rejected|not_reviewed }` verdict per item under the same rules: every item in both raw manifests gets a verdict keyed by `uid`, and `proxy_claimed`/`evidence`/`description` are never altered.
5. **Reconciliation** — an Analyst delegation producing **one** final per-module manifest for this batch, per the reconciled-with-totals schema in `references/line-item-yaml-schema.md`: merge Audit A's and Audit B's raw manifests by `uid` (falling back to evidence-tuple matching when a careless `uid` prevents a direct match on the same underlying fact), completing `found_by` (union of both passes) and `proxy_claimed` (both directions filled where matched), and carrying over both critiques' `critique_status` verbatim. For every item, fill a non-null `reconciliation: { status, resolved_proxy, resolution_note }`, classifying it as (a) `agreed` (both passes/critiques concur), (b) an *omission* (one audit missed an item the other found — add it, cited), (c) a *bucketing_dispute* (re-apply the skill's strict CHEC→ILC→ISC→RCK first-matching-bucket precedence), or (d) a genuine *interpretive_disagreement* (resolve with a cited reason in `resolution_note`, or leave as an explicit open question — never silently split the difference); `resolution_note` is required whenever `status != agreed`. Additionally emit one script-derived `totals` block per module (`chec`/`ilc`/`isc`/`rck`/`interface_cost` counts, derived from the reconciled items' `resolved_proxy` — never hand-typed). Merge both raw manifests' `cross_module_line_items` the same way (by `uid`, same evidence-tuple fallback, same `critique_status`/`reconciliation` treatment) into one reconciled `cross_module_line_items` list per the Cross-Module Findings section of `references/line-item-yaml-schema.md` — kept as its own list, never folded into any implicated module's own `line_items` or `totals`: an item appearing in `cross_module_line_items` MUST NOT also be counted in any single implicated module's own `totals` block.

   **Reconciliation Guardrail (the single most failure-prone step in this whole procedure):** never introduce an adjusted number that is not shown, derived, and reconciled explicitly against any tabulated number it could be confused with. An untabulated, informally-derived "adjustment" that quietly contradicts a number the same document tabulates elsewhere is the single specific defect this guardrail exists to prevent — it has caused a real, previously-observed methodology failure in this style of audit. If you cannot transparently derive an adjustment from real, cited inputs, report the raw/nominal number instead and say so.
6. **Review-of-Reconciliation** — a Critic delegation checking the reconciliation *itself* (not re-auditing the modules): did it cherry-pick, invent an item, or silently favor one audit over the other? Does every reconciled cell trace to a real, itemized item in one of the raw audits?

## Step 4 — Cross-Batch Assembly (only if `batches > 1`)

- **Cross-Batch Assembly** — an Analyst delegation merging every batch's reconciled table into one, and explicitly hunting for **cross-batch ILC**: a decision independently re-implemented in a module from one batch and a module from a different batch. This check falls through the cracks if each batch is reconciled in isolation, so it must be a deliberate, separate pass, not assumed to be covered by the per-batch reconciliations. Emit any such findings as a `cross_batch_line_items` list, reconciled-stage shape directly (per the Cross-Batch Findings section of `references/line-item-yaml-schema.md`), each entry naming every implicated module (`modules: [...]`, >=2 entries) and every implicated batch (`batches: [...]`, >=2 entries).
- **Cross-Batch Assembly Review** — a Critic delegation applying the same Reconciliation Guardrail to this merge step specifically, including verifying every `cross_batch_line_items` entry's `modules`/`batches` fields and non-null `reconciliation`.

## Step 5 — Final report (not a delegation — you write this yourself)

Consolidate the reconciled table(s) + all critique findings + the cross-batch findings (if any) into one final report, addressed directly to the user. Every other document produced by this procedure is intermediate working evidence; this is the only one meant to be read as a finished artifact. State clearly: this is a snapshot audit of what exists today, not a recommendation to change anything, unless the user separately asked for a recommendation too.

## Scaling note

This procedure is designed to be reusable at any scope size. The audit unit (Step 3) is a fixed 6-delegation cost regardless of subsystem size, as long as one delegation can thoroughly cover the batch it's given (roughly 15-20 files). Larger subsystems consume more total delegations by adding more batches (each +6, plus the fixed +2 for cross-batch assembly once `batches > 1`), never by asking any single delegation to cover more ground than it can thoroughly handle.
