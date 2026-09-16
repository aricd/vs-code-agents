---
name: literal-intent-fidelity
description: Prevents agents from silently replacing a user's explicitly stated criterion with a narrower, easier, or semantically adjacent proxy when deciding scope, inclusion/exclusion, filtering, sampling, or definition of done. Load whenever the user states a testable criterion ("all files that...", "any X that may...", "every Y where..."), whenever an in-scope/out-of-scope decision is made, and MANDATORY whenever the user pushes back that their stated intent was not honored. Complements no-silent-assumptions-software-planning - that skill covers what the user did NOT say; this skill covers what the user DID say.
license: MIT
metadata:
  author: groupzer0
  version: "1.0"
---

# Literal Intent Fidelity

## Purpose

This skill prevents **criterion substitution**: the user states an explicit, testable criterion, the agent applies a *different* (usually narrower) test, and then reports the result as though it answered the original request.

The user experiences this as: *"I literally stated my intent, and my intent is not represented in the work outcome — I have to be a language lawyer to stop agents from reinterpreting me."*

Its goals are to:

- Make the user's own words the operative test, not the agent's paraphrase of them
- Force every include/exclude verdict to carry **locatable evidence**
- Make any deviation from the stated criterion **visible and approvable** before it affects the outcome
- Separate **scope** decisions (what the criterion says) from **cost** decisions (what fits the budget), which are routinely and silently conflated
- Pin the **target** the criterion is applied to, so a correct answer is not delivered about the wrong repository, branch, or working tree

### Relationship to `no-silent-assumptions-software-planning`

| Situation | Skill |
|-----------|-------|
| The user did **not** state something; the agent must not invent it | `no-silent-assumptions-software-planning` |
| The user **did** state something; the agent must not replace it | `literal-intent-fidelity` (this skill) |

Both failures are silent. They need different fixes: the first is solved by asking, the second is solved by *quoting and testing*.

---

## When to Load

Load this skill when:

- The user's request contains a criterion that can be **mechanically tested** against candidates
  ("all Python files that may be executed when...", "every endpoint that touches auth", "any doc referencing X")
- Producing any **scope table, file list, target set, filter, sample, or exclusion list**
- Carrying framing, scope rules, or vocabulary from a **prior task, plan, or analysis document** into a new request — this is the highest-risk moment for substitution
- Deciding what "done" means for a request whose definition of done the user already stated

**MANDATORY load**: the user disputes, corrects, or questions any scope/selection decision.

---

## Core Rule (Non-Negotiable)

> **The user's stated criterion is the test. Any other test is a proxy, and a proxy is never applied silently.**

If the agent is about to apply a test that differs from the user's words by even one concept, that difference must be declared as `PROXY-*` **before** it affects any verdict — and it must be accepted by the user, not assumed.

---

## The Three Substitution Modes

Recognize these; they account for nearly every occurrence.

### 1. Narrowing proxy (semantic drift)

The stated test is swapped for a related but stricter one that feels equivalent.

| User's stated test | Substituted proxy | Effect |
|--------------------|-------------------|--------|
| "may be **executed** when interpreting specs" | "**owns the semantics** of spec interpretation" | Whole delivery/transport layer silently dropped |
| "every file that **references** the config" | "every file that **depends on** the config" | Docs, tests, and fixtures silently dropped |
| "**any** endpoint that touches auth" | "any **auth** endpoint" | Middleware and side-door routes silently dropped |

**Tell**: the proxy uses a category the user never used.

### 2. Carryover framing (context bleed)

A scoping rule that was **correct for a previous task** stays active and re-scopes the new one. It feels natural precisely *because* it worked before — that familiarity is the hazard, not a validation.

**Tell**: the justification for an exclusion can be traced to a prior document, plan, or turn rather than to this request.

### 3. Budget-driven shrink (cost masquerading as scope)

The literal scope is larger than the available budget (delegations, tokens, time), so items get labeled **"out of scope"** when the honest label is **"in scope, deferred"**, **"in scope, sampled"**, or **"over budget"**.

