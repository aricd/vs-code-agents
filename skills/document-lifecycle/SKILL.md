---
name: document-lifecycle
description: Unified document lifecycle management. Defines terminal statuses, unified numbering via .next-id, close procedures, and orphan detection. Also owns the Agent Team Protocol (status tracking, lifecycle load, structured-labeling load). Load at session start, or when an agent needs the team protocol reference.
metadata:
  version: "1.1"
---

# Document Lifecycle Skill

Manages document state transitions, unified numbering, and automated closure across all agent-output directories.

---

## Core Principle

Every work chain shares a single ID. When Analyst creates analysis 080, the downstream plan, implementation, QA, UAT, and critique all use ID 080. This enables human traceability across the entire lifecycle.

Documents in terminal status belong in `closed/` subfolders. Active work stays visible; completed work is archived but accessible.

---

## Template/Labels Compliance (MANDATORY)

All documents in `.agent-output/` MUST follow the structured labeling conventions defined in the `structured-labeling` skill:

1. **Label Usage**: Use applicable label prefixes (REQ-*, TASK-*, FILE-*, etc.) per the skill's domain mapping
2. **Status Values**: Use only the canonical status enum (not-started, in-progress, complete, blocked, deferred)
3. **Section Ordering**: Plans MUST follow the rigid 17-section template; other artifacts follow their domain-specific templates
4. **Consistency**: Labels and statuses must be consistent across related documents in a work chain

Load `structured-labeling` skill for complete prefix definitions, numbering rules, and agent-to-label mappings.

This compliance requirement does NOT change the ID/Origin/UUID/Status protocol--those remain as documented below.

---

## Terminal Statuses

These statuses trigger document closure (move to `closed/`):

| Status | Meaning | Closed By |
|--------|---------|-----------|
| `Committed` | Changes committed to git (awaiting release) | DevOps |
| `Released` | Successfully pushed/published | DevOps |
| `Abandoned` | Explicitly dropped, will not proceed | User (manual) |
| `Deferred` | Postponed indefinitely | User (manual) |
| `Superseded` | Replaced by a newer document | User (manual) |
| `Resolved` | All findings addressed (critiques only) | Critic |

### Two-Signal Completion Rule

Any "is X done" determination -- including a transition into one of the terminal statuses above
-- MUST check two signals with independent failure modes: a declared status field (e.g. `status:
complete`, `Critic_Approved: true`) AND a mechanical artifact check (e.g. a gate script's exit
code, a grep against the file the status claims describes). A single signal is not sufficient
even when it looks conclusive, because a declared field and the mechanism that sets it can share
the same scoping error and still agree with each other.

**In-repo instances this rule exists to prevent** (per `structured-labeling`'s Grounding Rule,
each is recorded with the command and result that grounds it, where discussed):

1. `FM-T-OPENQGATE` -- a validator gate returned a false PASS from a single collapsing signal:
   zero OPENQ warnings emitted, read as "mechanism working" without a second, independent check.
2. The Critic's own rev-0 review of Plan 033 recorded "zero registered modes" as CONFIRMED having
   read only `failure-modes/INDEX.md`, without a second check listing `failure-modes/` itself --
   the two-signal failure committed by the reviewer while reviewing the two-signal requirement.
3. Plan 033's own `Critic_Approved: true` frontmatter field was set from the substantive verdict
   before a confirmation pass existed to check it against a second, independent signal.

Authoring obligation: `execution-orchestration` §Owner pre-delegation steps. Review-time check:
`code-review`'s Critic Plan Completeness table.

---

## Evergreen Document Carve-Outs

The following document types are **evergreen** -- they are NEVER moved to `closed/` and have special lifecycle rules:

### Architecture Docs (`docs/architecture/`)
- `system-architecture.md` and diagrams are continuously updated as the source of truth
- Never reach a terminal status; never moved to `closed/`

