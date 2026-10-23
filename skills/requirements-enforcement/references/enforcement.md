# Enforcement -- triage, phase obligations, registry, templates

Read this file when: triaging a failure or escape, filing registry entries, writing or reviewing an exposure declaration, or creating/restructuring the failure-mode registry. Kernel rules (three-level model, Rule 1, Rule 2, oracle typology, maturity ladder) are in SKILL.md and are assumed here.

---

## Registry layout and budgets

```
failure-modes/
  INDEX.md        # one line per ACTIVE mode -- the only file planning ever loads
  FM-<CLASS>.md   # one file per class: guarantee ID, modes, oracles, instances
```

**Guarantee IDs.** `G-<LAYER>-<MNEMONIC>`. Same layer namespace as FM IDs (`R` runtime/wire-contract, `P` process/planning, `T` test-level, `D` design/review); mnemonic is 3–9 uppercase characters naming the invariant (e.g., `G-R-TRUNC`, `G-P-COORD`). The FM class for a guarantee mirrors its guarantee ID — `G-R-TRUNC` anchors `FM-R-TRUNC` — so no cross-reference table is needed. Mnemonics must be unique within a layer; a collision means the two guarantees are not distinct enough to warrant separate entries.

**FM IDs.** `FM-<LAYER>-<CLASS>.<MODE>.<NNN>`. Layer namespaces keep unlike things sorted without separate machinery: `R` runtime/wire-contract, `P` process/planning, `T` test-level, `D` design/review. Example: `FM-R-TRUNC.PAGINATION.003`. IDs are stable; plans, tests, and reviews reference them without loading files.

**Oracle IDs.** The `Oracle` column holds a resolvable ID whose prefix names what resolving it gets you: `T-<NNN>` a test in the codebase (structural), `E-<NNN>` an eval harness + corpus (measured, automated), `A-<NNN>` a **versioned procedure document** an agent executes (measured, adjudicated). `A-` IDs resolve to a file, not a runnable -- store it beside the registry (e.g. `failure-modes/oracles/A-001-<slug>.md`) and treat a change to it as a registry change. Prefixes are unique across the project; the type column and the prefix must agree.

**INDEX budget: 60 active modes** (project override allowed -- declare it in INDEX frontmatter with a one-line justification, and set it deliberately during bootstrap rather than after the cap trips mid-stream). Provisional classes (candidate-anchored) and their modes do **not** appear in INDEX and do not consume budget. Hitting the budget forces a consolidation review: re-run Rule 2 across neighboring modes; oracles that can merge without weakening, merge.

**Status lifecycle** (per mode and per instance): `hypothesized` -> `observed` -> `mitigated` -> `retired`. Record _how_ observed: `escaped` (reached QA or later -- highest evidentiary weight), `induced` (caught pre-merge by oracle or review). Retired modes leave INDEX; fully retired class files are deleted -- git is the archive.

---

## Triage: the decision procedure for any new failure

Run top to bottom; stop at the first match. Each outcome is a different named gap with a different fix -- the attribution is the registry's primary product.

1. **Which ledger guarantee does it violate?** Check at any maturity. None -> **contract gap.** Mint a candidate guarantee using the one-line format below, create the provisional class, file the instance there, record the attribution. Done -- ratification is a separate, human, ledger-side step.
2. **More than one guarantee violated?** Genuine two-class membership exists (a root violation producing a distinct observable harm). **File under the mode whose oracle detects earliest in the lifecycle** (static/structural checks beat runtime advisories) -- that is the cheapest interception point and usually the root, so fixing there extinguishes the harm. Add `also-violates: <class-id>` on the instance. One record, one primary mode, one cross-reference; never duplicate the instance.
3. **Does an existing mode's oracle catch it?**
   - Oracle exists and is wired -> known mode. File the instance, add its regression test. (If this arrived as an escape, the wiring claim is suspect -- verify before choosing this branch.)
   - Oracle would catch it in principle, but the test is missing, skipped, or not wired into the phase that should have run it -> **coverage gap.** File the instance AND fix the wiring. A coverage gap recurring identically is the signal to convert the oracle from a reminder into a hard gate (definition-of-done / CI-blocking).