**Tell**: the exclusion reason mentions effort, redundancy, or repetition rather than the criterion.

---

## The Target Is Part of the Criterion

The three modes above are all ways of getting the **test** wrong. There is a fourth failure one level up, and it is more expensive because nothing in the ledger detects it:

> **Target substitution** — the criterion is applied perfectly, to the wrong thing.

A criterion always applies to *something*: a repository, a working tree, a branch, a directory, a document set, an environment, a deployment. When that target is **inherited rather than stated**, every downstream step can be flawless and the whole result still lands somewhere the user did not mean.

### Where inherited targets come from

| Source | Example |
|--------|---------|
| Session or tooling binding | The agent was started against one checkout; the user is working in another |
| A fork, mirror, or abandoned remote | Work lands on `origin` while the user's real tree is local, or vice versa |
| Canonical vs. generated copies | A repo with a canonical source directory and generated/discoverable copies — editing the copy means the next sync silently reverts it |
| Branch or ref drift | The criterion is applied to `main` while the user means their feature branch |
| A prior task's target | The last request's repo, directory, or document set stays selected |

### The rule (one line of friction, not a question)

| Situation | Required action |
|-----------|-----------------|
| The user named the target | Quote it in `TARGET-*`, alongside the criterion |
| The user did not name it, and one plausible target exists | **State the target you are using, in one line, in the first response that acts on it.** Do not ask — disclose |
| The user did not name it, and **more than one** plausible target exists (fork vs. upstream, canonical vs. generated copy, two checkouts, multiple branches) | **Ask before acting.** Guessing here is unrecoverable work, not a recoverable detail |

### Target evidence

A target is confirmed by evidence, not by assumption. For a repository, that is the absolute path of the working tree, the remote it points at, and the branch — the output of a command run *now*:

```md
TARGET-001 (inherited from session binding, NOT user-stated - disclosing):
  Working tree: /home/user/vs-code-agents
  Remote:       https://github.com/example/vs-code-agents (origin)
  Branch:       feature/criterion-ledger
  Confirmed by: git rev-parse --show-toplevel; git remote -v; git branch --show-current
```

Stating this costs one line. Omitting it costs the entire task.

---

## Required Procedure — The Criterion Ledger

Run these steps before presenting any scope, selection, or filter result.

### 0. Establish the target (`TARGET-*`)

Before applying anything, pin **what the criterion applies to** — working tree, remote, branch, directory, or document set — and record whether the user stated it or the agent inherited it. An inherited target is disclosed in one line; an ambiguous one is asked about before any work begins (see *The Target Is Part of the Criterion*).

A ledger with no `TARGET-*` is incomplete, however well the rest of it is executed.

### 1. Quote it (`CRIT-*`)

Record the criterion **verbatim**, with its source turn. Never paraphrase into the ledger — a paraphrase is already a proxy.

```md
CRIT-001 (verbatim, user turn 3):
"all python files and code within our repo that may be executed when
interpreting or generating any etl specifications"
```

### 2. Operationalize it

Restate it as a per-candidate decision procedure plus the evidence type that settles it:

```md
CRIT-001 test:    Include candidate C iff C is a Python file in this repo
                  AND C may execute in any interpret-or-generate call chain.
CRIT-001 evidence: an import, a call site, or a docstring naming the entry point.
```

If the test cannot be stated mechanically, the criterion is not understood — **ask**, do not guess. Enumerate the population the criterion names — every candidate must be listed before any is judged (a criterion applied only to the candidates that came to mind is not applied).

### 3. Declare the test actually being applied (`PROXY-*`)

Before judging anything, write down the test about to be used. Compare it word-for-word against `CRIT-001`. Any difference is a proxy:

```md
PROXY-001 (DECLARED, NOT APPLIED):
Proposed test:   "module itself understands ETL vocabulary (watch/gate/emit/resolve)"
Differs from:    CRIT-001 ("may be executed when...")
Origin:          carried over from prior analysis doc 351 (carryover framing)
Would change:    excludes 11 transport/ingestion modules that pass CRIT-001
Status:          REQUIRES USER ACCEPTANCE - not applied
```