### ADRs (`docs/adr/ADR-NNN-*.md`)
- ADRs are evergreen decision records -- they remain in place permanently
- Superseded ADRs get `Status: superseded by ADR-NNN` but stay in `docs/adr/` (NOT moved to `closed/`)
- **ADR numbering is INDEPENDENT of `.agent-output/.next-id`** -- ADRs use their own number space
- See `adr-authoring` skill for the canonical numbering rule (scan `docs/adr/`, max + 1, 3-digit format)

### Root `CONTEXT.md`
- The domain glossary at repo root is evergreen and Architect-owned
- Never reaches a terminal status; never moved to `closed/`
- Updated inline during alignment sessions and by Architect as domain terminology evolves

---

## Unified Numbering Protocol

### The `.next-id` File

Location: `.agent-output/.next-id`

Contents: Single integer (e.g., `081`)

**Rules:**
- Only **originating agents** (Analyst, Planner when no analysis) read and increment
- Downstream agents **inherit** the ID from their source document
- Never skip numbers; always use the next available

### Document Header Format

Every document in `.agent-output/` MUST include:

```yaml
---
ID: 080                    # Global sequence number
Origin: 080                # Chain origin (same as ID for originating docs)
UUID: a3f7c2b1             # 8-char random hex for collision-proofing
Status: Active             # Current lifecycle state
Created: 2026-09-10T07:49:30-06:00   # When this document was created
Corrected-By: 095          # OPTIONAL. ID of a later document that supersedes/amends this one's content
---
```

#### `Created` — stamp it, never type it

`Created` is an **ISO-8601 timestamp with an explicit UTC offset** (or `Z`). A bare date is not
enough, and a local time without an offset is worse than a date — it is ambiguous while looking
precise, and consumers sort on this field.

**Obtain the value by running a clock. Do not compose it.**

```powershell
Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"    # PowerShell
```
```bash
date +%Y-%m-%dT%H:%M:%S%:z                    # bash
```

You do not know the time of day. Asked for one, you will produce a plausible string — typically a
round hour — and it will be wrong. Run the command and paste the result.

**`Created` is immutable.** It records authorship, not modification. Never update it when editing a
document: revisions belong in the Changelog, and execution-states carry `updated_at`. It survives
renames — a `git mv` does not reset it.

**Derived values are marked.** If a timestamp was reconstructed rather than observed (backfilled, or
widened from a date-only field), add `Created_Derived: true` alongside it, and `Created_Derived_Source`
naming how it was obtained. An unmarked whole-hour timestamp is rejected by `check-created-coverage`,
because that is the shape of an invented one.

**Enforcement is per-project.** `.agent-output/policy.yaml` sets the date from which this is required.
Artifacts predating a project's adoption date are reported, never failed — adding a convention does not
invalidate a repository's history. A malformed value is an error regardless of date.

### Correction Propagation

A correction to a closed or in-flight document MUST reach the document it corrects — not just live
in the correcting document's own text. Use one of two mechanisms:

1. **Dated in-place amendment.** Edit the original document directly, adding a short dated note (e.g.
   `**Correction (2026-09-20, Plan 033 TASK-013).** ...`) that states what was wrong and what replaces
   it, immediately adjacent to the corrected content. Preferred when the original is still actively read
   and the correction is small.
2. **`Corrected-By:` frontmatter pointer.** Add `Corrected-By: <ID>` to the original document's header,
   naming the later document that supersedes or amends its content. Preferred when the original is
   closed/frozen (e.g. a `BACKCOMPAT-004`-style frozen record) and should not be rewritten in place, or
   when the correction is large enough that inlining it would bury the original.

Either mechanism satisfies this rule; a correction that exists only in a *different* document with no
pointer or in-place note back to the original does not — a reader of the original has no way to
discover it was corrected.

### YAML Chain Artifacts

A YAML chain artifact (execution-state, work-order) inherits chain identity on the same terms as a
markdown document's `ID`/`Origin`/`UUID` above -- it carries the chain's `uuid`, inherited verbatim
from the originating plan's frontmatter. The field definition, the join-key rule, and the
newly-authored-only scope of the identifier-normalization declaration are owned by
`skills/execution-orchestration/references/execution-state.schema.md` and `work-order.schema.yaml`;
this is a pointer to that single owning statement, not a second rule.

