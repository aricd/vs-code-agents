---
oracle_id: A-001
version: 1
type: measured (adjudicated)
guarantee: G-D-BLIND
mode: FM-D-BLIND.UNENUM
status: pending-corpus
---

# A-001 — Blind-Spot Enumeration Protocol

The oracle for `FM-D-BLIND.UNENUM`. An agent executes it; the threshold validates **this
procedure**, never the document under review.

**This file is a versioned registry artifact.** Shortening the protocol, dropping a source, or
weakening a verdict rule is a registry change and must state what was dropped and which
instances remain covered (`requirements-enforcement` SKILL.md, Oracle erosion).

---

## 1. Why the ordinary reading pass cannot do this

A missing null check has a site — you point at line 40. **A missing disclosure has no site.**
Nothing in the document marks the place where a consideration is absent, so no amount of
reading finds one. The only method that works is to build the candidate set independently and
diff it against what the document claims.

Everything below follows from that. In particular the step order is not stylistic.

---

## 2. Step 1 — Enumerate, before reading the document's own disclosure

**Do not read the document's disclosure, blind-spot, FM Exposure, limitations, or
out-of-scope sections yet.** Read enough to know what the document is *about* — its objective,
scope, and the change it proposes — then stop and enumerate.

Anchoring is the dominant failure mode of this oracle and it is total: a reviewer who reads
"Blind spots: A, B" first will assess A and B, find them adequate, and terminate — having run a
review that was structurally incapable of producing a finding. The enumeration must exist as a
written, numbered artifact with a count **before** the disclosure section is opened.

Enumerate from these sources, each as its own pass. Record the source ID against every
candidate; a candidate with no source is not a candidate, it is an impression.

| ID | Source | Pass |
|---|---|---|
| **S2** | **Registry adjacency.** Walk `failure-modes/INDEX.md`. For each active mode/class, ask: does this change touch that mechanism? Include near-misses — the name-adjacent class the author will be asked about later is exactly the candidate to raise now. | required |
| **S4** | **Prior in-repo precedent.** Search closed critiques and plans for the same finding shape against earlier documents. A finding already made three times against sibling documents is the highest-yield candidate there is. | required |
| **S5** | **Document-internal consistency.** The document against itself: a claim versus its own cited evidence; a count versus its own enumeration; two sections treating the same scenario differently; a requirement whose own task ordering can violate it; a headline versus its own detail. | required |
| **S3** | **Cost-axis declines.** A `deep-modules`/`lean-design` axis (CHEC/ILC/ISC/RCK, growth trigger, substrate boundary) the document neither answers nor explicitly declines. | optional — see yield note |

**Yield note, so budget is spent where it pays.** Measured over the seed corpus (analysis 041,
24 findings): S5 produced 8, S2 3, S4 5, and **S3 produced 1**. If the review is
budget-constrained, S3 is the pass to drop — and dropping it is disclosed under §5, not
silent. S6 (a template-required field left unfilled) is deliberately **absent** from this
table: it produced 10 of 24 and is mechanically checkable, so it belongs to a structural gate
(plan 042), not to an agent's judgment.

Output of Step 1 is a numbered list with a stated total:

```
Enumerated candidates (N=7), sources recorded, written before reading §Disclosure:
1. [S5] ...
2. [S2] ...
```

---

## 3. Step 2 — Adjudicate each candidate against the document

Now read the disclosure. For **every** numbered candidate, record exactly one verdict:

| Verdict | Meaning | Required with it |
|---|---|---|
| `undisclosed` | The document neither addresses it nor names it as out of scope | **A finding.** |
| `disclosed-elsewhere` | Addressed or declined, in different words or another section | The location. Not a finding. |
| `inapplicable` | The candidate was wrong — it does not apply to this document | One clause saying why. **Still recorded.** |

**`inapplicable` rows are not optional and not an admission of incompetence.** They are this
oracle's false positives, and precision is not computable without them. An agent that records
only its confirmed hits is optimising to look accurate and has eroded the oracle while leaving
it looking better (SKILL.md, Oracle erosion). The count `N` was fixed in Step 1 before any
verdict was known, so a dropped candidate does not vanish — it leaves a numbered row with no
verdict, which is a visibly incomplete table rather than silence.

The output is the **whole table**, not the findings list. A review with zero findings still
produces a full table; that is a strong, citable result, and it is the shape most reviews never
produce because they never enumerated.

---

## 4. Who runs which step

Split generation from adjudication whenever two agents are already in the loop — typically
Planner authors the document, Critic runs the oracle. The split is not ceremony: the incentive
to suppress a false positive exists only when one entity both raises and rules on candidates.
Hand the numbered list over before verdicts are known and the incentive is gone, because the
generator does not yet know which of its candidates were wrong, and the adjudicator is
disposing of rows it did not author.

With a single agent, §3's fixed denominator carries the same load. Use it; do not skip it
because the same agent is doing both.

The Critic files nothing in the registry directly (`enforcement.md`, Code review / Critic). A
finding amends the document's declaration; a suspected new mechanism opens a taxonomy item for
the QA path.

---

## 5. Step 3 — Disclose the review's own blind spot

State what this run did not cover: passes skipped, budget exhausted, sources unavailable
(S2 is inert in a repo with no registry; S4 is only as good as the corpus searched).

The oracle is subject to the guarantee it enforces. A review that enumerated three candidates
and stopped has a blind spot, and saying so is the same obligation it is checking for.

---

## 6. Threshold

**Unset. `status: pending-corpus`.**

The seed corpus is analysis 041: 24 labelled findings over 4 documents. That establishes the
mode is real and enumerable; it is far too small to calibrate against, and setting a number
from it would be inventing precision.

To set one: grow the corpus to a stated size, run this protocol blind against those documents,
and compute recall (labelled items recovered) and precision (findings that were real). The
threshold is then a floor on both — and it is a claim about this protocol, not about any
document reviewed with it.

Known corpus limitation, carried from 041: every labelled item comes from critiques, which
review *documents*, and documents are inspectable by construction. Whether blind spots in
shipped behaviour are enumerable is untested. Do not quote a recall figure from this corpus as
if it covered that population.

---

## 7. What this oracle does not claim

It does not certify a document complete. No run of it may be reported as having done so.

It reports that a stated protocol, run against a stated corpus, recovers known-missed items at
a measured rate. That rate is the disclosure — the honest, bounded thing that a presence check
on a required field only pretends to be.
