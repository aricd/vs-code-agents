---
name: obs-create
description: >-
  Creates an Orthogonal Basis Set (OBS) for a service or an existing vocabulary (a DSL, grammar,
  schema or API surface). Enumerates the interfaces or the grammar, IR and codegen, frames the
  domain, negotiates scope, runs a 4→2→1 brainstorming tournament under lean + deep-modules
  rubrics, and produces a typed OBS interface definition (for a vocabulary, a grammar/IR sketch
  with an old-to-new mapping). Invoke with /obs-create followed by the service name.
  Redesigning an existing DSL under output-equivalence gates is
  basis-redesign's job; vocabulary mode here is normally entered from its stage 05.
argument-hint: "ServiceName — e.g. 'AnnotationService', 'PlanDataService', 'ToolOracle'"
---

<!-- scorecard-lint: skip -- specification document: defines/discusses the scorecard format rather than instantiating it -->

# obs-create — Orthogonal Basis Set Workflow

> You are running the **obs-create** workflow. Its purpose is to find the minimum set of
> orthogonal primitives that is equivalent to a service's interface — an interface small enough
> to be deeply learnable, powerful enough to compose every domain verb the user cares about.
>
> The workflow runs in 4 stages. Complete each stage before advancing.
> At each stage you MUST present results to the user and wait for their input before continuing.

All paths below are relative to this skill's directory. Each stage's procedure lives in its own
file under `references/`; read a stage's file when you enter that stage.

| Stage | File |
|---|---|
| 0 Kickoff | this file (below) |
| 1 Interface Analysis | [references/stage-1-interface-analysis.md](references/stage-1-interface-analysis.md) |
| 2 Domain Framing + Scope Negotiation | [references/stage-2-domain-framing.md](references/stage-2-domain-framing.md) |
| 3 Brainstorming Tournament (4 → 2 → 1) | [references/stage-3-tournament.md](references/stage-3-tournament.md) |
| 4 Final OBS Report | [references/stage-4-final-report.md](references/stage-4-final-report.md) |

---

## OBS Methodology

**What is an OBS?** The Orthogonal Basis Set is the smallest set of primitives from which every
domain verb can be derived by composition. A primitive is *orthogonal* if it cannot be derived
from the union of all other primitives. The goal is an interface where IC is bounded and the
common case is zero-tax.

**Worked examples** (look in `.agent-output/analysis/` for files named `*-obs-final.md` in
your workspace — these are prior completed OBS analyses showing the expected output format).

> **Preconditions.** This skill works best for services with at least 2 of:
> {message-bus (RMQ/DDS), database/file I/O, a render path}. For pure in-process libraries
> with no external interface, the exercise degenerates — exit at Stage 0 and say so.
> A vocabulary target (a DSL, grammar, schema or API vocabulary) is not a degenerate case: it is
> handled in vocabulary mode (see "Target modes" below), where the two-of-three test above does
> not apply.
>
> **Language note.** The interface-enumeration patterns in Stage 1b are provided for C++ and
> Python. If your service uses a different stack, adapt the search patterns accordingly and
> note the adaptation.

### Key definitions

- **Orthogonal**: primitive A cannot be derived from the union of all other primitives
- **ISC**: Interface Surface Count — entry points + named types + N-variant union members + return shapes
- **ILC**: Information Leakage Count — internal decisions that escape to the caller
- **RCK**: Required Caller Knowledge — implicit preconditions the caller must know
- **CHEC**: Caller-Handled Error Conditions
- **IC = ISC + ILC + RCK + CHEC** (the total interface cost; lower = deeper module)
- **Lean rung**: stop at the first rung that holds:
  1. Doesn't need to exist (pseudo-primitive → eliminate)
  2. An existing seam already carries it
  3. Existing tools/combinators compose it
  4. The platform/protocol already provides it (e.g. render wrapping an existing transport)
  5. One artifact, one edit
  6. Minimum that works
- **Render axis split**: 3D viewport render vs GUI-state/panel render — these may be independent axes

