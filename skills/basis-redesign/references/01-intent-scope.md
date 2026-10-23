# Stage 01 — Intent and scope

Contents: [Entry and exit](#entry-and-exit) · [Step 1 — Quote the criterion](#step-1--quote-the-criterion) · [Step 2 — Intent, function and scope brief](#step-2--intent-function-and-scope-brief) · [Step 3 — Vocabulary-layer table](#step-3--vocabulary-layer-table) · [Step 4 — Run Declaration](#step-4--run-declaration) · [Step 5 — User checkpoint](#step-5--user-checkpoint)

This stage fixes what is being redesigned, how strictly "same output" is judged, and which
earlier schema versions must keep working. Every later stage consumes the Run Declaration it
produces; a wrong scope here is inherited by all of them.

## Entry and exit

- **Entry:** the target vocabulary is named; the user's criterion is available to quote.
- **Exit:** an intent, function and scope brief; a vocabulary-layer table with one in/out
  decision per layer; a complete Run Declaration; the user's confirmation of it.

## Step 1 — Quote the criterion

Apply the Criterion Ledger of [`literal-intent-fidelity`](../../literal-intent-fidelity/SKILL.md)
as written: pin the target (working tree, branch, directory), quote the user's criterion
verbatim, state the per-candidate test, and declare any test you would use that differs from the
quote. That skill is normative here; nothing in this stage relaxes it. Every scope decision
below is made against the verbatim quote, never against a paraphrase, a prior analysis, or a
narrower framing that is fresh in context.

## Step 2 — Intent, function and scope brief

Write three short statements about the vocabulary, each with its source.

| Statement | Answers | Typical sources |
|---|---|---|
| **Intent** | What is the vocabulary *for*; what problem do its authors say it solves | Design documents, ADRs, README, the user's own words |
| **Function** | What it does mechanically: inputs accepted, outputs generated, the pipeline between them | Grammar or schema, the intermediate representation, the generator, a sample of corpus files |
| **Scope** | What belongs to the vocabulary and what lies just outside it | The layer table in Step 3 |

Rules that hold for the brief:

- Mark each statement `stated` (a source says so) or `inferred` (you concluded it). An inferred
  statement is shown to the user at the checkpoint, not buried.
- When documentation and implementation disagree, record both; do not resolve the conflict
  silently. The implementation decides what the corpus can do today; the documentation decides
  what its authors meant.
- The brief describes; it does not propose changes.
- A rule the code enforces that is not in the project's guarantee ledger is surfaced as a
  **candidate guarantee**, shown to the user at the checkpoint with its enforcing construct. Unlike
  a ledgered candidate row, it holds its construct: the construct under it is `guardrail: held`
  at stage 03 until the user decides. Do not ratify the candidate without the user.

## Step 3 — Vocabulary-layer table

A vocabulary rarely lives in one place. List every layer that contributes to what a corpus
author can write, and decide each layer in or out against the quoted criterion.

| Layer | What it holds | Example |
|---|---|---|
| Grammar-defined | Constructs the grammar or schema itself introduces | Keywords, node types, operators |
| Host-language-defined | Constructs inherited from the language the vocabulary is embedded in | Builtins, standard operators |
| Library-defined | Constructs supplied by a shipped library | Standard policies, bundled templates |
| Sub-languages | Embedded languages with their own rules | Expression languages, query strings, templates |

For each layer, record: the layer, in or out, the criterion's words that decide it, and the
evidence. A layer that the quote does not clearly exclude is in until the user says otherwise;
silently dropping a layer is a proxy substitution. A layer marked out is listed in the report so
the exclusion is visible. Whether a host-language layer is *in scope to be redesigned* is a
separate question from whether it may be *used to compose a replacement*; the second is the
composition relation in Step 4.

## Step 4 — Run Declaration

The Run Declaration is the contract between this stage and every later one. Fill every field. A
field is either given a default below or marked **must declare**; a **must declare** field has no
default, and the run stops here until the user supplies it. A stage may not start while a field
it consumes is undeclared.

| Field | Meaning | Default | Consumed by |
|---|---|---|---|
| `run_goal` | `snapshot` (stages 01-04 and 10; never mandates removal), `compress` (all stages except the stage-05 tournament), `redesign` (all stages) | **must declare** | All |
| Capability-baseline corpus | The corpus whose generated output defines "same". Name its location, size and the version of the vocabulary it was written in | **must declare** | 02, 03, 08 |
| Vocabulary layers | The Step 3 table, one in/out per layer | **must declare** | 02, 03, 05 |
| Version notion(s) and compatibility contract | Each way the vocabulary is versioned (schema version, format edition, grammar release), which prior versions must remain accepted, and what "accepted" means (parses *and* yields the same output). The corpus files written in each version | **must declare** | 03, 06, 09 |
| `equivalence_level` | How strictly outputs are compared: `byte`, `normalized` (list every normalization, for example generated ids derived from paths) or `behavioral` (name the behavior and how it is observed) | `byte` | 03, 08 |
| `equivalence_strength` | `hard` or `advisory`; see below | `hard` | 03, 04, 08, 10 |
| Oracle and pinned baseline | The executable check that compares generated outputs, and the commit that fixes the baseline generator. If no oracle exists, declare `none` | **must declare** | 03, 08 |
| Rung-2 check | The check that judges a stage-03 composition `passed`: the oracle itself, or, when the oracle compares generated bytes, a declared semantic check (validator equality plus a behavioral probe). It settles rung-2 status only; the oracle gates stage 08. Under `oracle: none` there is none | The oracle | 03 |
| Composition relation | Which constructs may be used to compose a replacement for another. Host-language escape hatches (raw code, shell-outs, eval-like constructs) are **excluded** unless the declaration says they count | In-scope layers only; escape hatches excluded | 03 |
| `transitive` | Whether a construct obtained by composition may itself be used as a building block (`true`), or only constructs present in the remaining set may (`false`) | **must declare** | 03, 04 |
| `realization_mode` | `in-run` (stage 07 builds the candidate) or `hand-off` (stage 07 writes an implementation hand-off and gate status stays `pending`) | `in-run` | 07, 10 |
| `finalists_to_gate` | How many candidates stages 06-09 carry. The compression candidate counts toward it | `1` | 05 |
| Budget | Ceiling on delegations (passes, when nested delegation is unavailable) and elapsed effort for the run; confirmed again after the stage-02 pilot | **must declare** | 02, 03 |

### `equivalence_strength`

- **`hard`**: no removal or redesign verdict is final until the oracle has executed and passed
  (stage 08). Stage 04 admits only compositions whose oracle status is `passed`.
- **`advisory`**: the run still executes compositions at stage 03 and still needs a passing
  stage-08 oracle for finality, but stage 04 also admits compositions that were found and not
  yet executed (`unproven`). A verdict that rests on one, or whose stage-08 oracle has not
  executed and passed, is recorded `output-unverified` and is never reported as final. Advisory
  widens what is *proposed*; it never widens what is *final*.

### When no oracle exists

`oracle: none` is a legitimate declaration, and it has a fixed consequence: no composition can
reach `passed`, so every found composition is `Unproven` (there is no rung-2 check either), no
verdict can be final, and a
`compress` or `redesign` run can finish only with `output-unverified` results. Say so at the
checkpoint and let the user choose between building the oracle first and running `snapshot`.

### Amending the declaration

A change to any field after confirmation is a new declaration. Re-confirm it, and treat every
artifact of every stage that consumed the changed field (see the last column) as stale: redo
those stages, starting from the earliest.

## Step 5 — User checkpoint

Present, in one message: the verbatim criterion and its test; the brief with `stated` /
`inferred` marks; the layer table; the Run Declaration with each defaulted field marked
`default`; and every declared proxy that still needs acceptance. Do not start stage 02 until the
user confirms the Run Declaration. A declared proxy with no answer is an open question, not a
default.