A declared proxy with no user response is a **blocking open question**, not a default.

### 4. Enumerate every candidate

List the full population the criterion names, gathered **from the repository now** — not from memory, not from a prior document's list. A criterion applied to a stale or partial candidate list produces a stale or partial answer that *looks* rigorous.

### 5. Verdict + cited evidence per candidate

Every verdict — **include and exclude alike** — carries a locatable reference: `path:line`, a quoted docstring, a call site, an import statement, a commit SHA, or a document ID.

"Reasoned from the file name", "it's obviously a...", and "by its role it must be..." are **not evidence**.

### 6. Classify every exclusion (`EXCL-*`)

Exclusion reasons must come from the valid taxonomy below. An exclusion whose reason is not in the taxonomy is an unauthorized narrowing.

### 7. Disclose drift (`DRIFT-*`)

Before presenting conclusions, state any verdict that rests on something other than `CRIT-001`. Zero drift is stated explicitly as `DRIFT: none`.

---

## Exclusion Reason Taxonomy

### VALID (criterion-based, evidence-bearing)

| Class | Meaning | Evidence required |
|-------|---------|-------------------|
| `EXCL-FAILS-TEST` | Evidence shows the candidate does not satisfy the stated criterion | The citation that shows the failure |
| `EXCL-UNREACHABLE` | The candidate cannot participate at all (dead code, deprecated shim, no live caller) | The absence check that was actually run (e.g. the grep for callers and its result) |
| `EXCL-NOT-IN-POPULATION` | The criterion names a population this candidate is not in (e.g. "Python files" and it is JSON) | The property that puts it outside |
| `EXCL-USER-DIRECTED` | The user explicitly excluded it | The user's own words |

### INVALID as scope reasons (role arguments, not criterion arguments)

These are the substitution patterns in disguise. None of them may exclude anything:

- "it's only plumbing / transport / glue / wiring / infrastructure"
- "it doesn't own the domain semantics" / "it doesn't understand the vocabulary"
- "it's a test or QA harness" — *unless the user's own criterion excludes tests*
- "it's generated / compiled output" — *if it executes and the criterion is about execution*
- "it's redundant, auditing it adds nothing" → this is a **cost** decision, see below
- "it's not really what the user meant" / "it's outside the spirit of the task"

> **The discriminating question**: *Does my exclusion reason restate the user's words, or does it introduce a category I invented?*
>
> If it introduces a category the user never used, the exclusion is invalid **as stated**. Either produce evidence it fails `CRIT-001`, include it, or escalate it as a labeled cost decision.

---

## Cost Decisions Are Separate and Explicit (`COST-*`)

When the literal scope exceeds the available budget, the scope does not shrink — the **plan** changes, with the user deciding.

Report:

1. The literal scope size under `CRIT-001` (a number)
2. The constraint it collides with (delegations, time, context, budget)
3. Options, each with what it costs and what it risks: sample N representatives (with the redundancy rationale stated), shard into batches, exceed the budget, or defer items with user consent

```md
COST-001: CRIT-001 yields 20 modules; the 8-delegation budget covers ~12 at full rigor.
  a) Sample: audit 1 of 13 structurally identical generated modules (default)
  b) Shard into 2 batches (~13 delegations, exceeds stated cap)
  c) Single pass over all 20, reduced per-module depth
```

> **"In scope but sampled" is not "out of scope."** Sampled and deferred items stay in the scope table with their `COST-*` reference, so the record still reflects the user's criterion.

---

## Pushback Protocol

When the user says a scope or selection decision was wrong, **a single correct pushback invalidates the test, not just the named items.**

