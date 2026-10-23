---
name: communication-signal-to-noise
description: >-
  Applies the deep-modules interface-cost proxies (CHEC, ILC, ISC, RCK) to CHAT ANSWERS, not code: a
  verbose, heavily-cited, deeply-hedged reply is a shallow communication interface even when every
  claim in it is true. ALWAYS load when answering a question expected to affect a plan, actionable
  status, addressable/fixable, uncertainty, or urgency, and whenever answering about plan details,
  findings, or status. ALSO load, as a non-optional step, for (a) 100% of plan-related user-facing
  decisions (every OPENQ-*, UD-*, option comparison, recommendation, or "A or B" in a plan, work
  order, or grooming packet) and (b) ANY decision presented directly to the user in chat (any time
  you ask the user to choose between two or more options, plan or not). The reader is the "caller":
  their question is almost always two parts -- (a) does this affect my plan/decision/blocker, and (b)
  do I act now or can it wait. Anything that doesn't serve (a) or (b) is noise. Triggers even when the
  user never says "concise" or "tl;dr".
metadata:
  version: "1.0"
---

# Communication Signal-to-Noise

> Sibling of the **design-rubrics** family — reuses the same four proxy names (CHEC, ILC, ISC, RCK)
> `deep-modules` defines for code interfaces, applied here to the **chat-answer interface**: the
> reader is the caller, their question is the contract, and the answer is the implementation. See
> [`deep-modules`](../deep-modules/SKILL.md) for the proxies' original code-interface definitions.

## The headline rule: resolve, don't narrate

The failure mode this skill exists to catch is always the same shape: the agent writes down its own
reasoning trace — what it checked, in what order, with what internal names, through what retraction
— instead of writing down only the reader's two answers. **Draft the verdict table first** (the
reader's actual questions, one row each, answer-first), and only *then* ask whether any supporting
clause earns its place inline. Never let supporting material earn its place by default.

## The reader's real question (the baseline)

