---
class_id: FM-T-CHAINJOIN
guarantee: G-T-CHAINJOIN-A, G-T-CHAINJOIN-B
status: observed
---

# FM-T-CHAINJOIN

Minted by plan 039 (chain-identity-and-closure). A chain-scoped operation resolves the wrong document set -- because the join key is absent (a YAML artifact predating this plan's `uuid` backfill), ambiguous (a numeric prefix spanning several chains), or wrong (a mis-verified backfill, or a document whose `UUID` frontmatter was inherited from the wrong plan at authoring time). Split into two guarantees at minting (see `G-T-CHAINJOIN-A` below) rather than the single conjoined guarantee an earlier draft of this plan proposed, because the corpus already violates the second half on day one -- a single guarantee covering both would have entered the ledger ratified-false.

`G-T-CHAINJOIN-A` (the join behaviour): `scripts/check-chain-closure.{ps1,sh}` assigns a document to a chain only by its `uuid`, never by filename, path, or numeric prefix, and reports -- rather than resolves -- every document whose `uuid` is absent, matched by no plan, or claimed by more than one plan. This is a fact the script can guarantee about itself.

`G-T-CHAINJOIN-B` (the corpus property): every artifact of a work chain, markdown or YAML, carries that chain's 8-hex `uuid`. This is an aspiration the corpus moves toward, not a fact it currently holds -- instance `.002` below is a known, live violation.

## Mode: FM-T-CHAINJOIN.PREFIX-COLLISION

**Mechanism.** A chain-scoped operation that resolves membership from a numeric filename prefix (e.g. `27-*`, `027-*`) rather than the frontmatter/YAML `uuid` silently fuses every chain sharing that prefix into one set. In this corpus, prefix `27` spans three genuinely distinct chains; an operation keyed on the prefix would act on 18 documents when at most 7 (or as few as 1) actually belong to the chain intended.

**Oracle.** `TEST-002` (property test) -- for every numeric prefix in the corpus, the set of documents `scripts/check-chain-closure.{ps1,sh} -Report` assigns to each chain must equal the set sharing that chain's `uuid`, and no document may be assigned by a filename or path match. `TEST-002b` pins the prefix-27 case by name as a named regression under that property.

**Instances.**

| ID | Status | Discovered | Repro |
| --- | --- | --- | --- |
| .001 | observed | 2026-09-08 (plan 039 authoring, `FINDING-001`); re-measured 2026-09-30 (plan 039 implementation, this repo) | Numeric prefix `27` resolves to 18 documents (both original 2026-09-08 count and the 2026-09-30 re-measurement agree) spanning **three** distinct chains: `4b7e1c9a` (live-access-and-citation-fidelity-ask-mechanisms, 9 docs), `a3f7c210` (ban-archaeological-comments, 7 docs), `7c1d4e9a` (inherited-openq-stage0-retriage, 2 docs). Measured 2026-09-30 by running `scripts/check-chain-closure.ps1 -Report -Uuid <each>` and confirming the three sets partition the 18 documents with zero overlap and zero omission -- literal output recorded in `.agent-output/implementation/039-chain-identity-and-closure-implementation.md`. Any prefix-keyed chain operation over prefix 27 would act on a set 2-3x too large and internally unrelated. |

## Mode: FM-T-CHAINJOIN.MISINHERITED-UUID

**Mechanism.** A document's `UUID` frontmatter is copied from the wrong sibling at authoring time (a copy-paste error, or a satellite generated from a template that still carried a prior chain's identity). The document's filename stem still names the correct plan, but its `uuid` field does not match that plan's `uuid` -- so a join-on-uuid-only script correctly refuses to adopt it into that plan's chain (per `G-T-CHAINJOIN-A`), and without a distinct report rule it would sit permanently unjoined to ANY chain.

**Oracle.** `scripts/check-chain-closure.{ps1,sh}`'s rule 3 (suspected mis-inheritance): a document whose `uuid` matches no plan but whose filename stem matches a plan's stem is reported distinctly, naming the probable plan, and is never silently adopted.

**Instances.**

| ID | Status | Discovered | Repro |
| --- | --- | --- | --- |
| .002 | observed, unrepaired (`DEFER-039-7`) | 2026-09-08 (plan 039 authoring, `FINDING-002`); re-verified 2026-09-30 (plan 039 implementation) | `.agent-output/architecture/030-executive-summary-deferred-items-architecture-findings.md` carries `UUID: d47ac9e3`, while its own plan (`030-executive-summary-deferred-items-plan.md`) and all six other chain-030 satellites carry `b7e21f0a`. Re-verified 2026-09-30 by running `scripts/check-chain-closure.ps1 -Report` (full-corpus audit mode): the document is reported under rule 3, naming plan stem `030-executive-summary-deferred-items-plan` (uuid `b7e21f0a`) as the probable owner -- literal output recorded in the implementation doc. Repair is out of scope for plan 039 (`CON-001` forbids frontmatter edits; chain 030 is `Status: Committed`) and is deliberately left open as the live instance that keeps `G-T-CHAINJOIN-B` at `candidate` maturity rather than promoted. |
