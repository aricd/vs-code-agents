---
class_id: FM-T-DEMODISCONF
guarantee: G-T-DEMODISCONF
status: observed
provisional: true
---

# FM-T-DEMODISCONF

## Mode: FM-T-DEMODISCONF.NULL-DISCONFIRM

**Mechanism.** `work-order.schema.yaml` (L101, L109-112) and `docs/adr/ADR-004-work-order-handoff-artifact.md` (L36-37) both require `disconfirm` for every `kind: Demonstrated` checklist item, and Plan 024 `REQ-004` states the gate script "MUST exit non-zero if ... missing `entry_point`/`disconfirm`" — but until Plan 033's `TASK-039`/`REQ-028` landed, neither `run-work-order-gates.ps1` nor `.sh` parsed the `disconfirm` key at all. The field a Demonstrated item's own schema and an accepted ADR both call load-bearing — the mechanism that is supposed to "distinguish a real demonstration from a tautological assertion" — was structurally incapable of failing the check, regardless of its content, because the check did not exist. A checklist item's `disconfirm: null`, `disconfirm: ""`, or an entirely absent `disconfirm:` key all passed identically to a genuine, well-formed disconfirmation rule.

**Why this is a missing-test defect, not a tautological-test defect.** Plan 024's own test set for `REQ-004` is `TEST-001..004, 006, 007, 008`; `TEST-006` covers `entry_point` only. There was never a test asserting the gate rejects a missing `disconfirm` — the requirement was ratified with a gap in its own oracle coverage, not with an oracle that merely failed to catch a real case.

**Oracle.** `scripts/test-property-oracle.ps1`'s `G-T-DEMODISCONF` property check: a generative check composing checklist items over the cartesian space of `kind` (`Asserted`/`Demonstrated`) x `disconfirm` representation (null, absent key, empty string, `~`, plain scalar, `>` folded block scalar, `|` literal block scalar, `>-` chomped block scalar) x arm (`.ps1`/`.sh`), asserting the gate exits non-zero iff `kind == Demonstrated` AND the representation is empty-equivalent, independent of `entry_point` (always populated, so every case isolates the `disconfirm` rule specifically). This is a property oracle per `requirements-enforcement`'s bar, not the fixture set alone (`TEST-019`..`TEST-023` are supporting fixtures; `TEST-025` is the sole discharger of `G-T-DEMODISCONF` as a guarantee).

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | Plan 037 (root-cause-first-policy-hardening), folded into Plan 033 by `DECISION-006`, 2026-09-08 | ADR-004 L36-37, work-order.schema.yaml L101/L109-112 | Real: any of the 23 committed work-orders under `.agent-output/handoffs/` with a `kind: Demonstrated` item carrying `disconfirm: null` or an absent `disconfirm` key passed `run-work-order-gates.ps1`/`.sh` before `REQ-028`/`REQ-029` landed. `033-phase-0-analyst.yaml` `AC-004` was the one such item in this repo's own corpus at measurement time (remediated by `TASK-041` before this fix shipped, per `BACKCOMPAT-005`). Synthetic (isolates the mechanism directly): `scripts/test-fixtures/invalid-work-order-missing-disconfirm.yaml` (explicit null), `invalid-work-order-absent-disconfirm.yaml` (no key at all), and `invalid-work-order-empty-disconfirm.yaml` (empty string) each passed the pre-fix script (`git show HEAD:scripts/run-work-order-gates.ps1`, run against the fixture) with exit 0 and no mention of `disconfirm` anywhere in the output — confirmed red-then-green by `scripts/test-run-work-order-gates.ps1`'s red-against-pre-fix cases. |
