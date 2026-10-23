---
class_id: FM-T-VALPARITY
guarantee: G-T-VALPARITY
status: observed
provisional: true
---

# FM-T-VALPARITY

## Mode: FM-T-VALPARITY.PARSER-DRIFT

**Mechanism.** The Bash and PowerShell plan validators independently parse the same Markdown
structure but use different section-boundary and identity-counting expressions. A Bash parser
that consumes beyond its intended section or counts label occurrences instead of distinct IDs
emits platform-specific false findings that the PowerShell validator does not emit.

**Oracle.** Differential structural oracle: run both real validator CLIs over the shared boundary
fixture corpus and compare normalized findings by severity plus final exit disposition. The oracle
must include nested numbered headings, an out-of-section `REQ-*` sentinel, and a repeated
`GOAL-*` citation.

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | escaped 2026-09-07 (Plan 036 TASK-011 QA) | -- | Bash Requirements extraction runs from the broad Requirements heading to EOF and treats a later historical `REQ-012` citation as an unmapped requirement; PowerShell scopes the section and passes. |
| .002 | observed | escaped 2026-09-07 (Plan 036 TASK-011 QA) | -- | Bash counts three `GOAL-*` occurrences (`GOAL-002`, `GOAL-001`, `GOAL-002`) while PowerShell counts the two distinct IDs, producing a false 3-vs-2 phase warning. |

## Mode: FM-T-VALPARITY.PIPEFAIL-SIGPIPE

**Mechanism.** With Bash `pipefail` enabled, a boolean `echo "$value" | grep -q ...` query can
report failure after `grep -q` successfully exits at its first match because the still-writing
producer receives SIGPIPE. Large plan documents make the false negative intermittent.

**Oracle.** Run the Bash validator repeatedly against a large valid repository plan and require
every run to have the same normalized findings and exit disposition as PowerShell.

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | escaped 2026-09-07 (Plan 036 validator-repair stress gate) | -- | Repeated Bash validation of Plan 036 intermittently reports a present section or label as missing while PowerShell consistently passes. |

## Mode: FM-T-VALPARITY.CARDINALITY-DRIFT

**Mechanism.** PowerShell pipeline cardinality collapses one result to a scalar and zero results to
`$null`; reading `.Count` from those values under strict mode raises a nonterminating exception and
can skip a finding that Bash emits.

**Oracle.** Invoke PowerShell with strict mode against single-item and zero-item boundary fixtures,
require clean stderr, and compare normalized findings plus exit disposition with Bash.

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | escaped 2026-09-07 (Plan 036 validator-repair differential gate) | -- | Under inherited strict mode, `invalid-plan.md` raises `PropertyNotFoundException` while counting OPENQ IDs and omits Bash's one unresolved-OPENQ warning. |
