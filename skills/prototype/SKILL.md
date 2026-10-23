---
name: prototype
description: Build a throwaway prototype to flesh out a design -- or a divergence -- before committing to it. Routes between three branches: a runnable terminal app for state/business-logic questions (LOGIC), several radically different UI variations toggleable from one route (UI), or a differential harness that drives two real implementations side by side to establish parity and localize where they disagree (PARITY). Use when the user wants to prototype, sanity-check a data model or state machine, mock up a UI, explore design options, or reconcile two implementations / a port / a legacy-vs-new authority that must produce identical output. Triggers on "prototype this", "let me play with it", "try a few designs", "why do these two disagree", "make them match", "establish parity". Routes "does the wired path actually connect under real conditions?" to the vertical-slice skill.
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

Sibling with **opposite disposability**: if the design is settled and the open question is whether
the wired path holds under *real* conditions, that is a tracer bullet, not a prototype — load
[`vertical-slice`](../vertical-slice/SKILL.md), whose slice is *kept* as the skeleton.

## Pick a branch

Identify which question is being answered -- from the user's prompt, the surrounding code, or by asking if the user is around:

| The question | Branch | Artifact |
|---|---|---|
| "Does this logic / state model feel right?" | **[LOGIC.md](LOGIC.md)** | A tiny interactive terminal app that pushes one state machine through cases that are hard to reason about on paper. |
| "What should this look like?" | **[UI.md](UI.md)** | Several radically different UI variations on a single route, switchable from a floating bottom bar. |
| "Do these two implementations agree -- and if not, where do they diverge?" | **[PARITY.md](PARITY.md)** | A differential harness that drives **both real implementations** over shared inputs and bisects to the stage that flips the output. |

The branches produce very different artifacts -- getting this wrong wastes the whole prototype.

Disambiguation that actually trips people up:

- **LOGIC vs PARITY.** LOGIC explores *one* model to find out whether it's right. PARITY compares *two* implementations against each other, one of which is the authority (ground truth). If there's a "correct" side you're trying to match, it's PARITY -- even though the harness looks similar to a LOGIC one.
- **Ambiguous and the user is unreachable:** default to whichever branch matches the surrounding code -- a backend module -> LOGIC; a page or component -> UI; a port, a reimplementation, or two code paths that must emit the same value -> PARITY. State the assumption at the top of the prototype.

## Before you write any branch -- read this

These five reflexes are cheap to state and expensive to skip. They are the difference between a prototype that finds the bug and one that launders a wrong assumption into a confident-sounding verdict. They apply to **every** branch.

1. **Trace before you blame.** Before you conclude "the code is correct, so the *data* must be wrong," trace the whole pipeline symbolically. Most "runtime data divergence, can't pin it statically" verdicts are an un-done algebra step in disguise -- the chain *was* determinable, you just didn't telescope it. For composition chains (`A·B·C·…`) write the adjacent-stage check: neighbouring stages must compose consistently (a frame meets its own inverse and cancels; units line up). A stage that fails that check on sight is your bug, no runtime needed.

2. **Never trust a name for its meaning.** A variable's name is not its type, its units, or its coordinate space. `regScanMM_T_frame` does not tell you *which* mm-space; `amount` does not tell you the currency or whether it's minor units; `ts` does not tell you the epoch or the zone. Establish each value's actual semantics **at its source**, and treat any name that doesn't encode the thing that varies as a latent bug, not a fact.

3. **Prototype the mechanism, not the symptom.** A prototype that re-confirms what you already observe is pure waste. "I wrote a script proving the two outputs are a reflection of each other" -- you already *suspected* that; it taught you nothing. Drive the *real* code and isolate *why*: which stage, which operand, which branch.

4. **Don't assume existing code is correct.** "Both sides call the same helper" proves nothing about the composition *around* the helper. The moment a symptom doesn't fit your model, re-examine the model -- don't reach for "must be the inputs."

5. **Don't walk past the clue.** If a search, a comment, or a prior note already flagged the exact ambiguity (an untagged space, a TODO about units, a month-old "which mm is this?"), that *is* the finding -- connect it instead of re-deriving around it.

## Rules that apply to every branch

1. **Throwaway from day one, and clearly marked as such.** Locate the prototype close to where it will actually be used so context is obvious -- but name it so a casual reader can see it's a prototype, not production. For throwaway UI routes, obey whatever routing convention the project already uses; don't invent a new top-level structure.
2. **One command to run.** Whatever the project's existing task runner supports -- `pnpm <name>`, `python <path>`, `bun <path>`, etc. The user must be able to start it without thinking.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE -- wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. One exception, and it is not optional: **a PARITY prototype's golden numeric assertion is a keeper** -- see [PARITY.md](PARITY.md).
5. **Surface the state.** After every action (LOGIC), on every variant switch (UI), or on every divergence (PARITY), print or render the full relevant state so the user can see what changed.
6. **Delete or absorb when done.** When the prototype has answered its question, either delete it or fold the validated decision into the real code -- don't leave it rotting in the repo. The one piece that often *graduates* rather than dies is a PARITY golden test.

## When done

The _answer_ is the only thing worth keeping from a prototype. Capture it somewhere durable (commit message, ADR, issue, or a `NOTES.md` next to the prototype) along with the question it was answering. If the user is around, that capture is a quick conversation; if not, leave the placeholder so they (or you, on the next pass) can fill in the verdict before deleting the prototype.

One asymmetry across branches: LOGIC and UI prototypes are pure scaffolding and should vanish. A PARITY prototype usually leaves behind **a golden test that graduates into the real suite** -- because the absence of exactly that test is what let the divergence ship in the first place.
