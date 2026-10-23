---
name: deep-modules
description: >-
  Criteria for guiding software design toward DEEP modules — powerful functionality behind small,
  stable interfaces — objective under a stated counting convention and fully auditable. ALWAYS
  applies when comparing two designs (approach A vs B, "should this be one function or several",
  "is this abstraction worth it") or deciding whether to split or merge code or where to draw a
  module boundary — including when the options differ in scope or capability (score the shared
  capability per the gate; a scope mismatch is a reason to normalize the comparison, never a reason
  to skip it). Also applies when reviewing an API or interface, judging abstraction quality,
  spotting leaky interfaces, temporal decomposition, overexposure, or pass-through layers, or
  assessing whether a design is shallow or over-engineered. Also applies when declaring or
  evaluating an extension point, allowlist, protocol-by-convention surface, config-by-example, or
  dispatch table, and whether an interface is extensible — an unannotated one is a leaky interface
  until it carries a definition-site open-or-closed verdict. Converts the deep-module philosophy
  into countable proxies — interface surface, leakage, caller knowledge, handled errors, common-case
  tax, change amplification, and required growth-unit / marginal-surface / slope trajectory rows —
  so designs are compared consistently and disagreements are explained with evidence rather than
  taste, backed by qualitative tie-breakers (hard-to-describe, naming, obscurity) when counts tie.
  Produces a count-based A-vs-B scorecard with required trajectory rows, a confidence level, and a
  blind-spot declaration. Triggers even when the term "deep module" is not used.
---

> Part of the **design-rubrics** family — see [`design-rubrics`](../design-rubrics/SKILL.md) for
> which rubric applies when, and the shared output contract. This skill covers the
> **between-units interface** lane.

# Deep Modules

## Why this skill exists

A module is **deep** when it provides a lot of functionality through a small, simple interface.
It is **shallow** when its interface is nearly as complicated as the functionality it provides —
the interface costs almost as much to learn as just doing the work yourself. The canonical deep
module is Unix file I/O: five calls (`open`, `read`, `write`, `close`, `lseek`) hide disk-block
layout, buffering, scheduling, permissions, and device differences. The canonical shallow module
is a class whose every method is a thin pass-through to something else.

Depth is the ratio of *benefit* (functionality the caller gets for free, and need not understand)
to *cost* (everything the caller must learn, pass, sequence, and handle to use it). Deep modules
win because **interface cost is paid by every caller, on every use, forever; implementation cost
is paid once, by the author.**

Use this skill to flag shallowness early and to adjudicate competing designs with counts instead
of taste.

## Scope: any caller-facing surface, not just source code

"Module" and "interface" are read broadly. The rubric applies wherever a **caller** (human, agent, downstream system) consumes a **surface** (a public API, a CLI, a documentation tree, a folder layout, a labeling convention, a template structure, a configuration shape) to obtain a **capability**. Code is the dominant case and the language below is code-flavored; the proxies — CHEC, ILC, ISC, RCK — translate directly. A folder name leaking an internal taxonomy is ILC; a legacy term the reader must translate is RCK; a navigation dead-end the reader must back out of is CHEC. Use the rubric on a non-code surface when (a) you can name a specific caller class and its baseline, (b) two or more concrete options exist, and (c) capability equivalence holds (the options deliver the same thing).

## What "objective" means here

"Objective" means **objective under a stated counting convention**, not measurement physics. The
counting procedure below is fixed, so a reviewer who follows it produces a repeatable result, and
any disagreement between two reviewers **localizes to a specific item** — "is this one concept or
two?" — that can be inspected and argued from evidence rather than vibes. State the counting
assumptions in the scorecard so the verdict is auditable, and record a confidence level so the
rubric never manufactures false certainty.

The counts are the spine. Three **qualitative tie-breakers** (hard-to-describe, naming difficulty,
obscurity) sit beside them and fire **only when the counts tie or confidence is Low** — they break
deadlocks and catch surface the slot-counting missed; they never override a clear count delta.

---

## The four concepts (definitions for context)

**Interface surface.** Everything a caller must know to use the module *correctly*. It has an
**explicit** part (signatures, parameters, return types, config, public errors, **and the interface
comment**) and an **implicit** part (required ordering, lifecycle/state preconditions, side effects,
units, nullability, idempotency, thread-safety). For counting, the explicit part becomes `ISC` and
the implicit part becomes `RCK` — the implicit part is where most surface hides and most bugs come
from. One structural cause worth naming: **overexposure** — when using a *common* feature forces the
caller to learn *rare* ones (see guideline 2 for the canonical definition and CCT).

**Implementation exposure / context leak (information leakage).** A design decision that lives
inside the module nonetheless escapes — into the interface, or into the caller's head. It leaks
when (a) an internal representation appears in a signature or return type, (b) the *same* decision
is encoded on both sides of the boundary so a change forces synchronized edits, or (c) the caller
must reproduce the module's internal ordering of steps. Leakage is the opposite of encapsulation
and the most common cause of shallowness. Its most common *structural* cause is **temporal
decomposition** — splitting modules by the time-order of operations (read, then modify, then write)
instead of by knowledge, which strands one decision in two places.

**Abstraction quality.** A good abstraction *omits* unimportant detail and *captures* the
important detail. It fails two ways: a **false abstraction** hides something the caller needs (so
they must read the source), and a **leaky/over-detailed abstraction** exposes detail the caller
does not need. Practical test: *how often must a correct caller read the implementation?* A second,
cheap test: *can you write the interface comment in one short, complete sentence?* If not, the
abstraction is probably wrong (see Hard-to-Describe).

**Cognitive load — at the module level, not the implementation level.** *Implementation-level*
complexity lives *inside* a module. *Module-level* load is what a developer must hold in their head
to *use or change the system through this module's interface*. **Deep design concentrates
complexity at the implementation level (hidden) and minimizes it at the module level.** High
implementation complexity is fine when it buys low module-level load. The failure to flag is the
inverse: a module trivial inside but forcing the caller to know a lot — that is shallow. The most
dangerous form of module-level load is the **unknown unknown**: a fact a maintainer must know to
change the system correctly, but which nothing at the change site reveals.

**Disclosing a bounded gap converts an unknown unknown into a counted one — that is the honest
move, and the scorecard should not punish it.** A limitation named in the contract becomes a
visible ISC or RCK line-item; the same limitation left unstated is counted nowhere and stays an
unknown unknown. So on `TOTAL` alone silence scores better than candor — an artifact of what the
proxies can see, not a property of the design. Prefer the disclosed version, record the
line-item, and read a lower `TOTAL` earned by omission as the measurement failing rather than the
design winning. (`requirements-enforcement`'s `G-D-BLIND` is where the obligation to disclose is
tracked.)

---

## The objective depth model — the counting convention

Depth is `functionality / interface-cost`. Functionality resists counting in the abstract, so make
the comparison concrete by **holding the capability constant** (see the gate); the depth difference
then reduces to interface cost, which you *can* count.

Count four proxies. **Assign every observed item to the FIRST matching bucket, top to bottom.**
This precedence keeps the buckets mutually exclusive and the total free of double-counting:

**What the order is, and what it does not claim.** Three of the four positions are forced by the
predicates themselves — ISC takes only what is "not already CHEC/ILC", RCK only what is "NOT
visible in the signature" — so each is residual to the rows above it. The one free adjacency is
**CHEC before ILC, and that is convention, not severity.** Any fixed order removes
double-counting; a *stated* one is what makes two reviewers reach the same assignment for the
same item. When an item genuinely matches both — the canonical case being a leaked internal
error type, a branch the caller must handle *and* an internal fact that escaped — charging it
CHEC is a **recording choice, not a claim that the caller-handled burden is the worse one**.

Two consequences, stated rather than left implicit. The bucket routes the item to a guideline
and therefore to a prescription (ADR-003's proxy→guideline mapping), so precedence shapes the
recommended remedy even though `TOTAL` is identical either way. And the order is deliberately
**stable**: reordering would move cross-axis items between buckets, change those prescriptions,
and make new scorecards non-comparable with every existing one — buying nothing the convention
does not already provide.

| Order | Proxy | Assign here if… | What to count |
|---|---|---|---|
| 1 | **CHEC** — Caller-Handled Error Conditions | the caller must branch on it as a failure to be correct | distinct failure/error variants the caller handles |
| 2 | **ILC** — Information Leakage Count | it is an internal implementation fact that escaped and should not be exposed | leaked storage/wire types, decisions duplicated across the boundary, pass-through methods/variables, protocol/framework details, **a shared decision stranded across a temporal split** |
| 3 | **ISC** — Interface Surface Count | it is visible in a signature, public type, required doc, **or the interface comment** (and is not already CHEC/ILC) | entry points, distinct parameter **concepts**, config knobs, distinct *success*-return shapes the caller branches on |
| 4 | **RCK** — Required Caller Knowledge | a correct caller must know it *above the declared baseline* (see gate) and it is NOT visible in the signature | module-specific ordering/lifecycle, units, nullability, idempotency, thread-safety, side effects, partial-failure semantics |

**Count concepts, not slots (ISC).** ISC counts *distinct concepts a correct caller must supply or
understand from the contract*, not signature tokens. A single `options`/`config`/`context` object
counts as the number of fields the caller must actually set, **not 1**; a tuple return the caller
must destructure counts by its meaningful parts. The honest measure of ISC is the length of the
*complete* one-sentence interface comment (see Hard-to-Describe). This closes the most common
gaming hole: collapsing ten parameters into one struct does not make a module deep.

**RCK is relative to a baseline.** Baseline competence (declared in the gate) is **free and never
counted**. An interface expressed in a language the caller already commands adds capability at ~0
RCK. Two reducers push RCK toward zero: **shared vocabulary** (build on a standard the caller
already knows — SQL, regex, JSON, paths; see [examples/06-shared-vocabulary-interfaces.md](examples/06-shared-vocabulary-interfaces.md)
for an orthogonal catalog — git, HTTP, pipes, cron, Make, CSS selectors, semver) and **discoverability** (facts the caller can introspect
at runtime — queryable schemas, capability/help endpoints — are *fetched, not carried*, so they
aren't RCK).

**Data model as contract is not leakage.** When a data model is *deliberately* exposed as the
public contract (a substrate — see the reframe section), its schema is interface (ISC), not a leak
(ILC). The cost does not vanish; it relocates to **schema stability** (changing it breaks callers),
which is a versioning concern, not a per-call cost.

`InterfaceCost = ISC + ILC + RCK + CHEC`, **counted once, per representative caller.** Do not
multiply by call sites here.

**Depth proxy:** `Depth ≈ Capability / InterfaceCost`. For the same capability, the design with the
**lower `InterfaceCost` is deeper.** Always list the items behind each count so the verdict is
auditable.

### Two derived counts (CCT and CA)

**CCT** (Common-Case Tax) — of ISC+RCK items, how many exist only for rarer tasks? CCT > 0 signals
**overexposure**; target zero-config for the common case.
**CA** (Change Amplification) — distinct sites to edit for one logical change; CA > 1 signals a
leaked/duplicated decision. CA is the maintenance-time face of ILC.

CCT and CA are **not** added to `InterfaceCost`; report them alongside it when relevant.

**Never write "CHEC" for the common-case tax.** The abbreviation is **CCT**; `CHEC` is always
Caller-Handled Error Conditions. The collision mis-scores twice in opposite directions — it
inflates a summed proxy with a derived count, and it hides the overexposure signal the firewall
keeps deliberately unsummed.
See [references/derived-counts.md](references/derived-counts.md) for full mechanics and Example-08 linkage.

**Call-site count `N` enters ONLY in the pull-complexity-down economics (guideline 1)** — never in
the depth comparison itself.

**One-time and non-interface costs are NEVER proxies.** Transition cost, migration effort, schedule,
and risk are one-time author-paid costs — not durable per-caller costs. They belong **only** in
Block 3 (Non-metric Factors & Recommended Action) of the scorecard. Never count them in Block 1,
and never let them alter the Block-2 Depth Verdict.

**Itemized counts are mandatory.** Every proxy count MUST be backed by **named line-items** (one
concept per item); a bare number without line-items is invalid. State items before the count:
`ISC: [entry-point X; param Y; config knob Z] = 3`.

**Confidence.** Record a level with every verdict:
- **High** — same capability, declared caller, real call sites visible.
- **Medium** — capability clear, but call-site count or future variation is estimated.
- **Low** — boundary or caller needs still unclear; treat the verdict as provisional, and let the
  qualitative tie-breakers carry more weight.

**Emission format (pointer — `design-rubrics` is authoritative).** Emit the verdict using the shared **Compact decision template** in [`design-rubrics`](../design-rubrics/SKILL.md#compact-decision-template): header block (Caller / Baseline / Capability-held-constant / Equivalence / Confidence), **dimensions as rows, options as columns**, a direction column, itemized counts (never bare numbers), and a blind-spot line. Do NOT copy or restate the template here — single source of truth. Shape checklist: ☐ header block present ☐ dimensions = rows & options = columns ☐ itemized counts (not bare numbers) ☐ confidence + blind-spot line.

---

## Gate: declare the caller, then check capability equivalence (run BEFORE scoring)

Two questions must be answered before counting anything. Skipping the gate is the most common way
the scorecard produces a confident-but-meaningless result.

**Step 1 — declare the caller and baseline.** Who consumes this interface, and what do they already
command? For **agent consumers** — the default for code this skill governs — the baseline is
**general frontier-model knowledge**: SQL, regex, JSON, HTTP, file paths, shell, common formats and
idioms. State it explicitly. RCK is counted *only above this baseline*. Caveat: only
**broadly-known standards** count as baseline. A niche or proprietary DSL is **not** baseline just
because the caller is an agent — name it and count it as RCK. The caller need not be a program. For documentation, layout, or convention decisions, the caller is the human or agent reading the artefact; the baseline is what they already command before reading (repo navigation, Markdown, the project's *current* vocabulary — not its legacy vocabulary, which is RCK).

**Step 2 — capability equivalence.** Are A and B delivering the same capability?
- **Yes** → proceed; count `InterfaceCost` for each.
- **Mostly** → score only the **shared** capability; list each design's extra separately and
  require a *current* caller to justify it. Unjustified extra is surface nobody asked for; the fix
  is usually to **unbundle** it, not to "simplify" the overloaded design in place. (Exception: when
  the extra capability adds ~0 interface surface — see Example 3 — the superset design simply wins.)
- **No** → do not score yet; first normalize (reduce both to the shared job, or split the question).

**Delegated scoring (handing a prompt to an analyst or another agent).** Run the
[Rubric Preflight Checklist](../design-rubrics/SKILL.md#rubric-preflight-checklist) before
the handoff — P1 enforces gate, conventions block, scope check, and acceptance basis in one
step; P2 gates acceptance; P3 audits the verdict before it is published.

---

## Design it Twice (run in planning, BEFORE you have an A and a B to score)

Before scoring, generate at least two *radically* different candidates — not variations on one idea.
The contrast exposes which details are essential vs. accidental to the first idea. At least one
sketch must probe the category-collapsing reframe below.

For load-bearing architectural decisions (foundational interfaces, cross-module contracts,
hard-to-reverse choices), load `../brainstorming/SKILL.md` for structured divergence before
returning here with your A and B.

---

## Design-philosophy guidelines and how to evaluate A vs B on each

### 1. Pull complexity away from the interface (pull it downward)

**Principle.** Absorb unavoidable complexity into the implementation, not the interface, because
the author pays implementation cost once while every caller pays interface cost repeatedly.

**Signals it pushed complexity up:** the caller passes config the module could default; runs a
setup/teardown dance; writes the same boilerplate around every call; handles an error the module
could resolve.

**Objective A-vs-B rule.** Compute `CallerCost = InterfaceCost × N` (N ≥ 2 for reusable/library
code; else projected count) and a one-time `AuthorCost` (extra internal branches/states). **Prefer
lower `CallerCost` even when `AuthorCost` is higher.**

**Trap to flag.** Pulling down only counts if it stays *encapsulated*. Verify `InterfaceCost` did
**not** rise. If complexity re-surfaced as new errors/states/knowledge, it was **relocated, not
pulled down** — score it as no gain.

**Author:client asymmetry — non-summed, and only with ≥2 caller classes.** When a module is
called both by code its own author writes and by client code written without knowledge of the
internals, score `InterfaceCost` separately for each class and record the ratio
`client-caller InterfaceCost : author-caller InterfaceCost` in the scorecard's existing
`Attention` column. A ratio well above 1 says the interface is affordable only to someone who
already holds the internal model — **small, but not deep**. This is the read that separates a
genuinely deep interface from a merely small one, and an aggregate `InterfaceCost` averages it
away.

**Both operands are durable per-caller costs — `AuthorCost` is not one of them.** Despite the
name, *author-caller* `InterfaceCost` is the recurring cost paid by the author's own calling
code, not the one-time implementation cost defined above. Putting `AuthorCost` in this ratio
divides a recurring cost by a one-time one and yields a number that means nothing.

Record it, never sum it: the ratio does not enter `InterfaceCost` or `TOTAL` (ADR-003 firewall),
though it may inform a tie-break or verdict. It carries **no fixed interpretation at the low
end** — a ratio near 1 is not by itself evidence of depth.

**Inverse, stated positively — facade-preserving decomposition is a deep move.** Splitting a large
module's *internals* into several cohesive sub-modules while the public **facade holds ISC flat**
(same entry points, same signatures, behaviour-invariant) raises no interface cost: the caller sees
the same small surface and the implementation-level complexity drops. That is deepening, not shallow
boundary-multiplication — the multiplication is *internal*, behind a stable facade. Score it as new
surface **only** if the split leaks a sub-module into the facade (a new entry point, a moved type in
a signature).

#### Transition cost — a one-time meta-cost the rubric does not score

The rubric measures durable per-caller interface cost. It does not score the **one-time author-paid cost** of getting from today's design to a deeper one — `git mv`, cross-reference updates, doc churn, deprecation cycles. This is conceptually parallel to the `AuthorCost` vs `CallerCost × N` distinction above, and generalizes beyond code to renames, restructures, and folder reorganizations. State it; do not let it veto a depth verdict unless the migration cost is large *and* the depth gap is small. **Avoid the failure mode where transition cost is mistaken for a fifth proxy** — it is not on the scorecard. (See [Worked example 4](examples/04-docs-folder-naming.md) for a cross-domain case where transition cost is called out explicitly.)

### 2. Favor general-purpose interfaces — and make the common case simple

**Principle.** A slightly general interface is usually simpler, deeper, and absorbs future needs
without churn. Special-purpose interfaces multiply near-duplicate methods and bake the current
caller's situation into the API. Independently, the **common case should be simple**: the most
frequent task should need the least knowledge, and desirable behavior everyone wants (buffering,
retries, sensible defaults) should be automatic, not opt-in. (For the strong form — replacing a
*menu* of endpoints with a *substrate* the caller composes — see "Look for the category-collapsing
reframe".)

**Signals (too special-purpose):** names encode a use case or caller (`deleteSelectionOnBackspace`)
rather than an operation (`delete(range)`); methods differing only by which special case they
handle; the interface "knows who is calling it."

**Signals (overexposure):** the common task requires constructing or composing objects that exist
for rare tasks (`new BufferedInputStream(new FileInputStream(path))`); a flag every caller sets the
same way; the caller must learn a rarely-used feature to reach a commonly-used one. → **CCT > 0.**

**Objective A-vs-B rule.** As counts:
- *Simplest interface covering all current needs?* If N special methods collapse into M < N general
  methods that satisfy **every current call site**, the general design has lower ISC and is deeper.
- *Common-case tax?* Prefer the design with the lower **CCT**; ideally the common case is
  zero-config and the rare capability is an opt-in that adds 0 common-case surface.
- *In how many situations is each method used?* A one-situation method is a candidate to generalize
  or fold into its caller.
- *Still easy for the current need?* Guard against over-generalization: if going general forces
  every caller to write adapter glue (raising RCK), it went too far.

Prefer the design satisfying all *current* call sites with the fewest entry points, the lowest CCT,
**and** no use-case/caller vocabulary. General *because of current callers*, never speculative ones.

### 3. Define errors out of existence

**Principle.** Every error the caller handles is CHEC and a branch in their code. The strongest
reduction is designing the *semantics* so the condition is no longer an error: deleting a missing
key succeeds; an over-range read clamps; closing a closed handle is a no-op; deleting an open file
is allowed and deferred (Unix) rather than refused (Windows).

**Hard caveat — always state it.** This means *redefining the normal case to include the formerly
exceptional input*, **not swallowing genuine failures.** A masked fault is worse than a thrown
exception. Test: *would a correct program ever legitimately hit it?* Yes → define it away. Only on
breakage (corrupt state, contract violation) → it stays an error. Two further reductions when you
*can't* define it away: **mask** it (handle low and don't propagate) or **aggregate** many
special-case handlers into one general handler.

**Objective A-vs-B rule.** Compare `CHEC`; **prefer lower.** The design that turns a former error
into defined normal behavior — without masking a fault — is deeper. **Flag** any error where every
caller handles it identically, or handles it by doing what the module could do itself.

### 4. Complementary code belongs together (and beware splitting by time)

**Principle.** Code that shares a design decision, is always used together, or can't be understood
independently should live together. Splitting it leaks information across the seam and forces
synchronized edits. Independent code, and special-purpose code mixed into general-purpose code,
should be pulled apart. The most seductive wrong split is **temporal decomposition** — organizing
modules by *when* steps run (reader → transformer → writer) rather than by *what knowledge they
hold*. Order usually matters and will live somewhere, but it should not drive the module boundary
unless the boundary also hides distinct knowledge.

**Signals (wrongly split):** one decision encoded in two places; you must read/edit two modules to
change one behavior (**CA > 1**); the pieces always appear in the same commit; one is meaningless
without the other (**conjoined methods**); the boundary names a phase (`read*`/`write*`,
`encode`/`decode`, `setup`/`teardown`) and both sides share a format/schema/protocol.

**Signals (wrongly together):** a nontrivial block of logic is copy-pasted across sites
(**repetition**, CA > 1 for a single logical change); special-purpose code is interleaved with the
general-purpose code it specializes.

**Objective A-vs-B rule.** `CouplingCount` = (shared decisions crossing the boundary) + (1 if they
always change together, i.e. CA > 1) + (1 if understanding one requires reading the other). High
across a *proposed split* → keep together; low across a *proposed merge* → keep apart. Prefer the
arrangement minimizing (leakage across boundaries) + (modules touched per logical change). Flag
**change amplification** — one logical change, many edits — by reporting CA explicitly.

> **Cross-rubric note.** Temporal decomposition is a *module-boundary* smell (between-units: ILC
> across the seam, CA > 1 across modules). It is distinct from [`functional-core`](../../skills/functional-core/SKILL.md)'s
> *temporal coupling* (TCC) — a within-a-unit ordering edge between statements or functions inside
> a single module. The router ([`design-rubrics`](../../skills/design-rubrics/SKILL.md)) partitions
> the two rubrics on exactly this between-units vs within-a-unit axis.

**Cross-unit ownership of a shared signal is ILC.** When one logical thing — a signal, an emitted
correction, a contract field, a backlog row — has its *definition* split across two modules or plans
(its kind declared in one, its emit-point in another), that is "one decision encoded on both sides of
the boundary" and scores as **ILC** (leakage), not as two independent surfaces. Trap: a
"no-duplication" contract test detects *collisions* (both sides declare it) but **not** *orphans*
(each side assumes the other owns it), so it passes trivially and gives false comfort. Assign each
shared signal exactly one owner for **both** its kind and its emit-point; shared *data* (a parsed
column, a metadata table) may be consumed by many, shared *definition* may not. For a worked non-code case — a counting-convention catalog federated across non-owning rubrics — see [examples/10-convention-ownership.md](examples/10-convention-ownership.md).

### 5. Extension points declare open or closed at their definition site

**Principle.** An allowlist, protocol-by-convention surface, config-by-example, or dispatch table
is a caller-facing surface exactly like a public method — a future extender must be able to tell,
without tracing every call site, whether the surface accepts new members. **An extension point declares open-or-closed at its definition site; a capability-limit claim is verified structural-vs-policy before assertion.** An unannotated extension point is a leaky interface: the
caller cannot tell a wall from a door, and every future extender re-derives the answer from
scratch — a caller cost the interface should have absorbed once, at the definition site.

**Signals it's unannotated.** A bare literal (list/set/dict) with no adjacent comment stating
whether growth is expected; a structurally-identical sibling surface carries a verdict comment
and this one doesn't; an agent or reviewer must trace fan-out call sites to guess whether adding
a member is safe, rather than reading a verdict.

**Objective A-vs-B rule.** Score an unannotated extension point as **ILC** (the open/closed
verdict is knowledge the caller must derive elsewhere) until its definition site states either:
**open** — the extension procedure (what to add, plus what else must change) and the fan-out
cost — or **closed** — the ADR/decision that froze it. Either verdict resolves the leak; treating
a bare allowlist as closed by default, with no cited decision, is not a verdict — it is the same
unverified guess the principle exists to catch. The durable inventory (fan-out files, sibling
names) belongs in one maintained register (see `architecture-patterns`' Extension-Point Register
Template), not duplicated inline at every definition site.

---

## Look for the category-collapsing reframe

Scoring A vs B optimizes *within* a frame. The largest wins come from a frame change — an Approach
C that makes a whole class of endpoints unnecessary. Agents under-find these because they refactor
incrementally. Before settling on A vs B, run two checks:

**Menu vs substrate.** A *menu* adds one entry per anticipated need (`getUsers`, `getOrders`,
`searchByX`…); its surface grows with requirements. A *substrate* exposes general primitives the
caller composes (a queryable store, a filesystem, an expression language), grows ~0 surface as
needs grow, and yields capability you never designed for. When several endpoints differ only in
*which* slice of data or *which* operation, and those operations are expressible as data
manipulation, the substrate reframe is on the table.

**Marginal surface (trajectory).** Don't score only today's `InterfaceCost` — this is exactly what
the required [Trajectory rows](#trajectory-rows-required-in-every-comparison-scorecard) measure;
run that section's growth-unit / Δ / slope / crossover procedure rather than eyeballing it here. In
the menu-vs-substrate case specifically, a menu adds ~1 entry per requirement (rising slope) and a
substrate adds ~0 (flat) — a small menu on a steep slope loses to a slightly larger substrate that
is flat, and the crossover formula says exactly at what count.

A substrate is deep **only when its guardrails hold** — otherwise it is shallowness relocated into
the caller's queries:
- the caller commands the substrate language (it is baseline → ~0 RCK);
- common needs stay one-liners (no boilerplate → not pushed up; CCT ≈ 0);
- the exposed data model is a *deliberate, stable, discoverable* contract (then it is ISC, not ILC);
- it opens no unbounded failure modes the caller must now manage (watch CHEC).

**"Stable" is the guardrail that gets asserted — measure it.** Of the four, schema stability is
the one a reviewer can grant by adjective, and a substrate whose schema churns is a menu with
extra steps: every break is paid by every caller at once, which is the cost the substrate was
supposed to avoid. **Primary measure: the observed count of breaking schema changes over the
last N released versions of that contract**, with N stated and the breaks listed. Zero over a
meaningful N earns the word. A new or unreleased schema has no record and says so — `Schema
stability: no record (N=0 releases)` — rather than borrowing the word on intent; an unproven
schema is not disqualifying, but it is a declared risk rather than a satisfied guardrail.

`code-metrics`' `instability` and `sdp_violations` are **reference only** here. They measure
coupling direction in the code, not whether this contract has broken its callers, so they may
inform a verdict but never stand in for the observed count — and never enter `InterfaceCost`
(ADR-003 firewall: non-proxy signals are recorded beside the scorecard, never summed into it).

When those hold, prefer the substrate even at higher `AuthorCost`. **Reward the property — flat
marginal surface within correct boundaries — not raw count minimization.** Minimizing endpoint
count alone invites over-merging pieces that should stay apart (guideline 4).

---

## Qualitative tie-breakers (fire ONLY on ties or Low confidence)

When two designs come out within ~1 of each other on `InterfaceCost`, or confidence is Low, these
named checks break the deadlock. They are deliberately not numeric — they catch surface the
slot-counting missed. **They never override a clear count delta**; a design that is 14 vs 4 does not
get rescued because it has a nicer name.

**1. Hard-to-Describe (required ISC-honesty check — also required in Block 1 of every scorecard).**
Write the *complete* one-sentence interface comment for each design's main entry point —
everything a caller needs, nothing about the implementation. The design whose comment stays short
and complete is deeper. This is the most reliable cross-check on ISC and closes the config-object
gaming hole: if `ISC` looks like 1 but the honest comment runs a page, trust the comment over the
count. (For a non-code surface, substitute "description of the surface" for "interface comment".)

**2. Naming precision & 3. Obscurity / unknown unknowns.** See
[references/qualitative-tiebreakers.md](references/qualitative-tiebreakers.md) for full
definitions. In brief: prefer the design whose central name comes easily and reads cleanly
(naming), and the one where a future change touches fewer distant / unknown sites (obscurity).

---

## Workflow: three modes

**Planning mode** — first run **Design it Twice**: sketch two or three radically different shapes, one
probing the reframe. Then run the gate, the four guideline questions, and the reframe checks. Flag
shallow proposals, premature boundaries, temporal decomposition, defaultable config, overexposure,
and use-case naming.

**Implementation mode** — flag at the moment of surface growth, *before* adding it: a new
parameter/flag/error type; an internal representation in a signature/return; a pass-through method;
a decision pushed to the caller; a split of tightly-coupled code; a module boundary drawn around a
phase rather than a body of knowledge.

**Review mode** — score only **public-facing changes**, *unless* an implementation split leaks
across a boundary (then score that boundary). For each interface: count the four proxies (plus CCT
and CA where relevant), check the four guidelines, run the tie-breakers if it's close, and report
**guideline violated + signal observed + deeper alternative**. For two approaches, produce the
scorecard.

---

## OPENQ Framing (pointer — `design-rubrics` is authoritative)

When emitting an OPENQ about an interface-boundary decision, the compact framing template lives
in [`design-rubrics` OPENQ-framing mode](../design-rubrics/SKILL.md#openq-framing-mode-authoritative-template).
Do NOT copy or restate the template here — single source of truth; lean cost axes for
scope/policy questions do not belong in this between-units interface lane (would create ILC
and invite drift with the rubric split).

**Gate-first guardrail.** Run the deep-modules gate (declare caller + baseline; confirm
capability equivalence) **before** scoring any interface-shaping OPENQ with CHEC/ILC/ISC/RCK.
A scorecard without a declared gate produces confident-but-meaningless numbers.

**No four proxies on scope/policy questions.** If the OPENQ's answer determines *what to build
or include* — not *how to shape a caller-facing surface* — it is scope/policy; use lean cost
axes instead. See the [`design-rubrics` OPENQ-framing mode](../design-rubrics/SKILL.md#openq-framing-mode-authoritative-template)
for both branches.

For worked examples of OPENQ framing in practice (happy-path, variations, and ambiguous edge
cases), see the [OPENQ Framing Example Index](../design-rubrics/SKILL.md#openq-framing-example-index) in `design-rubrics`.

---

## What a depth verdict does NOT establish (pair with seam-validation)

A depth score is auditable but bounded. It tells you whether a surface is *justified*; it does
**not** establish that:

- **the seam exists** — that the emit-point / extension-point / boundary you scored is actually
  present in the code (a verdict has been shipped naming a seam that did not exist);
- **ownership is singular** — that a shared signal/row has exactly one owning unit (guideline 4 —
  split definition is ILC, and a no-duplication test misses *orphans*);
- **cross-unit sequencing holds** — that the units this design depends on are committed / ordered so
  the boundary can be built as scored.

For any design touching ≥2 existing seams, pair the verdict with a seam-validation pass. See
[references/seam-validation-procedure.md](references/seam-validation-procedure.md) for the
step-by-step procedure.

**Depth ≠ size.** A large unit is not automatically a split candidate. A module with one cohesive
responsibility and low caller-knowledge is deep regardless of line count; a line-count screen may
flag it, but the depth/coupling verdict governs — the lean call on a big-but-cohesive unit is *leave
it whole*. (File-split decisions route through [`functional-core`](../functional-core/SKILL.md)'s RCC
trigger; the anti-overcorrection check lives in [`lean-design`](../lean-design/SKILL.md) "earn a name".)

---

## Trajectory rows (required in every comparison scorecard)

Every Block 1 that compares two or more options carries three additional rows beneath the four
proxy counts. This is a **rubric extension, not an optional embellishment**: a scorecard reporting
only today's `InterfaceCost` answers "which is cheaper to adopt," never "which is cheaper to live
with" — and the second question is almost always the one actually being decided. A scorecard
missing these rows is **incomplete**, in the same sense as a bare proxy count with no itemized
line-items (see "Itemized counts are mandatory," above).

**A scope mismatch does not exempt a comparison.** If the gate (Step 2) returned "Mostly," score
the *shared* capability's trajectory as usual and list each design's unjustified extra separately —
exactly as the base counts already require. The only exemption is a genuine one-off, no-growth
decision (see Growth unit, below), and that exemption must be stated, never assumed by omission.

### 1. Growth unit — declare before scoring, in the Block 1 header

The countable thing the requirement multiplies in. Complete the sentence *"a year from now we will
have more ______"* — the answer is the growth unit. Prefer the count a stakeholder already tracks
(tables, endpoints, message types, tenants, device models, report kinds) over one invented to make
the comparison land somewhere convenient — inventing the unit to flatter a preferred option is a
named failure mode below.

- **The unit is the domain's, not either design's.** If A naturally grows per table and B per
  message type, normalize both to the unit the *requirement* grows in — do not let each option
  report its own unit. If the two genuinely cannot be normalized, that is a capability difference
  and belongs in the gate (Step 2), not smuggled into the trajectory rows.
- **State the current count** when known — `Growth unit: allowlisted table (67 today)` — it anchors
  the crossover computation below.
- **If no growth unit exists**, write `Growth unit: none — one-off decision, no trajectory` and
  omit rows 2 and 3. A legitimate, informative result — never manufacture a unit just to fill the row.

### 2. Marginal surface — `Δ<proxy> per <growth unit>`

The change in a Block-1 proxy (CHEC, ILC, ISC, or RCK) when exactly **one** growth unit is added,
counted by the *same* convention as the base count and itemized the same way. **Marginal is the
derivative of a count you are already taking — never a new dimension introduced only for this row**
(see Failure modes, below).

Two ways to obtain it, in strict preference order:
- **(a) Observed** `[Observed, n=3]` — count the last three real additions of that growth unit from
  the repo, changelog, or ticket history; report the median (and the range if it varies). Preferred
  wherever history exists.
- **(b) Projected** `[Projected]` — walk one hypothetical addition through the design and count what
  it forces. Fallback only.

**Never blend the two labels into one number, and never omit the label.** An observed 8 against a
projected 0 is not an apples-to-apples comparison — the asymmetry in evidence quality is itself part
of the finding, and Confidence should reflect it (Medium/Low when either side is projected).

### 3. Growth slope — derived from row 2, never assigned by judgment

| Δ per growth unit | Band |
|---|---|
| 0 | **flat** |
| 0 < Δ ≤ 1 | **rising (linear)** |
| Δ > 1, constant | **rising (steep)** — state the multiple |
| Δ grows with the running count | **compounding** — name the coupling that causes it |

A compounding slope almost always has one driver — each addition must be integrated with every
prior one. Name that driver. **Always show the Δ that produced the band** — a band with no number
behind it is an opinion, not a count.

### Crossover — compute it, do not assert it

When one option has a lower base `InterfaceCost` but a steeper slope, the winner depends on how
many growth units accrue. Compute where the lines cross — `G` is the count of growth units elapsed,
**distinct from the call-site count `N`** used in guideline 1's pull-down economics; do not conflate
the two:

```
G* = (InterfaceCost_high − InterfaceCost_low) / (Slope_low − Slope_high)
```

- **Horizon known** → compare it to `G*`; the Block-2 trajectory reading follows from the
  arithmetic, not from judgment.
- **Horizon unknown** → say so explicitly, and default to the flatter option, because its cost is
  bounded regardless of how many units accrue. State this as a **declared default**, never as an
  assumption folded silently into a total.
- **One option is both lower-base and flatter** → it **dominates**; skip `G*` — computing it would
  produce a number with no decision content.

**Where the trajectory reading lives — and why it is not a fifth proxy.** Report `G*` and the
horizon comparison in **Block 2**, as a *derived, non-summed* reading beside the InterfaceCost
verdict (see the Block 2 skeleton below). It never enters `InterfaceCost` and never enters `TOTAL`
— `InterfaceCost` remains the only **scored** axis, per [ADR-003](../../docs/adr/ADR-003-deep-modules-metric-firewall.md).
Marginal surface is nonetheless a *durable per-caller* cost, so it belongs on the metric side of
the firewall (Block 2) rather than among Block 3's one-time factors.

When the trajectory reading contradicts the today-reading, **Block 2 resolves it internally** with
the crossover arithmetic and records both readings. This is emphatically **not** a Block-3 override:
the override gate exists solely for *one-time* costs (transition, migration, schedule, risk) and
keeps its `gap ≤ 1` window untouched. Do not route a trajectory divergence through Block 3, and do
not relabel a one-time cost as "trajectory" to avoid the gate — that is the contamination vector
ADR-003 was written to close.

### Gate rows — one boolean row per stated constraint an option could fail

Beyond the trajectory rows, add `Satisfies <CON-ID>: yes/no` per option for every **pre-existing**
stated constraint an option could fail:

- **Cite the constraint by ID or verbatim quote.** No exceptions.
- **The constraint must pre-date the scoring** (a requirements doc, a plan constraint, a written
  user statement). A criterion invented while scoring is the most common way a trade study gets
  rigged, usually without intent — this is the stated-requirement sibling of the runtime-hazard
  probes (P1-P4) in the [`design-rubrics`](../design-rubrics/SKILL.md) "Hazard probe" section; the
  two are complementary, not overlapping — hazards are *discovered* risks, gate rows are *declared*
  requirements.
- **Evaluate gate rows before totals.** A failing option is excluded **at the gate, not on points**
  — score it anyway for completeness and to show what is being given up, and say plainly it was
  excluded by constraint rather than by cost.
- **No stated constraints → no gate rows.** Do not manufacture them to eliminate a disliked option.

### Worked example

```
Growth unit: allowlisted table (67 today)
Capability held constant: for every row change to an allowlisted table, a durable record exists

| Dimension                    | A independent | D on-substrate |
|-------------------------------|--------------:|---------------:|
| CHEC                          |             3 |              3 |
| ILC                           |             0 |              1 |
| ISC                           |             3 |              3 |
| RCK                           |             4 |              2 |
| InterfaceCost                 |            10 |              9 |
| Δ interface per new table     |    +2 triggers |              0 |
|                                |   [Projected] |    [Projected] |
| Growth slope                  | rising (steep, 2×) |        flat |
| Satisfies CON-004             |            yes |           yes |

Crossover: not applicable — D is both lower-base (9 vs 10) and flatter (0 vs 2). D dominates.
```

And where the crossover does the work: base 10 / slope 2 vs. base 15 / slope 0 gives
`G* = (15 − 10) / (2 − 0) = 2.5` — the flat option wins beyond **3** additions. With 67 units
already in scope and more expected, that is not a close call, and the crossover says so without
appeal to taste.

---

## Comparison scorecard (three-block, ordered, non-reorderable)

**S3 carve-out:** the three-block form is required for genuine comparisons; a trivial pick may
collapse to a one-line rationale.

```
### Block 1 — Counts
Caller & baseline: <who consumes this; what they already command>
Capability held constant: <one line>      Equivalence: Yes / Shared-only / Normalized
Growth unit: <the countable thing this requirement multiplies in, + current count if known —
  or "none — one-off decision, no trajectory">

A — ISC: [item; item; …] = n
  Hard-to-Describe check: "<full interface in one sentence>" — complete? (required ISC-honesty check)
A — ILC: [item; …] = n   A — RCK: [item; …] = n   A — CHEC: [item; …] = n
A InterfaceCost = ISC + ILC + RCK + CHEC
A — Δ<proxy> per <growth unit>: [item; …] = n   [Observed, n=3 | Projected]
A — Growth slope: flat | rising (linear) | rising (steep, <mult>×) | compounding (<driver>)

B — ISC: [item; …] = n
  Hard-to-Describe check: "<full interface in one sentence>" — complete? (required ISC-honesty check)
B — ILC: [item; …] = n   B — RCK: [item; …] = n   B — CHEC: [item; …] = n
B InterfaceCost = ISC + ILC + RCK + CHEC
B — Δ<proxy> per <growth unit>: [item; …] = n   [Observed, n=3 | Projected]
B — Growth slope: flat | rising (linear) | rising (steep, <mult>×) | compounding (<driver>)

[if any pre-existing stated constraint applies] Satisfies <CON-ID>: A=<yes/no>  B=<yes/no>
  — cite the constraint by ID or verbatim quote; evaluated before totals (see Gate rows, above).

Per-guideline judgment (cite items from Block 1):
- Pull complexity down:         <winner> — CallerCost vs AuthorCost; encapsulated or relocated?
- General + common case simple: <winner> — collapsible methods? use-case naming? overexposure?
- Errors defined out:           <winner> — CHEC delta; any error every caller handles identically?
- Complementary code together:  <winner> — CouplingCount; temporal split? CA?

### Block 2 — Depth Verdict  (cites Block 1 ONLY; later blocks MUST NOT alter this)
Deeper by InterfaceCost (the only scored axis): <A|B>  (<n> vs <n>).
Trajectory reading (derived, non-summed — never enters InterfaceCost): A slope <band> vs
  B slope <band>; G* = <value | n/a — <X> dominates | n/a — no growth unit>;
  horizon <known: <n> units | unknown → declared default = flatter option>.
[if the trajectory reading contradicts the InterfaceCost line] Depth verdict over the horizon:
  <A|B>, by crossover arithmetic (G* = <n> vs expected <n> units). Both readings stand as
  recorded; this resolution is Block-2 internal and is NOT a Block-3 override.
Confidence: High / Medium / Low — <why; state Medium/Low when either side's Δ is Projected>
Blind-spot: <what this verdict does NOT establish — seam existence / ownership / sequencing>

### Block 3 — Non-metric Factors & Recommended Action  (quarantined; MUST NOT alter Block 2)
Non-metric factors: <transition cost, schedule, risk, current N>
Recommended Action: <A|B>
[if Action ≠ Block-2 verdict] Override gate: cost=<name>; gap=|A−B|=<n>; large? <yes/no —
  measured against gap×N; unit basis stated>; Block-2 verdict unchanged.
```

---

## Override gate

If Block 3's Recommended Action ≠ Block 2's Depth Verdict, the override is valid only if the
gate passes:

```
gap = |InterfaceCost_A − InterfaceCost_B|
```

Override is permitted **only if BOTH conditions hold:**

1. `gap ≤ 1` — the depth signal is already near-tie / Low-confidence; and
2. the one-time cost is **large** — comparable to or exceeding the durable cost forgone
   (`gap × N`, where N = call-site count), with the unit basis of the one-time cost stated
   explicitly (the comparison spans incommensurable units — name the basis).

**If `gap > 1` OR the cost is not demonstrably large against `gap × N`**, the override is
**BLOCKED** and Block 2's Depth Verdict stands as the Recommended Action.

Block 2's Depth Verdict **survives any override unchanged** — it is recorded as the depth truth
even when the recommendation diverges.

**Anti-example:** See [examples/09-transition-cost-masquerade.md](examples/09-transition-cost-masquerade.md)
for the canonical failure case: a recommendation picks the shallower design on transition-cost
grounds — override gate BLOCKS it (gap 3 > 1). Also demonstrates the positive control: gap ≤ 1
with a documented large cost permits the override, verdict unchanged.

---

## Worked example 1 — equal capability

**Capability:** fetch a record from a remote service. **A (shallow):** `buildRequest(cfg)` →
`send(req)` → `parse(raw)`, plus a `retryConfig`, a `status` field to branch on, and four error
types. **B (deep):** `getRecord(id) -> Record`; auth refresh, retries, and parsing are internal; a
missing record returns empty; only one `DataUnavailable` surfaces.

```
### Block 1 — Counts
Caller & baseline: application code; baseline = the host language
Capability held constant: given an id, return the record (or "not available")
Equivalence: Yes
Growth unit: none — one-off decision, no trajectory (a single record-fetch shape, not a family
  that grows with requirements)

A — ISC: [buildRequest entry-point; send entry-point; parse entry-point; cfg param;
          retryConfig param; status field] = 6
  Hard-to-Describe check: "Build and send a configured request, parse the raw response,
  and branch on status while managing retry config." — multi-clause, fails. Confirms ISC 6. ✗
A — ILC: [request-object exposes wire shape; raw response leaks server protocol] = 2
A — RCK: [must order: buildRequest→send→parse; must check status before use] = 2
A — CHEC: [NetworkError; ParseError; RetryExhausted; InvalidStatus] = 4
A InterfaceCost = 14

B — ISC: [getRecord entry-point; id param] = 2
  Hard-to-Describe check: "Given an id, return the record or empty." — one sentence, complete. ✓
B — ILC: [] = 0
B — RCK: [missing → empty result, not an error to handle] = 1
B — CHEC: [DataUnavailable] = 1
B InterfaceCost = 4

Per-guideline judgment:
- Pull complexity down:         B — retry/auth/parse absorbed; nothing re-surfaces (encapsulated).
- General + common case simple: B — one operation vs three sequential transport stages.
- Errors defined out:           B — missing = empty; transients retried; CHEC 4→1 without masking.
- Complementary code together:  B — build/send/parse share the wire protocol, always change together.

### Block 2 — Depth Verdict  (cites Block 1 ONLY; later blocks MUST NOT alter this)
Deeper by InterfaceCost (the only scored axis): B  (4 vs 14).
Trajectory reading: n/a — no growth unit declared (one-off decision).
Confidence: High — same capability, declared caller, all CHEC/ILC/ISC/RCK items visible.
Blind-spot: this verdict scores interface size; it does not establish whether B's retry seam
exists in the current codebase, or that auth-refresh has a single owning component.

### Block 3 — Non-metric Factors & Recommended Action  (quarantined; MUST NOT alter Block 2)
Non-metric factors: none identified.
Recommended Action: B. Ensure DataUnavailable carries only the retry-later/give-up decision,
or ILC creeps back.
```

---

## Examples Index

Worked examples are loaded on demand; they are not required reading to apply the rubric. Example 1 (above) establishes the scorecard format; the extracted examples demonstrate edge cases and cross-domain applications.

| # | Title | Location | Summary |
|---|-------|----------|----------|
| 1 | Equal capability | (inline above) | Core three-block scorecard walkthrough: shallow multi-step vs deep single-call. |
| 2 | Capabilities differ (the gate fires) | [examples/02-config-parser-gate-fires.md](examples/02-config-parser-gate-fires.md) | Demonstrates unbundling when B has unjustified extras. |
| 3 | More capability, smaller interface (the substrate reframe) | [examples/03-substrate-reframe.md](examples/03-substrate-reframe.md) | The real win quadrant: substrate beats menu by orders of magnitude. |
| 4 | Docs folder naming (cross-domain) | [examples/04-docs-folder-naming.md](examples/04-docs-folder-naming.md) | Non-code example; explicit transition-cost callout. |
| 5 | CLI command grouping (menu vs substrate) | [examples/05-cli-command-grouping.md](examples/05-cli-command-grouping.md) | Smallest non-code substrate-reframe case. |
| 6 | Shared-vocabulary interfaces (catalog) | [examples/06-shared-vocabulary-interfaces.md](examples/06-shared-vocabulary-interfaces.md) | Orthogonal known interfaces (git, HTTP, pipes, cron, Make, CSS/XPath, semver) that drive RCK toward zero. |
| 7 | Temporal decomposition (a split that leaks) | [examples/07-temporal-decomposition.md](examples/07-temporal-decomposition.md) | Module-boundary smell: splitting by phase strands one decision across two modules (ILC, CA > 1). |
| 8 | Overexposure (the common case pays for the rare one) | [examples/08-overexposure.md](examples/08-overexposure.md) | Common-case tax (CCT): the caller learns rare machinery to reach a common feature; target zero-config. |
| 9 | Transition cost masquerading as depth (negative example) | [examples/09-transition-cost-masquerade.md](examples/09-transition-cost-masquerade.md) | Anti-example: override gate BLOCKS a shallow pick driven by migration cost (gap 3 > 1); positive control shows gate permits gap ≤ 1 with documented large cost, verdict unchanged. |
| 10 | Convention/definition ownership (one owner vs federated) | [examples/10-convention-ownership.md](examples/10-convention-ownership.md) | Non-code depth example: federating a counting-convention catalog into non-owning rubrics scatters the routing index (RCK) and splits the contract (ILC); keep one owner and point in. |
| 11 | Pull complexity down (derivability + silent routing) | [examples/11-pull-complexity-down.md](examples/11-pull-complexity-down.md) | A derivability proof collapses 11 of 14 raw topics into pseudo-primitives; the adapter silently routes to the efficient wire form once a composition is recognized, adding zero interface surface. |

---

## Anti-pattern → guideline → fix (quick reference)

| Anti-pattern observed | Guideline | Fix |
|---|---|---|
| Interface ≈ functionality (shallow module) | depth | Merge with neighbors or move functionality inward. |
| Pass-through method/variable | leakage / pull-down | Remove the middle layer, or give it real value. |
| Config every caller sets identically | pull-down | Default it inside the module. |
| Error every caller handles the same way | define errors out | Handle once internally, or redefine as no-op/clamp/idempotent. |
| Method named for a use case or caller | general-purpose | Rename to the operation; collapse near-duplicate siblings. |
| Common task must engage rare-case machinery (**overexposure**) | general / common case | Make the common case zero-config; demote the rare capability to an opt-in (CCT→0). |
| Modules split by phase (read/modify/write) sharing one decision (**temporal decomposition**) | complementary together / leakage | Re-cut the boundary around the *knowledge*; one module owns the format/protocol, used in every phase. |
| Two methods you can't understand apart (**conjoined methods**) | complementary together | Merge, or redesign so the dependency is explicit and one-directional. |
| Same nontrivial logic copy-pasted (**repetition**, CA > 1) | complementary together | Factor into one place; the duplicate is one decision in many sites. |
| One logical change edits many sites (**change amplification**) | complementary together | Find the leaked/duplicated decision and house it once. |
| Two files always edited in the same commit | complementary together | Merge them; the split leaks a shared decision. |
| Internal/wire format in a public signature | leakage | Return a domain type, not the storage/wire shape. |
| Caller must orchestrate ordered steps | leakage / pull-down | Expose one operation that orchestrates internally. |
| Optional capability bolted onto a core entry point | general-purpose / gate | Unbundle; expose the extra as a composable piece. |
| Menu that grows ~1 endpoint per requirement | general-purpose / reframe | Replace with a substrate the caller composes (query language, store, filesystem) — if the guardrails hold. |
| Scorecard reports only today's `InterfaceCost`, no growth unit declared | trajectory | Declare the growth unit (or state none); add Δ and slope rows before comparing — see Trajectory rows. |
| Interface needs a long comment to be complete (**hard to describe**) | tie-breaker / depth | Treat the long comment as ISC the slots hid; re-cut so a short complete comment suffices. |
| Central entity resists a precise name (**vague / hard-to-pick name**) | tie-breaker / depth | The boundary is likely wrong or doing two jobs; split until each part names cleanly. |
| Tiny interface, tangled unreadable interior (**obscurity**) | tie-breaker | Depth of interface != clarity of implementation; reduce unknown-unknowns inside before blessing it. |
| "Must know SQL/regex/etc." counted as cost for an agent caller | RCK baseline | Declare the baseline; baseline competence is free — count only module-specific facts. |
| "Simple inside, but caller must know a lot" | module-level load | Push knowledge into the implementation to lower module-level load. |
| Allowlist/protocol-by-convention/dispatch table with no open-or-closed verdict at its definition site (**unannotated extension point**) | extension-point declaration | Add a definition-site verdict: open (extension procedure + fan-out) or closed (naming the ADR/decision); record it in the `architecture-patterns` Extension-Point Register. |

---

## When to prefer the shallower design (escape hatch)

Depth is the default, not a law — and the exit is deliberately harder to trip than the main path,
because code drifts shallow on its own. Prefer the shallower design only when **several** of these
hold together; **no single one is a license**:
- exactly one caller, AND no expected reuse, AND the interface is not load-bearing for understanding;
- hiding the complexity would obscure control the caller legitimately needs (information genuinely
  needed outside the module must not be hidden — e.g. performance-tuning parameters with no good
  default);
- the abstraction's name is less clear than the code it would replace;
- making it deep would require global state, hidden mutation, or surprising side effects;
- going deeper would force an over-merge that conjoins genuinely independent code (guideline 4 in
  reverse).

If only one applies, the deeper design usually still wins — re-run the gate and counts before exiting.

## Failure modes of this skill itself

- **Mistaking relocation for encapsulation.** Re-check that pulling complexity down did not raise
  `InterfaceCost`. If it did, no depth was gained.
- **Over-generalizing or over-merging.** "General-purpose", "substrate", and "together" are bounded
  by *current* callers and *actual* shared decisions. When counts are tied, say so (Confidence: Low)
  and let the tie-breakers, then the simpler implementation, decide.
- **Slot-counting gaming (false low ISC).** Collapsing many parameters into one `options` object,
  or many returns into one tuple, lowers the slot count without lowering the real surface. Count
  *concepts in the honest interface comment*, not signature tokens; if ISC and the Hard-to-Describe
  comment disagree, trust the comment.
- **Depth rewarding obscurity.** The four proxies measure the *interface*, never the
  *implementation's* readability. A god-module with a one-method interface and an unmaintainable
  interior scores deep but is a maintenance trap. When that smell is present, run the obscurity
  tie-breaker and report the implementation risk explicitly — a deep interface does not excuse an
  unknowable inside.
- **Baseline gaming (false low RCK).** Declaring an over-broad baseline ("an agent knows
  everything") zeroes out RCK that is real. Only broadly-known standards are baseline; name niche
  or proprietary knowledge and count it.
- **Local optimization inside a bad frame.** Scoring only the A and B you were handed can crown the
  better of two poor designs. Run Design it Twice and the reframe checks *before* scoring, so the
  frame itself is on the table.
- **False precision over qualitative red flags.** The counts are proxies, not truth. When a design
  is hard to describe, hard to name, or full of unknown unknowns, those signals are often more
  reliable than a marginally lower proxy count. Report both — count and red flag — and let the
  user see the tension.
- **Metric contamination.** One-time / non-interface costs (transition, schedule, risk) appearing
  in Block 1 or altering Block 2 is a constraint violation, not a judgment call. The override gate
  (Block 3) is the only legitimate place for them, and only within the gap ≤ 1 window.
- **Growth-unit gaming.** Choosing a growth unit that flatters a preferred option. Test: would the
  stakeholder recognize the unit as the thing they actually count? If you had to invent it, it's wrong.
- **Projecting when history exists.** If the repo/changelog shows the last three additions of the
  growth unit, count them — `[Observed]` is required, not optional, whenever that history is
  available. A `[Projected]` figure that contradicts observed history is a finding about the
  design, not a free scoring choice.
- **Blending Observed and Projected**, or omitting the label, on the Δ row. This silently upgrades
  a guess to the evidentiary weight of a measurement.
- **A growth-slope band with no Δ behind it.** The band is derived, not asserted; a band without
  its number is unfalsifiable and must be treated as missing.
- **Treating flat as an automatic win.** Flat with a much higher base loses over a short horizon —
  compute `G*`, don't assume the flatter design wins.
- **Inventing a gate-row constraint during scoring.** A criterion with no pre-existing citation is
  how a reviewer eliminates the option they dislike. Cite the constraint or drop the row.
- **Reporting marginal cost for a dimension the scorecard doesn't otherwise score.** That's a new
  dimension wearing a trajectory label — fold it into the base score (if it belongs there) or drop it.

---

## References

Extended material, loaded on demand:

- [references/derived-counts.md](references/derived-counts.md) — Full CCT and CA mechanics,
  counting procedure, and Example-08 linkage.
- [references/qualitative-tiebreakers.md](references/qualitative-tiebreakers.md) — Naming
  precision and Obscurity / unknown unknowns (full definitions and worked checks).
- [references/seam-validation-procedure.md](references/seam-validation-procedure.md) —
  Step-by-step procedure for seam-validation when a verdict spans ≥2 existing seams.
- [`../code-metrics/SKILL.md`](../code-metrics/SKILL.md) — Automated code-health metrics
  affiliated with the deep-modules philosophy (e.g. `ic_max`, `instability`, `sdp_violations`,
  `interface_density`, `annotation_coverage`) are cataloged there, with their counting conventions
  and gate-status. These are automated measurements, distinct from this skill's ISC/ILC/RCK/CHEC
  scoring proxies.
- [references/orchestration.md](references/orchestration.md) — Multi-agent orchestration workflow
  for depth decisions that span multiple roles (Planner/Architect/Implementer/Critic/Analyst);
  triggers, 6-step workflow, HARD BLOCK conditions, and DM Recommendation Memo template.