---
name: requirements-enforcement
description: >-
  Maintain a project's guarantee ledger (semi-formal requirements with a maturity ladder) and
  enforce it through a failure-mode registry. ALWAYS applies when a defect, bug, escape,
  regression, or unexpected behavior is triaged or documented; when designing tests or asking
  what could go wrong; when reviewing a plan or diff for risk exposure; and during postmortems
  or FMEA-style analysis. Four phase hooks -- planning (exposure declaration),
  implementation/TDD (oracle coverage), code review (diff vs. declaration), QA (escape
  attribution) -- each with one obligation and bounded context loading. Also governs ledger
  work: minting candidate guarantees, ratification, promotion, supersession, oracle
  revalidation. Classes are negations of declared guarantees; modes split by a falsifiable
  single-oracle rule; instances pin regressions. Triggers even when "failure mode" or
  "requirement" is never said -- e.g. "where should this bug be documented", "what tests should
  cover this", "did we miss a case like this before".
---

# Requirements Enforcement

## Why this skill exists

Requirements in a live project are not well defined up front: they are discovered incrementally,
change shape, and are sometimes replaced by something qualitatively different. Meanwhile,
failure-mode documentation fails in two directions -- recorded too granular, each entry is
testable but blind to variations of the same unnamed mechanism; recorded too coarse, entries are
unfalsifiable risk prose. And both problems compound for agents: an unbounded register every
agent must "consider" is context flooding wearing a safety vest.

This skill couples two thin registries so each fixes the other:

- **The guarantee ledger** -- the project's requirements, declared one falsifiable clause at a
  time, with a maturity ladder from agent-proposed candidate to formal requirement. Declaration
  is cheap, so it happens; maturity is explicit, so provisional guarantees never become
  load-bearing silently.
- **The failure-mode registry** -- the ledger's enforcement dual. Every failure is attributed to
  a guarantee (or becomes evidence for a missing one), routed to the right kind of test, and
  counted toward a self-evaluating metric.

The coupling runs both ways: guarantees give failures a derivable taxonomy, and failures are the
discovery engine that grows the ledger empirically. The registries are **pull, not push**:
agents load detail only for what a plan declares relevant.

## What "objective" means here

Membership and maturity are decided by **stated, falsifiable rules and countable events**, not
judgment. A disagreement localizes to an inspectable question -- "which guarantee does this
violate?", "does one oracle catch both?", "did the promotion event occur?" -- settled with
evidence. When a failure fits nothing, the misfit is itself a finding (a candidate guarantee),
never a license to improvise a bucket.

---

## The kernel: rules every activity shares

### The three-level model

| Level | Definition | Partition rule | Test artifact |
|---|---|---|---|
| **Class** | The negation of one ledger guarantee | Same class **iff** same guarantee violated | None -- organizing principle only |
| **Mode** | One mechanism of violating it | Same mode **iff** a single detection oracle catches both instances | The **oracle** -- catches every instance, including unseen ones |
| **Instance** | One specific manifestation | Concrete repro under one primary mode | Example-based **regression test** |

Three levels, never more. A failure that wants a fourth level is a new mode or instance detail.

**Rule 1 -- classes derive from the ledger.** Every guarantee generates at most one class, minted
lazily (when its first mode is minted, never pre-generated). Class files reference the guarantee
**by ID only** -- statement text lives in the ledger and nowhere else. A failure violating no
ledger guarantee is evidence of a missing one: mint a *candidate* guarantee, then proceed. Never
mint a class from surface similarity ("the timeout-ish ones") -- that is the granularity trap
re-entering.

**Rule 2 -- the single-oracle rule.** Two instances share a mode iff one oracle catches both; if
two different checks are needed, they are two modes. Falsifiable by running the proposed oracle
against both. Corollary: **an oracle that only re-detects its known instances is a regression
test in costume** -- a genuine oracle checks the property (the guarantee, scoped to the
mechanism), so unseen variations fail it too.

**Oracle typology.** Two types, equal standing:

- **Structural** -- a property/invariant test; runs in CI.
- **Measured** -- a fixed evaluation procedure + ground-truth corpus + threshold (for
  guarantees that are precision/recall-shaped or budget-shaped: discovery quality, latency
  budgets, judge-layer behavior); runs on a cadence or pre-release; may carry status
  `pending-corpus` until its corpus exists.

**Who executes a measured procedure is part of its type.** A measured oracle records its
executor, because the two erode differently and a reader scanning INDEX must not mistake one
for the other:

