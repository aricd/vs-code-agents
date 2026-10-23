---
name: vertical-slice
description: >-
  Force end-to-end vertical slices instead of horizontal layers built in isolation. ALWAYS
  applies when about to build, implement, or scaffold a feature that crosses more than one layer
  (UI→API→service→transport→store, action→endpoint→IPC→OS, command→DDS→subscriber); when an agent
  is producing a complete solution in one leap — all endpoints, full models, middleware, auth —
  before the critical path has been connected once; and when sequencing the phases of a build or
  reviewing a plan whose first phase defers the riskiest boundary. Routes the "which design?"
  question to the prototype skill and keeps the "does the wired path actually connect under real
  conditions?" question here. Triggers on "vertical slice", "walking skeleton", "tracer bullet",
  "build this feature end to end" — and even when none of those are said, whenever an agent is
  about to outrun its headlights.
metadata:
  version: "1.0"
---

# Vertical Slice — Tracer Bullets

A tracer bullet is a **thin, end-to-end slice that pierces every layer of the system for real**,
fired to get feedback under live conditions before the rest of the feature is built. It is lean
but complete, and — unlike a prototype — it is *kept*: it becomes the skeleton the feature is
fleshed out onto.

## Why this skill exists

An agent aiming to please produces the finished feature in one leap. It builds all the API
endpoints, the full request/response models, error middleware, auth, rate limiting, logging — and
only *then* tries to connect to the database, where it discovers the connection-string format is
wrong, or the column type is wrong, or the tests never hit the store. Every layer was built in the
dark, validated against nothing. The result is a large diff that needs reworking and a review
burden dumped on the human.

*The Pragmatic Programmer* names this **outrunning your headlights**: building further than your
feedback can see. Its two countermeasures are the two halves of this skill — **take small steps,
always**, and **use tracer bullets to find the target**. For an agent the discipline is
non-negotiable, not optional as it is for a careful human: the context window makes building in
the dark *cheaper to start* and *more expensive to unwind*.

The fix is to stop building horizontally. Build one thin vertical slice end-to-end, run it
in-environment, read the feedback, then expand from the validated skeleton — each subsequent slice
in a fresh context.

## Tracer bullet vs prototype — pick the right tool

The book draws this line and it decides which skill you're in. They are siblings with **opposite
disposability**.

| | **Prototype** ([`prototype`](../prototype/SKILL.md)) | **Tracer bullet** (here) |
|---|---|---|
| Disposability | Throwaway — deleted or absorbed | **Kept** — becomes the skeleton |
| Shape | Explores one aspect, ignores the rest | Thin but **end-to-end**, every layer |
| Conditions | Whatever's convenient to answer the question | The **real** environment and boundaries |
| Answers | "Is this design / logic / data model right?" | "Does the critical path actually connect?" |
| When | *Before* committing to an approach | The *first increment of* the committed approach |

Common sequence: **prototype** the risky sub-question and throw it away, then **fire a tracer**
through the approach you chose and keep it. If the open question is *which* design, you're in
`prototype`. If the design is settled and the open question is *whether the wired path holds under
real conditions*, you're here.

## Firing a tracer bullet — the procedure

1. **Name the vertical.** List every layer the feature crosses, end to end. Not the layers you
   feel like writing — the ones the request actually touches.
2. **Find the riskiest seam.** The boundary you understand *least*, or whose failure is most
   *expensive to discover late*: a wire/schema/IPC crossing, a connection-string or QoS or
   type-hash negotiation, a trust boundary, a cross-process or WSL→OS hop. **Order by uncertainty,
   not by layer convenience.** The easy CRUD you've written a hundred times is never the first
   slice.
3. **Cut the thinnest path that still crosses everything.** One endpoint, one record, one
   DataItem, one happy path. *No* second endpoint, *no* full model set, *no* middleware. If the
   slice contains a complete surface, it isn't thin.
4. **Pierce the seam for real.** Wire the slice through the actual transport, the actual schema,
   the actual IPC — **no stub at the boundary under test.** Stubbing elsewhere is fine; stubbing
   the thing you're validating is firing blanks at a paper target three feet away and calling it
   zeroed.
5. **Run it in-environment and read what lands.** The connection either negotiates or it tells you
   the format is wrong — now, cheaply, with a one-record blast radius. This is `[Demonstrated]`
   evidence, never `[Asserted]`.
6. **Capture the feedback, then fresh context, next slice.** Expand outward from the validated
   skeleton. Each new slice thickens the wired path; none of them re-opens a seam the tracer
   already closed.

## The cardinal rule: real target, real conditions

