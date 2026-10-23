# Work-Order as a Structured Planner→Implementer Handoff Artifact

## Status

accepted

## Context

Analysis of 52 mini-retros across two codebases identified five recurring failure patterns in Planner→Implementer delegations:

- **GAP-1 (AC-SWEEP-MISSING)**: Implementer COMPLETE returns that satisfy tests but omit whole classes of acceptance criteria the Planner specified in the plan. The plan-level criteria existed, but no per-delegation encoding forced the Implementer to read and confirm each one.
- **GAP-2 (CODE-HYGIENE)**: Leaked planning-label prefixes in source code, tests, and docstrings. Honor-system reminders proved insufficient; the recurring escape survived multiple retrospectives as a standing top-two failure.
- **GAP-3 (SCOPE-DRIFT)**: Implementer touched files outside the delegated scope — either through well-intentioned fixes or incomplete scope communication in prose delegation messages.
- **GAP-4 (BLOCKER-PREDICTABLE)**: Blocking conditions the Planner could have anticipated (missing credentials, environment setup, out-of-scope dependency) surfaced as inline HARD BLOCK prose mid-session, discarding context and requiring full re-delegation.
- **GAP-5 (DELEGATION-INCOMPLETE)**: Delegation prompts omitted non-obvious runtime environment facts (venv bootstrap, sub-repo topology, canonical test invocation), causing wasted Implementer-side discovery time.

These failures share a root cause: the delegation boundary was informal — carried entirely in prose and honor-system agent instructions with no machine-checkable enforcement. The plan document was authoritative for planning but had no per-delegation, per-phase scoping instrument.

## Decision

Introduce a **work-order** artifact class at `.agent-output/handoffs/<ID>-<role>-phase-NN.yaml`.

A work-order is a YAML file the Planner creates before any qualified delegation and the Implementer reads, executes against, and updates. A gate script (`scripts/run-work-order-gates.ps1/.sh`) reads the file and exits non-zero if scope is violated, a Demonstrated checklist item lacks required fields, a blocker is open, or a gate command uses a non-allowlisted executable.

**Scope of this decision**: The executor role is Implementer-first. The schema, gate script, and authoring obligation are designed to be role-neutral; QA and DevOps are anticipated extensions with the same schema and gate contract. No schema changes are required to extend to those roles.

**Creation threshold**: A work-order is mandatory when the delegation covers two or more tasks OR contains at least one Demonstrated acceptance criterion. Single-task, assertion-only delegations are exempt.

**Blocker communication**: The Implementer writes structured `blockers[]` entries into the work-order YAML (with `status: open`, `description`, and `raised_date`) instead of returning an inline prose HARD BLOCK. The gate script exits non-zero when an open blocker exists, so the Planner re-runs the gate at COMPLETE-acceptance and cannot inadvertently accept a blocked return. This channel applies only to the executor role; all other agents retain the existing prose HARD BLOCK format.

**Command allowlist (typo/mistake guard, not a trust boundary)**: The `gates[*].command` field accepts arbitrary strings from a data file. The gate script enforces a declared allowlist of known-safe command prefixes (`make`, `git`, `grep`, `python`, `pytest`, `pwsh`, `powershell`, `bash`). Any command not matching the allowlist causes the gate script to exit non-zero with an error. **This is not a trust boundary** (Plan 033 `DECISION-001`/`SEC-001`, 2026-09-02, dated amendment below): the check validates only the first token, so an allowlisted prefix followed by `;` still executes arbitrary code, reproduced by direct probe. Work-order authors already hold repo-write access, so anyone able to author a disallowed command could edit these scripts directly instead — the allowlist's actual job is catching a typo or an accidental wrong command, not containing a hostile author.

## Considered Options

**1. YAML work-order vs Markdown checklist** (GAP-1, GAP-2): Markdown checklists in the Implementer doc are human-readable but not machine-parseable. The gate script cannot deterministically verify a Markdown checklist, and label-audit enforcement requires a path list to scope the grep. YAML was chosen because it enables deterministic gate execution with no ambiguity in field presence or value. Markdown's readability advantage is served by the YAML file's structure (human-readable key names, inline comments).

**2. Per-phase files vs per-plan file** (GAP-3): A single per-plan file accumulates checklist items across phases. After phase 1 closes, phase-1 checklist items remain in the file, requiring phase-section parsing to know which items apply to the current delegation. Per-phase files avoid this: each file contains exactly the items for its phase, and a closed phase's file is immutable. Per-phase was chosen.