**Scoring convention:** N-variant discriminated union = N ISC items. A `x | null` sentinel = 1 item.

### Target modes

obs-create runs in one of two modes, fixed at Stage 0 and stated in every stage's output.

- **Service target** (default): the target is a service with external interfaces. Every stage
  runs as written, outside the "Vocabulary target" subsections.
- **Vocabulary target**: the target is a vocabulary — a DSL, grammar, schema or API vocabulary.
  Stages 0–4 run in the same order with the same gates; each stage has a "Vocabulary target"
  subsection stating what changes. In short: the interface to enumerate is the grammar rules, IR
  node kinds, codegen targets and host-language-defined vocabulary; nouns are construct kinds or
  IR entities, verbs are the operations a user can express, adjectives are attributes and
  modifiers; the render axes are N/A; the tournament's seeds carry an old → new mapping and
  Round 2 returns finalists with their mappings; and the final report sketches a grammar/IR in
  place of a client-language interface.

**Hand-off entry.** Vocabulary mode is normally entered from `basis-redesign` stage 05, which
supplies a ready Stage 1 results block (vocabulary layers, catalog, dispositions with overlay
flags, the alternative bases from its stage 04), the confirmed scope decisions, and the Run
Declaration's capability baseline. Stages 0-4 all still run in a hand-off, each in a reduced
form:

- **Stage 0** reads the vocabulary name and source location from the hand-off, checks that the
  location exists, and fixes vocabulary mode. It skips the consumer-path confirmation, because
  the supplied catalog already names the IR, generator and corpus.
- **Stage 1** uses the supplied block and does not re-enumerate, then presents it to the user
  and asks its confirmation question.
- **Stage 2** presents the supplied scope decisions and asks only whether any changed; it does
  not re-ask the scope question.
- **Stage 3** runs the tournament. Round 2 returns the winner and runner-up, each with its
  old → new mapping, to the caller, which decides which finalists go on to its gates.
- **Stage 4** runs for each finalist the user selects (one unless the caller gates more), after
  the caller has received the finalists, and writes the final report with its grammar/IR sketch.

In standalone vocabulary mode, with no hand-off, every stage runs in full. See
[../basis-redesign/SKILL.md](../basis-redesign/SKILL.md). Renaming
`references/stage-3-tournament.md`, or changing either payload, is a breaking change for both
skills.

---

## Stage 0 — Kickoff

**If the service name was not supplied as an argument, ask now:**

> Which service should we build an OBS for?
> (Provide the service name as it appears in the source tree — e.g. "AnnotationService",
> "PlanDataService", "ToolOracle". If you're unsure of the exact name, describe what it does
> and I'll search for it.)

Once the service name is confirmed, do a quick existence check:
```
find <workspace-root> -maxdepth 4 -type d -iname "*<ServiceName>*" | grep -v build | head -5
```
**If no matching directory is found:** tell the user "Service `<ServiceName>` was not found.
Please check the name (case-sensitive) or provide the directory path." Do NOT proceed to
Stage 1 until a source directory is confirmed.

**If the service has fewer than 2 external interface types** (e.g. only file I/O, no bus
topics, no DB): report this, ask whether to continue with a reduced OBS, and note that the
result will have very few primitives (possibly N=1).

### Vocabulary target

Choose vocabulary mode when the target is a DSL, grammar, schema or API vocabulary, or when a
hand-off from `basis-redesign` supplies the Stage 1 payload. The precondition above accepts a
vocabulary target; the "fewer than 2 external interface types" exit does not apply.

- Ask for (or read from the hand-off) the vocabulary's name and the location of its grammar or
  schema source, in place of a service name. Run the same existence check against that location;
  do NOT proceed to Stage 1 until the source location is confirmed.
- Confirm at least one consumer path to enumerate in Stage 1: an IR, a code generator, or a
  corpus of documents written in the vocabulary. With none, report it and ask whether to
  continue with a reduced OBS.
