---
project: vs-code-agents
formal_system: none
review_cadence: per plan close
---

# Guarantee Ledger

## Active

| ID | Statement (one falsifiable clause) | Maturity | Scope | FM class | External ref |
| --- | --- | --- | --- | --- | --- |
| G-T-AGENTORD | Every ordered instruction list in agents/\*.agent.md uses each ordinal at most once between explicit restarts at 1. | candidate | project | FM-T-AGENTORD (provisional) | -- |
| G-T-VALPARITY | For every plan document, the PowerShell and Bash plan-template validators emit equivalent normalized findings and exit disposition. | candidate | project | FM-T-VALPARITY (provisional) | -- |
| G-T-SECTIONANCHOR | scripts/validate-plan-template.{ps1,sh} reports a required section as present only when a line matches that section's heading pattern, for every required section, and never on any non-heading line elsewhere in the document. | candidate | project | FM-T-SECTIONANCHOR (provisional) | -- |
| G-T-OPENQENTRY | scripts/validate-plan-template.{ps1,sh} scores an OPENQ id against the entry declaring it in the Open Questions section, resolving it only from a marker within that entry, independent of the entry's table-or-list form, of how many entries share its origin id, and of any mention of that id elsewhere in the document. | candidate | project | FM-T-OPENQGATE (provisional) | -- |
| G-D-BLIND | A plan or design document names every material consideration it leaves unaddressed, where "material" means raised by a named enumeration source available at authoring time. | candidate | project | FM-D-BLIND (provisional) | -- |
| G-D-ASSERTBYPASS | Before stating, in chat or in a plan artifact, any confident claim about system behavior, sufficiency, completeness, or "what's required" that the Planner has not itself verified by citation/tool output/delegation, the Planner runs it through the Stage-0 three-outcome classifier exactly as it would a candidate question; an Outcome-1-shaped claim is never asserted as settled without first spending available Analyst budget to verify it. | candidate | project | FM-D-ASSERTBYPASS (provisional) | -- |
| G-T-SELFLINK | scripts/link_setup.py never relocates or replaces a destination path that resolves to the link source itself. | candidate | project | FM-T-SELFLINK (provisional) | -- |
| G-T-WOSCOPE | scripts/run-work-order-gates.{ps1,sh}' file-scope check flags every modified, created, renamed, or blocked path that is declared in scope.allowed_files or scope.blocked_files, and flags no declared-allowed path, independent of git's display abbreviation, path quoting, the repo-root/workspace-root relationship, or whether the path is gitignored. | candidate | project | FM-T-WOSCOPE (provisional) | -- |
| G-T-DEMODISCONF | scripts/run-work-order-gates.{ps1,sh} exits non-zero for every checklist item with kind: Demonstrated whose disconfirm is null, absent, or empty, in both the PowerShell and bash arms, independent of whether entry_point is populated and independent of whether disconfirm is written as a plain scalar or a block scalar. | candidate | project | FM-T-DEMODISCONF (provisional) | -- |
| G-T-SCRIPTCOMPLETE | Every script under scripts/ that a work-order gate's command field can reference exists in every consumer repo enrolled via link_setup.py's script-linking, independent of when the script was added to the canonical source relative to when the consumer last linked. | candidate | project | FM-T-SCRIPTCOMPLETE (provisional) | -- |
| G-T-CHAINJOIN-A | check-chain-closure assigns a document to a chain only by its uuid, never by filename, path or numeric prefix, and reports rather than resolves every document whose uuid is absent, matched by no plan, or claimed by more than one plan. | candidate | project | FM-T-CHAINJOIN (provisional) | -- |
| G-T-CHAINJOIN-B | Every artifact of a work chain, markdown or YAML, carries that chain's 8-hex uuid. | candidate | project | FM-T-CHAINJOIN (provisional) | -- |

## Superseded

| ID            | Superseded by     | Date       |
| ------------- | ----------------- | ---------- |
| G-T-OPENQGATE | G-T-OPENQENTRY    | 2026-09-19 |
| G-T-DEFERGATE | G-T-SECTIONANCHOR | 2026-09-19 |