**3. Planner-creates vs Implementer-creates** (GAP-5): If the Implementer creates the work-order, they transcribe the FILE-_ list and task acceptance criteria from the plan — introducing an additional copy with transcription risk and ILC (interface caller knowledge). The Planner already holds the FILE-_ list and TASK acceptance criteria at delegation time. Planner-creates was chosen: the owner of the knowledge is the author.

**4. YAML `blockers[]` vs prose HARD BLOCK** (GAP-4): An inline prose HARD BLOCK is ephemeral — it lives in one chat turn and is lost when the session continues. A YAML `blockers[]` entry is durable across session turns and machine-checkable: an open blocker causes the gate script to exit non-zero, preventing the Planner from accepting COMPLETE without seeing the block. YAML `blockers[]` was chosen for executor-origin blocks; prose HARD BLOCK is retained for all other agents to minimize scope of change.

## Consequences

### Positive

- Acceptance criteria are machine-enforced at delegation boundary and at COMPLETE acceptance.
- File-scope violations are caught before COMPLETE is accepted, eliminating scope-drift escapes.
- Label-audit enforcement is scoped to the exact files in `scope.allowed_files`, reducing false positives and making the grep anchor precise.
- Predictable blocking conditions are communicated durably through `blockers[]` rather than lost in prose, giving the Planner structured input for re-delegation.
- The mechanism is additive: existing single-task, assertion-only delegations continue under the prior honor-system COMPLETE protocol without change.

### Negative

- Planner acquires a standing pre-delegation authoring obligation for qualified delegations. The work-order file must be created and populated accurately before each phase invocation.
- The `gates[*].command` allowlist is enforced by the gate script, not by the OS or a sandbox. A compromised work-order file with a plausible-looking allowlisted command prefix (e.g., `git` followed by destructive flags) passes the prefix check. **Corrected by dated amendment (2026-09-20, Plan 033 `TASK-012`)**: this is not "a first-level defense" against that scenario with a gap — there is no defense here at all, by design. Work-order authors are trusted at repo-write level by construction (`DECISION-001`); a more constrained execution model would defend against a threat model this repo does not have. The allowlist's actual, durable job is catching an author's typo or wrong-command mistake before it runs, not isolating a hostile input.
- Extension to QA and DevOps roles requires those agents to acquire the executor consumption procedure. The schema and gate script are already role-neutral; only agent instruction updates are needed.

## Related ADRs

- [ADR-020](ADR-020-mechanical-gate-resolution-and-distribution.md): Corrects this ADR's original trust-boundary framing ("first-level defense, not a complete isolation boundary") via a dated Amendment, reframing the command allowlist as a typo/mistake guard, not a security boundary.

## Amendments

**2026-09-20 (Plan 033 `TASK-012`).** Two corrections, both dated in place rather than rewriting history:

1. **Allowlist prefix count.** This ADR previously documented **nine** prefixes including `Select-String`. The implemented allowlist in both `run-work-order-gates.ps1` and `.sh`, and `work-order.schema.yaml`'s own description, have only ever declared **eight**: `make`, `git`, `grep`, `python`, `pytest`, `pwsh`, `powershell`, `bash`. `Select-String` was never one of the allowed prefixes to begin with, and the dead `-Path`-argument extraction fallback that once referenced it in `Test-LabelAudit`/`check_label_audit` (for a `label_audit` gate with no `paths[]` list) has been removed — `paths[]` is now required for every `label_audit` gate, with no command-parsing fallback.
2. **Trust-boundary framing.** See the corrected paragraphs above (Command allowlist; Negative consequences). Plan 033 `DECISION-001`/`SEC-001` established, by direct reproduction, that the allowlist is a typo/mistake guard, not a security boundary — this ADR's original phrasing ("first-level defense... not a complete isolation boundary") implied a boundary-with-a-gap where in fact no boundary is claimed at all.

**2026-09-27 (Plan 056 TASK-027).** Fidelity confirmation: the work-order mechanism this ADR decides is fully implemented and mandatory in practice -- `scripts/run-work-order-gates.ps1`/`.sh` and the active `.agent-output/handoffs/*-phase-NN.yaml` corpus (including this ADR's own 2026-09-20 amendment above, itself evidence of the mechanism being exercised in production) -- matching `system-architecture.md`'s **DD-002** finding that this ADR's Status field lagged behind its actual accepted-and-operating state. `Status: proposed` -> `accepted`.