4. **No existing oracle catches it.** Decide by Rule 2:
   - Same mechanism, oracle written too narrowly -> **strengthen the oracle** until it catches old and new instances; file under that mode. The strengthened oracle must still read as a scoped property of the guarantee -- if it degenerates toward "fails iff it fails," it is two modes.
   - Genuinely different mechanism -> **taxonomy gap.** Mint a new mode with its own oracle (structural or measured); file the instance under it.

**Candidate mint format** (the only ledger write the QA path performs):

```
G-<LAYER>-<MNEMONIC> | <statement: one falsifiable clause> | candidate | scope: project | minted-by: <agent/plan> <date>
```

Example: `G-R-TRUNC | Search responses are complete OR meta.truncated=true | candidate | scope: project | minted-by: plan-042 2026-07-14`

Append to `guarantees/LEDGER.md`'s candidate section. Everything else about the line's lifecycle is ledger work (ledger.md) -- do not ratify, promote, or edit other lines from the triage path.

**Attribution record** (append wherever the project tracks QA outcomes, and to the class file's instance row):

```
escape: <defect ref> -> FM-R-TRUNC.PAGINATION.003
attribution: coverage gap        # exactly one of: coverage gap | taxonomy gap | contract gap
action: <regression test added; oracle wired/strengthened; candidate G-R-TRUNC minted>
```

---

## Phase obligations in full

### Planning -- the exposure declaration

Load INDEX.md only. Produce, inside the plan:

```markdown
## FM Exposure

Declared against: failure-modes/INDEX.md @ <commit-or-date>

| ID                    | Why plausibly touched                        |
| --------------------- | -------------------------------------------- |
| FM-R-TRUNC.PAGINATION | changes result assembly ordering in search() |
| FM-R-IDENT (class)    | adds a new identity-bearing object type      |
```

or `none -- <one-line rationale>` plus the same `Declared against` pin. Rules:

- Declare at mode level when known; class level when the change is broad. A class-level declaration obligates implementation to load that whole class file.
- The pin makes staleness detectable -- a reviewer can see whether modes were minted after the declaration was written.
- The rationale on `none` is mandatory; it is the reviewable part.
- **Plan-local guarantees** discovered while planning ("this change assumes X") are declared in the plan with a plan-scoped ID, ratified by the plan's approver, and guarded by plan-scoped oracle tests, all inside the plan document. They never touch INDEX. Their promotion path is ledger work.

### Implementation / TDD

Load class files for declared classes only. For each declared mode: its oracle test exists, or write it now (structural in CI; measured registered with its cadence, or `pending-corpus` with the corpus need recorded; **adjudicated** registered with its `A-` procedure document, its corpus, and its threshold, or `pending-corpus` with the corpus need recorded). Instance regressions are opportunistic, never mandatory.

An adjudicated oracle is not discharged by "review will catch it". Leaving the Oracle column `--` on an observed mode makes it a coverage gap by definition (below), so the procedure document is what converts a judgment obligation into a named, resolvable oracle rather than an unenforced intention.

### Code review / Critic

Load the diff and the declaration -- not the registry. Answer exactly two questions:

1. Does the diff expose a class the declaration omitted? -> amend the declaration; record the omission (a process defect distinct from any code defect).
2. Does the diff suggest a mechanism the taxonomy lacks? -> open a taxonomy item for QA-path triage; the reviewer never files registry entries directly.

**Method for question 1 when an adjudicated oracle governs the artifact.** This is not a third question -- it is how question 1 is answered when the declared guarantee is a completeness-of-consideration one (`measured (adjudicated)`, SKILL.md). Run that mode's `A-` procedure: enumerate candidates from its named sources and write the numbered list **before reading the artifact's own declaration**. The order is load-bearing, not stylistic -- reading the declaration first anchors the reviewer onto the author's set, and a review that starts there will evaluate what is present and terminate, having been structurally unable to produce a finding. Then adjudicate each candidate against the declaration: undeclared (a finding), declared elsewhere in other words (cite where), or inapplicable (the candidate was wrong -- **recorded anyway**). Because the candidate count is fixed before any verdict is known, dropping an inapplicable one leaves a numbered row with no verdict rather than silence. Absent an adjudicated oracle, question 1 is answered as before, and the reviewer still files nothing directly either way.

### QA / escape analysis

**Every escaped defect is filed through triage -- no exceptions.** This is the only mandatory registry write path and the only way the taxonomy and ledger grow. An escape fixed but not filed deletes the system's only growth signal.

---

## Templates

### INDEX.md

```markdown
---
project: <name>
mode_budget: 60 # override + one-line justification if changed
ledger: guarantees/LEDGER.md
---

# Failure Mode Index

| Mode ID | Guarantee | Oracle | Type | Status | Instances |
| --- | --- | --- | --- | --- | --- |
| FM-R-TRUNC.PAGINATION | G-R-TRUNC | T-041 | structural | observed (escaped) | 3 |
| FM-R-LEVER.WEAK-PROXY | G-R-LEVER | E-007 | measured (pending-corpus) | observed (escaped) | 11 |
| FM-P-COORD.LINE-ROT | G-P-COORD | T-090 | structural | observed (induced) | 2 |
| FM-D-BLIND.UNENUM | G-D-BLIND | A-001 | measured (adjudicated) | observed (escaped) | 5 |
```

One line per active mode; no prose, no instance rows, no mitigation notes. Guarantee column is an ID -- the statement lives in the ledger only. `Oracle` is a resolvable test/eval ID; `--` is legal only while status is `hypothesized` (an observed mode without an oracle is a coverage gap by definition). Sort by layer, then class.

### Class file: FM-<LAYER>-<CLASS>.md

```markdown
---
class_id: FM-R-TRUNC
guarantee: G-R-TRUNC # ID only -- never the statement text
status: observed
---

# FM-R-TRUNC

## Mode: FM-R-TRUNC.PAGINATION

**Mechanism.** Result assembly applies the page cap before the completeness check, so result sets landing exactly on a cap boundary report complete while dropping the remainder. (<=3 sentences.)

**Oracle.** `T-041` \* structural -- property: for any query, `len(results) < cap` OR `meta.truncated == true`, checked across cap-adjacent sizes with generated corpora. Last revalidated against G-R-TRUNC wording: <date>.

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | mitigated | escaped <date> | -- | corpus of exactly `cap` matches; truncated=false |
| .002 | mitigated | induced (T-041) <date> | -- | cap+1 with post-filter removing 1 |
| .003 | observed | escaped <date> | FM-R-ADVSUP | multi-page walk; final page boundary |
```

Each instance gets a pinned regression test named for its ID. Oracle narrowing (property weakened, scope reduced) requires a dated line stating what narrowed and which instances remain covered. Mitigation details do not live here -- link the plan/commit in the repro column if needed; the registry records and attributes, plans mitigate.

**Adjudicated oracle line.** Same position in the class file, different payload -- the procedure, its corpus, and the threshold that validates the procedure (never the artifact under review):

```markdown
**Oracle.** `A-001` \* measured (adjudicated) -- procedure: `failure-modes/oracles/A-001-blind-spot-enumeration.md` v3. Enumerates candidates from named sources BEFORE reading the artifact's own disclosure, records every candidate with a verdict (undisclosed / disclosed-elsewhere / inapplicable). Corpus: 12 labelled plan-critique pairs. Threshold: recall >= 0.6, precision >= 0.4 over the corpus. Last revalidated against G-D-BLIND wording: <date>.
```

The recorded `inapplicable` verdicts are the oracle's false positives and are load-bearing: precision is not computable without them, and an adjudicated oracle whose record contains only confirmed findings has been eroded (SKILL.md, Oracle erosion).

### Provisional class file (candidate-anchored)

Same template, plus frontmatter `provisional: true` and guarantee pointing at a candidate-maturity guarantee ID (`G-<LAYER>-<MNEMONIC>`). Not listed in INDEX; modes may have `oracle: --` indefinitely; the instance table is the accruing evidence that ratification will weigh.