The metaphor is load-bearing. Tracer rounds work because they fly under the **same conditions as
live ammunition** — same gun, same trajectory, same wind — so where they land tells you where the
real round lands. A tracer that fakes the boundary it exists to validate has taught you nothing
and shipped the risky assumption with a green check beside it.

Apply the two-zone split ([`lean-design`](../lean-design/SKILL.md)) to *what may be crude* in a
slice — never to the seam:

- **Tooling zone** (MCP servers, plan docs, harness, skills): the non-risky layers of the slice
  can be the crudest thing that runs.
- **Runtime / contract zone** (regulated runtime, wire/schema/IPC, audit & traceability): the seam
  the tracer pierces is exactly the thing that must be real — real DDS transport with real QoS
  (durability / reliability / liveliness) and real type-hash, real trust-boundary validation, real
  teardown ordering. Thin the *functionality*; never fake the *boundary*.
- **Unsure which zone the seam is in → treat it as runtime and pierce it for real.**

## Fits with the rest of the suite

- **[`structured-labeling`](../structured-labeling/SKILL.md)** — The tracer slice is the **first
  GOAL / phase** of the Implementation Plan (§7), and it must pierce the riskiest `BOUNDARY-NNN`
  for real. Its TASK acceptance criteria are **`[Demonstrated]`** (in-environment runtime
  evidence) — a tracer whose criteria are `[Asserted]` has defeated its own purpose. Order phases
  so the unknown seam is pierced in phase 1, never deferred to phase 3. The slice walks the
  traceability chain (REQ→TASK→TEST→RISK→FM) once, narrowly, before it is widened.
- **[`requirements-enforcement`](../requirements-enforcement/SKILL.md)** — Aim the first tracer at
  the guarantee whose violation is most *expensive to find late*. The slice is where you wire that
  guarantee's first **oracle**, and the in-environment run is the evidence it fires. A tracer that
  pierces no declared boundary and exercises no guarantee is sightseeing.
- **[`deep-modules`](../deep-modules/SKILL.md)** — "Is this one slice or two?" defers here. A
  slice should be **deep**: real functionality through a thin path, not a shallow pass-through
  that name-drops every layer without exercising any.
- **[`prototype`](../prototype/SKILL.md)** — Sibling, opposite disposability (table above).
  Throwaway answers "which design?"; the tracer keeps the wired skeleton.
- **[`lean-design`](../lean-design/SKILL.md)** — A tracer bullet is the lean ladder applied to
  **sequencing**: the minimum that yields feedback, fired at the first rung that actually reduces
  uncertainty. `lean-design` trims volume *within* a slice; this skill *orders* the slices. Both
  refuse to build in the dark.

## Drop-in prompt block

Paste into a build-feature prompt or agent loop to force the discipline at the prompt level:

```
## Tracer bullets

Before building a feature, find the thinnest slice that crosses every layer it
touches and pierces — for real, no stubs — the boundary you understand least or
whose failure is most expensive to find late. Build that one slice end-to-end,
run it in-environment, and read the feedback before expanding. One endpoint, one
record, one happy path — not the full surface. The seam under test must be real
even when the rest of the slice is crude. Then: fresh context, next slice, expand
from the validated skeleton. Never build horizontal layers in isolation and wire
them together at the end — that is outrunning your headlights.
```

## When done

The skeleton **stays**. You do not delete a tracer and rebuild "properly" — that pays the wiring
cost twice and is what the [`prototype`](../prototype/SKILL.md) skill is for. Each subsequent
slice thickens the path the tracer proved.

Capture what the feedback *taught* you — the connection-string format, the QoS that actually
negotiated, the type-hash that matched, the boundary that didn't — wherever the project keeps
decisions. For a structured-labeling plan that is the §12 Risks / FM-Exposure entry and the
relevant OPENQ, not a stray `NOTES.md`.

## Failure modes of this skill itself

- **Stub at the seam.** The tracer fakes the very boundary it exists to validate — the most common
  and most corrosive failure. Countermeasure: the cardinal rule; the pierced seam is real or it
  isn't a tracer.
- **Horizontal in disguise.** An "end-to-end slice" that is actually the full API surface with one
  DB call bolted on at the end. A second endpoint or a complete model set means it isn't thin.
- **Wrong target first.** Firing the comfortable slice and deferring the unknown seam to a later
  phase. The whole point is to hit the *uncertain* target early — order by risk, not by comfort.
- **Treated as throwaway.** Deleting the slice once it proves the path. That's a prototype, and the
  lean skeleton was the keeper.
- **Never watched land.** Building the slice but not running it in-environment — `[Asserted]` where
  `[Demonstrated]` was the entire reason to fire it. A tracer you don't watch land taught you
  nothing.
