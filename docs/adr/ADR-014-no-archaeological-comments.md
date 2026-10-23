# No-archaeological-comments convention for consumer-facing files

## Status

proposed

## Context

Consumer-facing files in this repository (agents, skills, documentation, scripts, READMEs) accumulated references to this repository's own internal change history: plan numbers ("Plan 015"), plan names, "Historical note" annotations, and "previously / formerly / renamed from / replaced by" commentary that only makes sense relative to a prior state of *this* repo. These references degrade the content: a consumer reading a skill or agent file encounters noise that conveys nothing about how to use the tool, creates a false impression that the documentation is incomplete or transitional, and entangles the timeless spec with an internal development diary.

Separately, the process-history zone (`.agent-output/`) was excluded from version control, making the full audit trail of plans, critiques, QA reports, and implementation docs invisible outside the author's local workspace.

## Decision

**Ban archaeological comments from consumer-facing files** and **publish the process-history zone**.

### The ban

Consumer-facing files — `agents/`, `skills/`, `docs/` (excluding `docs/adr/`), `scripts/`, and root docs (`README.md`, `USING-AGENTS.md`, `AGENTS-DEEP-DIVE.md`, `LINKING.md`, `Makefile`, `plugin.json`) — MUST NOT contain:

- Plan numbers referring to this repository's own change history (e.g., "Plan 015", "per Plan 007")
- Plan names used as internal change references
- "Historical note" annotations
- "renamed from / replaced by / previously called" commentary that describes what a thing *used to be* in this repo, not what it *is*

This content belongs in `CHANGELOG.md` or `.agent-output/`, not in timeless specification prose.

### The exemptions

The following are explicitly **not** banned:

- **`.agent-output/`** — process/history zone by definition; committed as-is.
- **`CHANGELOG.md`** — the designated home for dated, plan-numbered history.
- **`docs/adr/`** — a dated decision record zone; an ADR's Context/Consequences/Amendment sections may retain originating-plan/situation references. Accepted ADRs are not edited in place to remove this context (that would violate the supersession-not-in-place-edit rule from ADR-001). ADR-supersession phrasing ("superseded by ADR-NNN") is always legitimate inside this zone.
- **Functional plan-numbering mechanisms** — the unified `.next-id` numbering machinery in `document-lifecycle` and `structured-labeling`, and plan-ID usage that is a live functional mechanism (not a backward reference), are out of scope.
- **Illustrative examples** — generic examples such as `argument-hint: … (e.g., plan 002)` are illustrative format demonstrations, not self-referential history.
- **Legitimate domain vocabulary** — words like "legacy", "formerly", "no longer" used as *domain content* (e.g., defining a "legacy term" in a metrics rubric; noting a "legacy location, still supported" in a tool description) are not archaeological references. Because these low-precision tokens flip between banned and allowed based on referent, they are owned by human/agent judgment and are not mechanically flagged.
- **Embedded, clearly-delimited history/changelog/provenance sections** — where an otherwise consumer-facing doc contains a dedicated dated-history block or provenance column (e.g., the Decisions Index changelog column in `docs/architecture/system-architecture.md`, or the provenance notes in `docs/VALIDATOR-PARITY-CHECKLIST.md`), that block is exempt in the same spirit as `CHANGELOG.md`. The ban targets commentary woven into timeless spec prose, not dedicated provenance/history blocks.

### Enforcement

A lightweight, cross-platform validator (`scripts/validate-no-archaeology.{ps1,sh}`) checks high-signal patterns case-sensitively:

- `per Plan \d+`
- `\(Plan \d+`
- `Historical note`
- `renamed from`
- `replaced by (ADR|plan) \d+`

The validator skips all exemption zones and supports a path allowlist and inline `<!-- archaeology-ok -->` suppression markers for rare legitimate matches. It is advisory (exit non-zero on findings) and is wired into the `Makefile` as a `check-archaeology` target.

The high-precision patterns were chosen deliberately to avoid matching CON-004 illustrative examples (lowercase `e.g., plan 002`) and CON-005 domain vocabulary (`legacy location`). Low-precision tokens ("no longer", "formerly", "previously") are intentionally excluded from the pattern set because their classification requires referent judgment.

### Publishing the history zone

The `.agent-output/` entry is removed from `.gitignore` and all local contents are committed after a secrets and path-exposure scan (distinguishing benign repo-root paths from contributor home paths, workspaceStorage GUIDs, and absolute session-log paths).

## Considered Options

**Option A — Strip `.agent-output/` of archaeology before committing**: Rejected. The folder is a history zone by design; removing its internal references would destroy its purpose.

**Option B — ADR only, no sweep or validator**: Rejected. Leaves the consumer surface non-compliant with the stated goal of a clean, authoritative present-tense specification.

**Option C — Aggressive regex find-replace across all files**: Rejected. High false-positive rate against domain vocabulary and illustrative examples; the sweep requires human/agent judgment for boundary cases.

## Consequences

### Positive

- Consumer-facing content reads as a clean, authoritative present-tense specification.
- The full process-history audit trail (`.agent-output/`) is versioned and shareable.
- A repeatable validator keeps the convention enforceable going forward.
- The ban/exemption boundary is codified, reducing ambiguity for future contributors.

### Negative

- One-time sweep creates a diff across multiple consumer-facing files.
- The `.agent-output/` commit adds a large number of files to the repository's tracked set.
- The validator is advisory only; enforcement depends on contributors and agents loading `CONTEXT.md`.

### Follow-up

ADR-014 remains `proposed` at initial commit. A follow-up Architect review of the ADR prose is required to advance its status to `accepted`.