- **`measured`** (automated, the default) -- a script or eval harness runs the procedure.
- **`measured (adjudicated)`** -- an agent runs the procedure under a versioned protocol. Legal
  only when the guarantee is about **completeness of consideration**: a property whose violation
  leaves no site in the artifact to point at, so it cannot be found by inspection and must be
  re-derived independently. The protocol MUST require the reviewing agent to **enumerate its
  candidate set from named sources before reading the artifact's own claims**, and to record
  every candidate it raised, including those it then rules inapplicable. Those are the oracle's
  false positives; without them precision is not computable and the procedure cannot be
  calibrated. An adjudicated oracle that reports only confirmed findings is a regression test in
  costume by the corollary above.

The threshold on an adjudicated oracle validates the **procedure**, not the artifact under
review: it states the rate at which the protocol recovers known-missed items from the corpus. No
individual review claims the artifact is complete; the measured detection rate is itself the
disclosure.

The taxonomy's boundary is "declared guarantee" -- full stop. A performance ceiling is outside it
only until someone declares the budget; then it is an ordinary class with a measured oracle. No
category is special-cased in or out.

**Test routing follows the hierarchy.** Classes: no tests. Modes: oracles. Instances:
regressions. The historical mistake this skill exists to prevent is instance tests without mode
oracles -- coverage of the seen at the expense of the unseen.

### The maturity ladder

Every guarantee carries exactly one maturity. "Declared" in Rule 1 means *any* rung -- formality
is a ladder, not a prerequisite:

| Maturity | Meaning | What it can anchor |
|---|---|---|
| **candidate** | Proposed (agent or human), awaiting ratification | A **provisional class**: holds instances as accruing evidence, but generates **zero obligations** -- no INDEX budget, no planning declarations, no oracle mandate |
| **plan-local** | Ratified within one plan; guards an assumption that plan depends on | Plan-local classes, documented and oracle-guarded inside the plan itself |
| **adopted** | Project-level, semi-formal | Registry classes; oracle wired into project CI |
| **formal** | Mapped to an external requirement system ID | Same as adopted, plus the external traceability reference |

Ratification (candidate -> plan-local or adopted) is a **human gate** -- agent-proposed guarantees
never become load-bearing silently. Promotion above plan-local is triggered by countable events,
and supersession preserves instance evidence across requirement churn -- both specified in
`references/ledger.md`.

### Phase hooks -- one obligation, bounded loading

No phase loads the full registry; no phase has a checklist.

| Phase | Loads | Single obligation | Detail in |
|---|---|---|---|
| **Planning** | INDEX.md only | Produce the **exposure declaration** (touched class/mode IDs, or `none` + rationale), pinned to an INDEX version | enforcement.md |
| **Implementation / TDD** | Class files for declared classes only | Each declared mode's oracle exists, or write it | enforcement.md |
| **Code review / Critic** | Diff + declaration | Two questions: undeclared exposure? unnamed mechanism? | enforcement.md |
| **QA / escape analysis** | Triage procedure + candidate class file | **File every escape** through triage -- the only mandatory write path | enforcement.md |
| **Ledger work** | LEDGER.md | Ratify / promote / supersede / revalidate per the stated events | ledger.md |

---

## Activity references -- read exactly one

- **`references/enforcement.md`** -- read when triaging a failure, filing registry entries,
  writing or reviewing an exposure declaration, or creating the registry. Contains the triage
  procedure, two-class filing rule, phase obligations in full, registry layout, budgets, ID
  scheme, and all templates.
- **`references/ledger.md`** -- read when minting, ratifying, promoting, or superseding
  guarantees, revalidating oracles after a guarantee changes, or creating the ledger. Contains
  the LEDGER.md template, promotion events, supersession procedure, and ledger discipline.

Triage that ends in minting a candidate guarantee needs only the one-line mint format, which is
included in enforcement.md so the QA path stays a single read.

---

## Recommended ledger and registry home

This skill distributes templates and rules; **the ledger and registry themselves live in the
consuming project**, not here. Recommended paths:

| Artifact | Recommended path | Rationale |
|---|---|---|
| Guarantee ledger | `guarantees/LEDGER.md` | Single file, version-controlled alongside the code it governs |
| Failure-mode registry index | `failure-modes/INDEX.md` | Same directory; budget constraints and phase-hook loading reference this file |
| Class files | `failure-modes/<class-id>.md` | One file per class, named by ID (e.g., `failure-modes/FM-R-TRUNC.md`) |

### Bootstrapping (first use)

The registry is two files, and both are legal with zero entries (frontmatter and header rows
only):

1. `guarantees/LEDGER.md` -- copy the LEDGER.md template from `references/ledger.md`.
2. `failure-modes/INDEX.md` -- copy the INDEX.md template from `references/enforcement.md`.