Unless the user explicitly asks for depth ("explain in detail", "walk me through it", "I need more
context"), their question collapses to exactly two parts:

1. **Does this affect me?** — my plan, my decision, my blocker, my goals.
2. **Do I need to act now?** — or does waiting cost me nothing (my future options stay open)?

The user is not trying to learn the codebase, fix the bug themselves, or memorize a library's
quirks or call order — unless they say so. An answer that teaches those things by default, when not
asked, has paid interface cost nobody is spending.

## The four proxies, applied to chat

### CHEC — unresolved decision branches
**What it means here**: a branch the reader must still personally resolve after reading, to know
what to do next.
**High markers**: a sub-header phrased as a question with no one-word verdict directly under it
("Does it matter" with no Yes/No); a hedge ("however", "that said") where the final position is
never named; a correction or retraction left to sit without restating its effect on the bottom line.
**Fix — verdict-first ordering**: every answer-bearing sentence/row leads with the resolving word
(Yes / No / Not yet / Not applicable) before any supporting clause. If you can't put a one-word
verdict first, the branch isn't resolved yet — keep editing, don't send it.

### ILC — internal-process leakage
**What it means here**: an internal fact about *how the agent produced or verified the answer* —
code symbols, module names, review-process narration, the agent's own revision history — that
escapes into the answer without being translated into what it means for the reader.
**High markers**: bare code symbols/function names with no inline gloss of why the reader should
care; narration of the agent's own review/revision process ("after Critic review...", "I initially
thought X but...") presented as content; a second full section that exists only because the agent's
internal trace surfaced more detail, not because the reader asked a second question.
**Fix — translate, don't cite**: any internal symbol/ID that must appear gets its caller-relevant
meaning glossed in the same clause it's named in. Delete narration of your own verification/revision
process unless the reader explicitly asked "how did you check this."

### ISC — concept surface count
**What it means here**: the count of distinct named concepts — headers, sub-headers, labeled
abstractions — the reader must individually take in to extract the answer.
**High markers**: more than ~2-3 markdown headers/bolded subsection names for a single yes/no-shaped
question; nested sub-subsections; two "full sections" answering what is structurally one question
from two different angles.
**Fix — collapse to the reader's actual question set**: before drafting, write down the literal
questions the reader is asking (usually 2-4). Every subsection must map 1:1 to one of those; any
header that doesn't map to a reader question gets deleted, not shortened.

### RCK — ungleamed knowledge
**What it means here**: a fact the reader must already know, or go look up, because it was cited by
bare ID or jargon rather than restated. Labels without a direct quote or restated content ARE RCK.
**High markers**: a citation like "analysis 354" / "CAR 318" / "§10.3" with no clause stating the
one fact that citation contributes; an acronym or proper noun used as if already defined for *this*
answer, with no inline plain-language gloss; relying on the reader having tracked an earlier
multi-turn thread without restating the current state.
**Fix — inline the one sentence**: every ID/jargon citation carries its single load-bearing fact in
the same clause (`<ID>: <the one fact that matters>`). If the fact won't fit in one clause, the
citation doesn't belong in this answer — cut it or move it to an appendix the reader can ignore.

### Why these four are a complete decomposition of "noise"
Mapping the reader's two real questions onto the proxies: **ILC** = implementation-detail noise that
serves neither (a) nor (b); **RCK** = citation/jargon trivia forced onto the reader without being
resolvable into (a)/(b); **ISC** = sheer concept count — every extra header is another thing the
reader must process before reaching (a)/(b); **CHEC** = decision branches the answer leaves
unresolved, i.e. exactly the reader's own (a)/(b) questions left half-answered. Nothing a reader
would call "noise" falls outside these four.

## Presenting a decision (the decision-support layer)

The four proxies above are all *subtraction* — they tell you what to cut. A user-facing **decision**
also needs *construction*: a shape a human can actually decide from. **This section fires on every
decision you put in front of a reader** — 100% of plan-related decisions (`OPENQ-*`, `UD-*`, option
comparisons, recommendations, "A or B") and any decision you raise directly in chat. It is not a
judgment call; applying this layer is part of presenting the decision. The `design-rubrics`
scorecard is the rigor underneath; the techniques below are the interface the reader reads.

- **Plain-language "what this is" preamble** — define the subject in the reader's own domain words
  *before* the first option. Kills RCK up front: the reader never has to go look up what the decision
  is even about.
- **Decider-indexed columns** — build the comparison so the COLUMNS are the reader's own decision
  questions ("Where does it work? / Ready now? / What does it cost me? / What does it prevent
  later?") and the ROWS are keyed by what the reader wants — not the system's taxonomy (path, ADR
  rung, owning plan, internal IDs). Lowers RCK and ISC: the table is sufficient to decide from
  without decoding the system's internal vocabulary.
- **Name the single pivot question** — distill the decision to its one real fork and state it in one
  sentence. Resolves CHEC: the reader sees exactly the one branch they have to settle.
- **Layered progressive disclosure** — put a 3-line decision any reader can act on at the very top
  (the recommendation + the one fork + the one caveat), then clearly-separated optional depth below.
  Keeps ISC low for the reader who only needs the answer. **Anti-example (do NOT do this):** appending
  a self-narrating "a note on how I built this / the audit layer underneath" meta-paragraph. That is
  an ILC violation — internal-process narration the reader never asked for — and it re-buries the
  3-line answer you just surfaced. Depth means *more of the decision*, never a tour of your process.
- **The "what happens if I do nothing?" question** — always answer the cost of inaction. It is the
  reader's implicit third option; leaving it unanswered is an unresolved CHEC branch.
- **Per-option foreclosure line** — for each option, state what it PREVENTS or OPENS later (lock-in
  vs. future capability). This is the one dimension the four interface-cost proxies cannot see, and
  it is usually what the reader cares about most.
- **The "set aside this note" device** — park an anticipated-but-irrelevant technical detail in one
  clause ("one technical note you can set aside: …") so it neither becomes noise nor opens an
  unanswered CHEC branch in the reader's head.
- **Crisp closing fork** — end with the literal choice: "all I need from you: X, or Y."

## Self-check before sending

- [ ] Every answer-bearing line leads with a verdict word (Yes/No/Not yet/N/A).
- [ ] Every doc-ID/jargon citation carries its one load-bearing fact inline, in the same clause.
- [ ] Header/subsection count maps 1:1 to the reader's actual question set — no extra.
- [ ] No narration of your own verification/revision process, unless the reader asked for it.
- [ ] Depth is available on request, not delivered by default.
- [ ] (Decisions) The one pivot question is named explicitly.
- [ ] (Decisions) Every option states what it forecloses or opens later.
- [ ] (Decisions) The cost of doing nothing is answered.
- [ ] (Decisions) No self-narrating meta-note about how the answer was built.

## Worked example (compressed)

**Before (high CHEC/ILC/ISC/RCK)**: a ~600-word answer with two full sections, five sub-headers
each ("What was literally proposed" / "Why that's broken" / "What a caller would observe" /
"Blast radius" / "Does it matter" / "The topology, concretely" / ... / "One nuance, corrected after
Critic review"), each paragraph carrying multiple bare file:line citations and document-ID numbers,
and an entire paragraph narrating an internal review correction the reader never asked about.

**After (low across all four)**: a 4-row table, `Question | Answer`, each answer leading with a bold
verdict word ("**No.**", "**Yes, trivially, if/when...**"), zero internal-process narration, and one
closing sentence connecting back to the reader's original question. Same underlying facts, same
rigor — the proxies measure *delivery*, not correctness.

## Exceptions — when more detail is correct, not noise

- **The user explicitly asks for depth** ("explain in detail", "I need more context", "walk me
  through it"). Depth on request is not noise; depth by default is.
- **Mandatory verbatim evidence** (e.g. QA's canonical summary line and literal invocation
  requirements) is oracle evidence, not padding — this skill does not license dropping a required
  proof artifact. Lead with the verdict, then include the mandatory evidence.
- **A named risk or control must still be stated precisely** (e.g. Security's specific
  vulnerability/remediation). Brevity must never drop the control itself, only the surrounding
  narration.
- **A mandated artifact's required-fields schema** (e.g. `executive-summary`'s Required Fields
  table) is not shrunk by this skill — produce every mandated field, written densely.

## Related

- [`deep-modules`](../deep-modules/SKILL.md) — the proxies' original code-interface definitions and
  counting convention; this skill reuses the names, not the counting mechanics.
- [`design-rubrics`](../design-rubrics/SKILL.md) — the rigorous, auditable option-comparison
  scorecard (`OPENQ-*`/`ALT-*` framing). These are **layers, not alternatives**: `design-rubrics`
  produces the dense audit scorecard that goes on the record (the audit layer), and THIS skill owns
  the human-facing decision-support presentation that *consumes and summarizes* that scorecard (the
  interface layer the reader actually reads — see "Presenting a decision" above). A user-facing
  option-decision requires **both**: the scorecard underneath, the decision-support presentation on
  top.
- [`executive-summary`](../executive-summary/SKILL.md) — the artifact-specific lane for plan-status
  snapshots at approval transitions; its required-fields schema is not shrunk by this skill — produce
  the mandated fields, written densely.

> **Deployment note**: `~/.agents/skills/communication-signal-to-noise/SKILL.md` is a separate
> deployed copy, not a symlink. Edits to this source file must be re-synced to that path to take
> effect; the re-sync is a separate step and is not performed by editing this file.
