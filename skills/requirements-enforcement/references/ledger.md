# Ledger -- guarantee lifecycle

Read this file when: minting, ratifying, promoting, or superseding guarantees; revalidating
oracles after a guarantee changes; running the ledger review cadence; or creating the ledger.
Kernel rules (maturity ladder, Rule 1, oracle typology) are in SKILL.md and are assumed here.

---

## LEDGER.md

```markdown
---
project: <name>
formal_system: <name/location of the external requirement system, if any>
review_cadence: <e.g. per plan close, or monthly>
---

# Guarantee Ledger

## Active

| ID | Statement (one falsifiable clause) | Maturity | Scope | FM class | External ref |
|---|---|---|---|---|---|
| G-R-TRUNC | Search responses are complete OR meta.truncated=true | adopted | project | FM-R-TRUNC | -- |
| G-P-COORD | A plan anchors facts by symbol; line numbers are hints only | adopted | project | FM-P-COORD | -- |
| G-R-LEVER | Recommended discovery levers select the intended set at >= the declared precision threshold | candidate | project | FM-R-LEVER (provisional) | -- |
| G-R-PERF | Fan-out completes within the declared latency budget at the declared class count | formal | project | FM-R-PERF | SYS-RQ-112 |

## Superseded

| ID | Superseded by | Date |
|---|---|---|
| G-R-COMPL | G-R-TRUNC | <date> |
```

Discipline, non-negotiable:

- **One falsifiable clause per line.** No mitigation plans, design rationale, or risk essays --
  the ledger's depth comes from staying a thin, stable interface over a growing body of
  enforcement evidence. Rationale lives in the ratifying plan or ADR; link nothing here.
- **Statement text lives here and nowhere else.** Class files, plans, and tests reference the
  G-ID. Duplicated statement text is the same decision encoded on both sides of a boundary.
- **Guarantee IDs follow `G-<LAYER>-<MNEMONIC>`** (full scheme, layer namespaces, and uniqueness
  rule defined in `enforcement.md`); the FM class mirrors the guarantee ID:
  `G-R-TRUNC` ↔ `FM-R-TRUNC` — no cross-reference table needed.
- IDs are stable forever. The Superseded section is live routing for triage (step 1 must not
  match dead guarantees), not historical commentary -- full history is in git.

## Scope

`project` or `plan:<plan-id>`. Plan-local guarantees live in their plan document, not in
LEDGER.md -- they enter the ledger only on promotion, with a fresh project-scoped ID. The plan
remains the frozen audit record of the original declaration.

---

## Ratification (candidate -> plan-local or adopted)

A **human gate**, always. Agents mint candidates freely (triage does this); no candidate
becomes load-bearing without a named human ratifying it. Ratification is a one-line edit:
maturity changes, and a one-line justification goes in the ratifying plan or commit message.
Rejection is equally legitimate -- move the line to Superseded with `superseded by: rejected` --
and an explicit "won't declare" decision is more valuable than a candidate left ambiguous,
because triage step 1 stops re-litigating it.

On ratification, the provisional class (if one accrued) activates: it enters INDEX, its
observed modes now require oracles (or are coverage gaps), and it participates in planning
declarations. The accrued instance table is the evidence the ratifier weighs.

## Promotion (plan-local -> adopted)

Triggered by countable events, not judgment -- any one suffices:

- **(a) Re-declaration** -- a second, independent plan declares the same guarantee. Recurrence
  is the system reporting that the guarantee is load-bearing beyond one change.
- **(b) Oracle outlives its plan** -- the guarantee's oracle test remains wired in project CI
  after the originating plan closes. It is de facto project-level; the ledger makes it
  explicit.
- **(c) External escape** -- an escape attributes to the guarantee from outside the originating
  plan.

Promotion is a one-line ledger append (fresh project G-ID, maturity `adopted`) plus a one-line
justification naming the event. Adopted -> formal is administrative: add the external system
reference when the mapping is made; nothing else changes mechanically.

---

## Supersession

Two distinct operations; conflating them is how failure history gets orphaned.

**Incremental revision** -- same ID, statement amended in place. The class persists. The single
obligation is **oracle revalidation**: re-read each mode's oracle against the new wording and
record (dated, in the class file) that it still expresses the property -- or strengthen it. This
is the step that silently rots if skipped.

**Qualitative replacement** -- new statement, new G-ID; old line moves to Superseded with the
pointer. Then, for each mode under the old class, re-run Rule 1 against the successor:

- Mechanism violates the new guarantee -> **reattach** the mode (and its instances) to the
  successor's class. Instances are empirical facts; they must survive requirement churn.
- Mechanism does not -> **retire** it with the old class. Retired modes leave INDEX; a fully
  retired class file is deleted. Git is the archive.

Record the reattach/retire disposition per mode in the superseding plan -- that mapping is the
delta a reviewer audits.

---

## Ledger review cadence

At the declared cadence (default: every plan close), one bounded pass over the candidate
section only:

1. Ratify, reject, or explicitly defer each candidate older than the cadence window. Deferral
   is allowed once; a twice-deferred candidate is decided or rejected.
2. Check promotion events (a)/(b)/(c) for plan-local guarantees in recently closed plans --
   event (b) in particular is mechanical: does the plan's oracle test still run in CI?

This is the countermeasure to candidate sprawl. The pass loads LEDGER.md and nothing else; if
it needs more, the candidates' statements were not falsifiable clauses and should be rewritten
before being judged.
