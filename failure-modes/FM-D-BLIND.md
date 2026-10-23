---
class_id: FM-D-BLIND
guarantee: G-D-BLIND
status: observed
provisional: true
---

# FM-D-BLIND

## Mode: FM-D-BLIND.UNENUM

**Mechanism.** A design or plan document omits a consideration that a named enumeration source (ledger, failure-mode registry, owning template/skill rule, prior in-repo precedent, or the document's own internal consistency) would have raised at authoring time, and does not name the omission as out of scope. The omission has no site in the artifact to point at, so it is undetectable by inspection and is found only by re-deriving the candidate set independently and diffing against what the document claims.

**Oracle.** `A-001` \* measured (adjudicated) -- **pending-corpus**. Procedure: `failure-modes/oracles/A-001-blind-spot-enumeration.md` v1. Enumerates candidates from named sources (S2 registry adjacency, S4 prior precedent, S5 document-internal consistency required; S3 cost-axis declines optional, measured yield 1 of 24) **before** reading the document's own disclosure, then records every candidate with a verdict of undisclosed / disclosed-elsewhere / inapplicable. Corpus: `.agent-output/analysis/041-blind-spot-enumerability-probe.md`, 24 labelled findings over 4 documents. Threshold deliberately unset -- that corpus establishes the mode is real and enumerable, and is far too small to calibrate recall/precision against. Source S6 (template-required field left unfilled) is **out of scope**: probe §3 measured it at 10 of 24 and mechanically checkable, so it belongs to a structural gate (plan 042) rather than to an agent's judgment. Last revalidated against G-D-BLIND wording: 2026-09-16.

**Instances.** Cross-repo: all four discovered in `ExampleService`, which consumes this repo's skills. All four are `induced` (caught pre-merge by Critic review), not `escaped` -- the existing SRH review pass is catching this class today. The gap this mode records is therefore **not** that nothing catches these; it is that the pass has no fixed denominator, no recorded candidate set, and no false-positive record, so its detection rate is unmeasurable and its consistency undefended.

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | induced (critique 123 H-1) 2026-09-16 | -- | Contingent "if vulnerable" branch reachable with all staged tasks passing and no gate on completion; S5 |
| .002 | observed | induced (critique 149 H-1) 2026-09-16 | -- | `Architect_Approved: true` + "re-confirmed clean" contradicted by the cited review's own final verdict; S5 |
| .003 | observed | induced (critiques 205 L-1, 123 M-1) 2026-09-16 | -- | FM Exposure survey omits a mechanically adjacent registry class; S2 |
| .004 | observed | induced (critiques 061, 072, 074, 094, 123 M-5, 205 M-1) 2026-09-16 | -- | Required `Lens applicability` declaration absent from `ALT-*`; same finding 6x -- coverage gap, see probe §4; S4/S6 |

Full labelled corpus and the pre-registered labelling rule: `.agent-output/analysis/041-blind-spot-enumerability-probe.md`.