Set `mode_budget` deliberately at bootstrap (default 60). Class files are never created at
bootstrap -- Rule 1 mints them lazily. Once both files exist, planning pins
`Declared against: failure-modes/INDEX.md @ <commit-or-date>` (a date is a legal pin until the
first commit exists) and the registries grow through the normal paths only: guarantees via
candidate minting, modes via QA triage.

**Until both files exist, a plan is in exactly one of three states, and must say which:**

| State | FM Exposure form | Meaning |
|---|---|---|
| **Deliberate opt-out** | `none -- deliberate (per AGENTS.md)` | Guarantee tracking is out of scope for this project. The decision lives as a visible standing marker in the repo's `AGENTS.md`: `RE-Registry: opted-out -- <date> -- <one-line reason>`. While the marker exists, no plan asks again and no further RE obligations apply. |
| **Not bootstrapped, no exposure** | `none -- not bootstrapped[; <rationale>]` | The plan touches no failure modes and relies on no guarantees; the registry just does not exist yet. Legal ONLY when the plan documents zero candidate modes. |
| **Not bootstrapped, exposure exists** | `Declared against: plan-local (no registry; bootstrap deferred by user -- <date>)` + the candidate-mode table | The plan HAS exposure (documented plan-local candidate modes) but the user deferred bootstrap. **Never a `none` header** -- a `none` line above documented candidate modes is a contradiction: the plan self-evidently has exposure. |

**The ask is the user's, at approval time.** When the registry is absent and no `AGENTS.md`
opt-out marker exists, the Planner MUST present -- immediately before plan approval, on every
plan -- the question: *"The guarantees ledger and failure-modes index have not been created
within this repo. Would you like to have them created now, or explicitly defer?"* The answer
is documented in the plan either way (frontmatter `RE_Bootstrap_Decision` + a
`Bootstrap decision:` line in FM Exposure). Deferral is 100% legal on every plan -- but it is
in front of the user every time; **the agent never self-selects it**. The standing escape from
the every-plan ask is the explicit `AGENTS.md` opt-out marker, never silence.

Registry-dependent obligations (INDEX pins, exposure gates, G-ID annotations, deepened FM
Exposure formats) apply only when the registry exists; under the no-registry forms they are
**waived explicitly, never failed silently**. On "create now", also mint the negation of each
documented plan-local candidate mode as a candidate guarantee (one-line mint format,
provisional class files -- not in INDEX).

---

## The self-evaluation metric: escape attribution rate

Every escape is attributed to exactly one bucket; the distribution over time names which layer
is failing:

| Bucket | Meaning | The fix lives in |
|---|---|---|
| **Coverage gap** | An existing oracle would have caught it; the test was missing or unwired | CI wiring, implementation discipline |
| **Taxonomy gap** | No oracle could have; a new mode was minted | The registry, and the declarations that consult it |
| **Contract gap** | No ledger guarantee covered it; a candidate was minted | The ledger -- requirements discovery is working as designed |

A healthy project shows taxonomy-gap share declining as mechanisms get named, and contract-gap
escapes converting into ratified guarantees. A contract-gap spike means guarantees are living in
prose instead of the ledger -- the problem is upstream of enforcement.

---

## When to split this skill (fork criterion, recorded deliberately)

Keep one skill while the two halves share rules (Rule 1 references the ledger; triage mints
candidates; promotion events are defined by enforcement artifacts). Split into two **only when**
the ledger side grows heavyweight independent tooling (formal-system sync, regulated
traceability exports) **and** the coupling has reduced to data only -- enforcement consuming
guarantee IDs from a file, no shared rules. Data coupling through a stable in-repo registry is a
clean seam; shared-rule coupling is not.

## Failure modes of this skill itself

- **Declaration theater.** Rubber-stamped `none` declarations make every downstream check
  vacuous. Countermeasure: review question (a) -- undeclared exposure found in a diff is a
  process defect, not just a code one.
- **Oracle erosion.** A failing oracle narrowed until it passes relocates the registry's value
  into its costume. Any narrowing is a registry change and must state which instances remain
  covered. For an adjudicated oracle the same erosion wears three other faces: the protocol
  silently shortened; enumeration performed after reading the artifact's own claims (anchoring,
  which makes a finding nearly impossible); and raised-then-inapplicable candidates dropped from
  the record, which destroys precision while leaving the oracle looking more accurate. All three
  are registry changes -- the protocol is a versioned artifact, and narrowing it states what was
  dropped.
- **Candidate sprawl.** Cheap minting is the point, but candidates that never ratify or retire
  are speculation accruing interest. The ledger review cadence (ledger.md) prunes them.
- **Becoming the flood.** If any phase loads more than its row specifies, the ergonomic contract
  is broken and agents will correctly start ignoring the registries. The budgets are the skill;
  enforce them before adding anything.
