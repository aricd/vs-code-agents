# Criterion Ledger — Template

Copy this block into any artifact (plan, analysis, critique, QA doc, or chat response) that presents a scope, selection, filter, or sampling decision.

Keep it short. A ledger that is too long to read is a ledger nobody checks.

---

## Template

```md
## Scope Ledger

### CRIT — the user's criterion, verbatim

CRIT-001 (verbatim, <source: user turn / plan REQ-00X / issue #N>):
"<exact words, copied - not summarized>"

CRIT-001 test:     Include candidate C iff <mechanical, per-candidate test>
CRIT-001 evidence: <what artifact settles it: import, call site, docstring, route table, grep result>
CRIT-001 population: <how the candidate list was produced, and when>

### PROXY — any test that differs from CRIT

PROXY: none
<or>
PROXY-001 (DECLARED, NOT APPLIED - requires user acceptance)
  Proposed test: "<the test I was about to use>"
  Differs from CRIT-001 by: <the concept added or removed>
  Origin: <prior task / prior doc / habit / convenience>
  Would change: <which candidates flip, and how many>

### Verdicts

| Candidate | CRIT-001 result | Evidence (cited) | Verdict | Reason class |
|-----------|-----------------|------------------|---------|--------------|
|           |                 |                  | IN/OUT  |              |

### COST — budget decisions, never folded into the table above

COST: none
<or>
COST-001: <literal scope size> vs <constraint>. Options:
  a) <option> (default) - costs <x>, risks <y>
  b) <option>
  c) <option>

### DRIFT — verdicts resting on anything other than CRIT-001

DRIFT: none
<or>
DRIFT-001: <verdict> rests on <what>, not on CRIT-001. <Action taken.>

### Totals

Population enumerated: <N> (source: <command or method>, run <date>)
IN: <n> | OUT: <n> | IN-but-sampled/deferred: <n> (see COST-001)
```

---

## Field Rules

| Field | Rule |
|-------|------|
| `CRIT-*` | Verbatim only. If it is not in quotation marks and copied exactly, it is not a CRIT. |
| `CRIT-* test` | Must be applicable by someone else without asking you what you meant. |
| `CRIT-* population` | Must name how the list was produced *for this request* (a command, a directory walk, a route dump) and when. |
| `PROXY-*` | Declared before use, never applied until accepted. No response from the user = blocked, not approved. |
| Evidence | `path:line`, quoted docstring, commit SHA, or document ID. Never "by its role" or "obviously". |
| Reason class | One of `EXCL-FAILS-TEST`, `EXCL-UNREACHABLE`, `EXCL-NOT-IN-POPULATION`, `EXCL-USER-DIRECTED`, or a `COST-*` reference. Nothing else. |
| `COST-*` | Sampled and deferred items stay IN the verdict table with a `COST-*` reference. They are never moved to OUT. |
| `DRIFT-*` | Written before the conclusion, not after the user objects. |

---

## Minimal Inline Form

For small decisions, a one-line form is acceptable and still satisfies the skill:

```md
CRIT-001 "every handler that writes to the audit log" -> tested by: grep for `audit.write(` call sites
(14 handlers enumerated via `rg -l 'audit\.write\('`; 14 IN, 0 OUT; PROXY none; DRIFT none)
```

The obligation is not the table — it is the **verbatim criterion, the mechanical test, the enumerated population, and cited verdicts**. Use whichever form carries those four things.