### ID Assignment Rules

| Scenario | Action |
|----------|--------|
| Analyst starts new investigation (standalone) | Read `.next-id`, increment, use as ID, write back |
| Planner creates plan from analysis | Inherit ID/Origin from analysis doc |
| Planner creates plan from user request (no analysis) | Read `.next-id`, increment, use as ID, write back |
| Implementer/QA/UAT/Critic work on plan | Inherit ID/Origin from plan doc |
| **Any agent invoked as a delegate within an existing session/chain** (brainstorming analysts/critics/synthesizers, Planner-delegated Analysts, etc.) | **Inherit ID/Origin/UUID supplied by the orchestrator at initialization; never read or increment `.next-id`; write to the exact filename the orchestrator supplied** |

### Orchestrated sessions (parallel delegates)

A multi-delegate session (e.g., a `brainstorming` session) is **one work chain**: the
orchestrator allocates one ID (read `.next-id`, increment, write back -- exactly once, at
session start), mints one 8-char UUID, and supplies three things to every delegate at
creation/initialization: the shared `ID`/`Origin`/`UUID`, and a **distinct output filename**.
Delegates use all of them verbatim.

Rationale: parallel delegates racing `.next-id` produce duplicate IDs and lost increments, and
per-delegate allocation scatters one session across many chain IDs. The shared ID keeps the
chain traceable; the orchestrator-assigned filename is what prevents collisions between
same-ID artifacts. Recommended scheme: `NNN-<session-slug>-<round|tier>-<role><seat>.md`
(e.g., `081-obs-facade-t0-analyst-3.md`).

---

## Close Procedure

When a document reaches terminal status:

1. **Update Status field** to the terminal status
2. **Add changelog entry**: `| YYYY-MM-DD | [Agent] | Document closed | Status: [status] |`
3. **Create closed folder** if needed: `mkdir -p .agent-output/<domain>/closed/`
4. **Move file**: `mv .agent-output/<domain>/NNN-name.md .agent-output/<domain>/closed/`
5. **Log action**: "Closed document NNN-name.md (Status: [status])"

### Cross-Reference Handling

When referencing a closed document from another document, use relative paths:
- From active doc: `../closed/080-feature.md`
- From closed doc to closed doc: `./080-feature.md` (same folder)

---

## Orphan Detection

### Agent Self-Check (At Session Start and At Citation Time)

**At session start**, before starting work, each agent MUST:

1. Scan their exclusive domain (e.g., `.agent-output/qa/`) excluding `closed/`
2. Identify any document with terminal Status
3. Move orphaned documents to `closed/`
4. Log: "Found orphaned document [name] with Status [status], moved to closed/"
5. **Consult the recurrence register.** Before treating a process/infra defect as new, check
   `failure-modes/INDEX.md` for a matching row. A match means **append**: increment that row's
   `recurrence_count` and update `last_seen` to today's date rather than filing a fresh finding
   (see `failure-modes/INDEX.md`'s own header for the column contract). No match means it is
   genuinely new and follows the normal failure-mode intake path.

**At citation time**, before citing or relying on another document's `OPENQ-<id>-<n>` entry or a
hedge-qualified finding (see `structured-labeling`'s Citation Fidelity Rule), each agent MUST:

1. Compute the origin document's age: today's date minus that document's own Changelog creation
   date (its earliest changelog entry, not today's edit)
2. If the origin document is more than 5 days old, the citing text MUST carry an explicit
   `[STALE -- Nd]` annotation (e.g., `[STALE -- 7d]`) immediately adjacent to the citation,
   instead of silent restatement
3. `[STALE -- Nd]` extends the existing `[RESOLVED]`/`[CLOSED]` annotation syntax; it does not by
   itself resolve or invalidate the cited finding -- it flags that a fresher read may be warranted

### Roadmap Periodic Sweep

Roadmap agent performs comprehensive sweep when reviewing roadmap, covering three distinct
procedures:

#### Orphan Sweep

1. Scan ALL `.agent-output/*/` directories (excluding `closed/`)
2. Flag documents with terminal Status not in `closed/`
3. Report to user
4. Move to respective `closed/` folders

#### OPENQ Staleness Sweep

1. Grep the corpus for `OPENQ-<id>-<n>` entries lacking a `[RESOLVED]`/`[CLOSED]` marker
2. Report the count and the oldest age found (using each entry's origin document's Changelog
   creation date, per the Agent Self-Check's age computation above)
3. Any such entry whose origin chain is touched by the next Executive Summary/Open-Questions
   section, and whose age exceeds 10 days, becomes mandatory `BLOCKING` in that section (see
   `structured-labeling`'s Age-Triggered Mandatory Escalation rule) -- this is the same 10-day
   threshold that rule reuses

#### Citation Fan-Out Tracking

1. Track the citation count per distinct finding ID (an `OPENQ-<id>-<n>` entry or any other
   citable finding) across the corpus
2. Once a finding ID has been cited more than 4 times, the 5th and every subsequent citation MUST
   include an explicit "re-verified at source" note -- the citing agent re-read the origin
   document directly -- before it may cite that finding again
3. Report any finding ID approaching or past the 4-citation threshold without a re-verification
   note on its most recent citation

---

## Agent Responsibilities

| Agent | Role | Closure Trigger |
|-------|------|-----------------|
| Analyst | Originate IDs | Planner closes when plan created |
| Planner | Originate or inherit | DevOps closes after commit |
| Implementer | Inherit | DevOps closes after commit |
| QA | Inherit | DevOps closes after commit |
| UAT | Inherit | DevOps closes after commit |
| Critic | Inherit | Self-closes when findings resolved |
| DevOps | N/A | Self-closes after release |
| PI | N/A | Self-closes own analysis |
| Architect | N/A | Evergreen docs, no closure |
| Roadmap | N/A | Orphan sweep responsibility |
| Security | Inherit | Self-check only |

---

## Quick Reference

### Creating a New Document (Originating)

```bash
# Read current ID
NEXT_ID=$(cat .agent-output/.next-id)
# Increment for next use
echo $((NEXT_ID + 1)) > .agent-output/.next-id
# Use $NEXT_ID as your document ID
```

### Closing a Document

```bash
# Update Status in document header to terminal status
# Add changelog entry
mkdir -p .agent-output/<domain>/closed/
mv .agent-output/<domain>/NNN-name.md .agent-output/<domain>/closed/
```

### Self-Check Pattern

```
Before starting work:
1. List .agent-output/<my-domain>/*.md (excluding closed/)
2. For each file, check Status field
3. If Status in [Committed, Released, Abandoned, Deferred, Superseded, Resolved]:
   -> Move to closed/
```

---

## Agent Team Protocol

**This section is the single owning definition for the shared agent protocol trio.**

Every agent in the workflow follows these three obligations. They are defined here once; each `.agent.md` references them with the CONTRACT-002 one-liner:

> `Team protocol: per document-lifecycle skill (status tracking, lifecycle, labeling loads).`

### 1. Status Tracking (MANDATORY)

Agents MUST keep their owned artifact's Status field current throughout the workflow. Other agents and users rely on accurate status at a glance. Update the Status field and add a changelog entry at every meaningful state transition (e.g., Active → In Progress → Committed). Agents that update plan Status fields (Implementer, Code Reviewer, QA, UAT, DevOps) must add a changelog entry in the plan document when doing so.

### 2. Document Lifecycle Load (MANDATORY)

Load this skill (`document-lifecycle`) at session start. Follow the ID inheritance/origination rules, close procedure, and orphan detection protocol defined above. Each agent's `.agent.md` specifies its role (originating or inheriting), owned domain, and closure trigger — those are the only agent-specific additions needed.

### 3. Structured-Labeling Load (MANDATORY)

Load the `structured-labeling` skill for the authoritative label prefix definitions (REQ-*, TASK-*, SEC-*, CON-*, FILE-*, etc.), plan template section ordering (17 sections), numbering rules, status enum, and frontmatter schema. Each agent uses the label subsets relevant to its role; the skill description is the single trigger owner for "when to load".
