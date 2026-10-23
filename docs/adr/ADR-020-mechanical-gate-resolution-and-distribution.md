# Mechanical Gate Resolution and Distribution

## Status

accepted

## Context

Plan 033 (`verification-discipline-hardening`) Phase 1 hardens `run-work-order-gates.{ps1,sh}` so it correctly enforces declared scope (untracked creations, blocked paths, git's display abbreviation/quoting, a stable `base_commit` anchor) instead of the defects `FOLD-01` traced across four consuming plans. A correct gate script is only a marquee value (`REQ-004`/`TEST-010`) if it is actually **resolvable** from wherever a delegation runs it — the plan's own `execution-orchestration` skill previously named the script by a bare relative path with no stated fallback for a consuming workspace where that path does not exist.

Two related but separable concerns follow from this:

1. **Resolution.** Where does an executor find the gate script when the workspace it is operating in is not this repo?
2. **Distribution.** How does the gate script (and this repo's skills/agents/prompts) get INTO a consuming workspace in the first place, so resolution has something to find?

This ADR's decision is the resolution contract; distribution (via `scripts/link_setup.py` and `LINKING.md`) is a necessary consequence of making resolution meaningful, not a separate decision this ADR re-litigates — `link_setup.py`'s own design (junction-vs-symlink strategy, drift refusal, the `INCIDENT-001` already-linked-ancestor guard) is reviewed under Plan 033 `TASK-010` and documented in `LINKING.md`.

## Decision

**Gate-resolution contract (`CONTRACT-001`).** Before running the work-order gate script, an executor (or the orchestrating owner, at COMPLETE-acceptance) resolves it in this order, stopping at the first hit:

1. **Workspace `scripts/`** — `scripts/run-work-order-gates.ps1` (or `.sh`) inside the current workspace root.
2. **Linked `scripts/`** — the same file reached through this repo's distribution mechanism (`link_setup.py` / `LINKING.md`), when the current workspace is a consumer with `link_scripts: true`.
3. **`blockers[]` HARD BLOCK** — if neither location resolves, the gate is **unresolvable**. This is itself a blocking condition, not a reason to skip validation: the executor writes a `blockers[]` entry with `status: open` naming the unresolved gate and does not declare COMPLETE.

There is **no fourth, manual-substitution step**. An earlier draft of this plan's Phase 1 contemplated an "Unresolvable-Gate Fallback" procedure (reasoning about scope by hand when the script cannot be found) — that draft was rejected during Critic review (`H-10`) as institutionalising the exact tolerance that let `FOLD-01` survive four plans undetected. A missing gate script is escalated to the owner via `blockers[]`, never worked around.

**Waiver is the only route past an unresolved or otherwise unsatisfied criterion** (`REQ-005`): `status: waived` requires owner sign-off recorded in the work-order AND non-null `evidence` describing what was done instead. A `waived` item with `evidence: null` is invalid — it would record that a check was skipped and say nothing about what replaced it.

**Distribution, as a consequence.** For resolution step 2 to ever succeed, this repo's `scripts/` (along with `skills/`, `agents/`, `prompts/`) must already be linked into the consuming workspace or its home directory. `scripts/link_setup.py` is the canonical mechanism (per-item symlink on POSIX, per-item NTFS junction on Windows); `link-setup.ps1`/`.sh` are thin shims with no logic of their own. `link_scripts` defaults to `false` on every target — unlike skills/agents/prompts, it distributes **executable** content, and enabling it is what makes resolution step 2 possible for a given consumer. Enabling `link_scripts: true` for a real target, and running the gate against a real scope violation there (`TEST-SCOPE-003`/`TEST-010`), is **gated on this ADR's acceptance** and is explicitly out of scope for the work that drafts it — see the Consequences section below.

## Trust surface (`DECISION-001` / `SEC-001`, stated verbatim)

The gate script's command allowlist (`gates[*].command`, checked against `make`, `git`, `grep`, `python`, `pytest`, `pwsh`, `powershell`, `bash`) is a **typo/mistake guard, not a trust boundary**: `Test-CommandAllowlist` validates only the first token of the command string, and the full string is then executed via `Invoke-Expression` (`.ps1`) or `eval` (`.sh`) — so any allowlisted prefix followed by `;` executes arbitrary code. This was reproduced directly:

```
command: "git --version; Set-Content -Path C1-PAYLOAD-RAN.txt -Value pwned"
  -> PASS: work-order gates all passed.   exit 0   payload file created
```

**Disposition (user, 2026-09-02):** _"Trust here has been established and we are not doing anything to change that. Note this and let's move on."_ Work-order authors already hold repo-write access; a party able to author a `gates[*].command` string could edit these scripts directly instead. The allowlist's actual, durable job is catching an author's typo or wrong command before it runs — not containing a hostile author. This plan neither relies on the allowlist as a security control nor changes it, and does not describe it as a boundary anywhere it touches. `ADR-004`'s original phrasing ("a first-level defense, not a complete isolation boundary") implied a boundary-with-a-gap where none is claimed; that ADR is corrected by a dated amendment in the same work that drafts this one.

This posture extends unchanged to `REQ-028`'s `disconfirm`-presence check (`SEC-003`): it is data validation on a trusted-author artifact, not a trust boundary, and the parser never evaluates, expands, or executes `disconfirm` content — the only machine predicate applied to it is non-emptiness.

## Considered Options

**1. A fourth, manual-substitution fallback when the gate is unresolvable, vs. `blockers[]` HARD BLOCK only.** Rejected (Critic `H-10`): a documented "reason about scope by hand" procedure is precisely the tolerance this plan exists to close. Escalating via `blockers[]` keeps the mechanical guarantee mechanical — either the real script runs, or nothing is declared COMPLETE.

**2. Directory-level linking (one link for the whole `scripts/` tree) vs. per-item linking.** Per-item was kept for `scripts/`, consistent with `skills/`/`agents/`/`prompts/`, so a target can keep sibling content (an `old/` archive) alongside the linked items without a directory-level link forcing an all-or-nothing choice. `~/.agents/skills` is a documented exception (a single whole-directory link, made by hand, per `LINKING.md`) precisely because nothing else needs to live alongside it there — `scripts/` targets do not share that property in general.

**3. Enabling `link_scripts: true` inside this same ADR's acceptance vs. gating it behind a separate, later step.** Gated separately. `link_scripts` distributes executable content; per `TEST-SCOPE-003`'s own stated precondition, the integration test that exercises a live scope violation in a consuming workspace (`TEST-010`) cannot run until both this ADR is accepted AND a real target sets `link_scripts: true`. Folding that into this ADR's own acceptance would let a single sign-off simultaneously bless the resolution contract and enable untested executable distribution in one motion; keeping them separate lets the Architect accept the contract now and defer the distribution flip to whichever target actually needs it.

## Consequences

### Positive

- The gate script's resolution behaviour is a stated contract instead of an implicit assumption, closing the gap `REQ-004` names as this plan's marquee value.
- A missing gate script produces a durable, auditable block (`blockers[]`) instead of a silent workaround or a lost prose HARD BLOCK.
- Distribution and resolution are decoupled: a consumer that only needs skills/agents/prompts is never forced to also receive executable scripts.

### Negative

- `link_scripts: true` is a genuine escalation in trust for a target (it distributes executable content into a workspace this repo does not own); enabling it is a per-target decision an operator must make deliberately, not a default.
- Until a real target enables `link_scripts` and the ADR is accepted, `TEST-SCOPE-003`/`TEST-010` — and therefore `REQ-004` — remain undischarged. This is the intended reading, not a loophole: the plan is not complete while that test has not actually run.

## Related ADRs

- [ADR-004](ADR-004-work-order-handoff-artifact.md): This ADR's Trust surface section corrects ADR-004's original trust-boundary framing via a dated Amendment (Plan 033 `TASK-012`), reframing the command allowlist as a typo/mistake guard, not a security boundary.

## Changelog

| Date       | Summary               | Reference |
| ---------- | --------------------- | --------- |
| 2026-09-20 | Accepted by Architect | Plan 033  |