1. **Do not defend, and do not patch only the items named.** Every verdict produced by the faulty test is suspect.
2. **Re-run the full pass** under the literal criterion, across all candidates.
3. **Report every verdict that flips — including ones the user did not mention.** This is the signal that the test was corrected, not the answer.
4. **Name the substitution**: which mode (narrowing / carryover / budget shrink), and where it came from.
5. **Re-justify every surviving exclusion** with its taxonomy class and fresh evidence — on the user's test, not the agent's.
6. **State the delta**: what the corrected scope now costs relative to the plan, as a `COST-*` item.

---

## Evidence & Reference Discipline

Every factual claim in a ledger, audit, or trajectory carries a label **and** a locatable reference:

| Label | Meaning | Requirement |
|-------|---------|-------------|
| `[Observed]` | Drawn from a cited artifact | `path:line`, commit SHA, document ID, or quoted docstring |
| `[Projected]` | Derived from observed data | The observed inputs **and** the derivation method |
| `[Hypothesis]` | No supporting reference | Must be marked; MUST NOT drive a verdict |

Rules:

- An unlabeled claim is treated as `[Hypothesis]`.
- Never report a count, rate, growth figure, or trajectory without the reference it came from.
- If no reference exists, say **"no reference exists"** — reasoning is not a substitute for evidence, and an invented amortization, estimate, or "roughly" figure is a fabrication.

---

## Output Format — Scope Ledger

```md
## Scope Ledger

TARGET-001 (user-stated | inherited - disclosing): <working tree> @ <branch>, remote <url>
CRIT-001 (verbatim, user turn N): "<exact user words>"
CRIT-001 test: Include C iff <mechanical test>
PROXY: none declared | PROXY-001 (pending user acceptance)
DRIFT: none | DRIFT-001: <verdict resting on something other than CRIT-001>

| Candidate | CRIT-001 result | Evidence (cited) | Verdict | Reason class |
|-----------|-----------------|------------------|---------|--------------|
| `a.py`    | passes          | `a.py:41` calls `resolve()` | IN | - |
| `b.py`    | fails           | no caller: `grep -rn "b\." -> 0 hits` | OUT | EXCL-UNREACHABLE |
| `c.json`  | n/a             | not a Python file | OUT | EXCL-NOT-IN-POPULATION |
| `d.py`    | passes          | `d.py:12` docstring: "drives the interpreter" | IN (sampled) | COST-001 |

Population enumerated: 24 candidates (source: `find . -name '*.py'`, run 2026-09-16)
In scope: 20 | Out: 4 | Sampled under COST-001: 12 of 13
```

---

## Quick Self-Check (before presenting any scope)

0. Do I know **what this applies to** — which repository, working tree, and branch — from evidence gathered now? Did the user state it, or did I inherit it? If inherited, have I said so out loud?
1. Can I point to the user's **exact words** for this criterion, or am I working from my summary of them?
2. Is my actual test **word-identical in meaning** to those words?
3. Does any exclusion use a **category the user never used**?
4. Did I enumerate the population **now**, or reuse a list from earlier context?
5. Does every verdict — including the exclusions — carry a **citation**?
6. Is anything labeled "out of scope" that is really **"too expensive"** or **"redundant"**?

Any "no" means the ledger is not ready to present.

---

## Forbidden Anti-Patterns

- Applying a correct ledger to a target the user never named — inherited from a session binding, a prior task, a fork, or the first path that matched
- Treating a session-provided or tool-provided target as user-stated
- Editing a generated or mirrored copy when the canonical source is what the user meant
- Paraphrasing the user's criterion into the ledger instead of quoting it
- Applying a narrower test and reporting the result as an answer to the original request
- Excluding items by role, kind, layer, or "spirit" rather than by the stated test
- Reusing a prior task's scoping rule in a new request without declaring it
- Labeling a budget or redundancy decision as a scope decision
- Fixing only the items the user named after pushback, leaving the faulty test in place
- Presenting counts, growth figures, or trajectories with no reference
- Treating a declared-but-unanswered `PROXY-*` as accepted

---

## Reference Files

- `references/criterion-ledger-template.md` — copy-paste ledger template and worked template fields
- `references/worked-example-scope-substitution.md` — a real, end-to-end substitution incident and its correction
