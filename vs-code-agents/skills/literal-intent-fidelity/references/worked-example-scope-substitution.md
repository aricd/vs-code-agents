# Worked Example — A Real Criterion Substitution and Its Correction

This is the incident that motivated the `literal-intent-fidelity` skill. It is included because the failure is much easier to recognize from a concrete case than from a rule.

---

## The setup

A Planner agent was asked to scope a module-quality audit of an ETL substrate. The user's criterion, stated in their own words:

> "all python files and code within our repo that may be executed when interpreting or generating any etl specifications"

Immediately before this request, the same session had completed a *different* task whose scope was deliberately narrower — it covered only the "tooling zone" that owns ETL semantics, and explicitly set the transport and runtime layers aside.

---

## The substitution

The Planner proposed a 6-file core and excluded eleven modules — the RMQ/DDS/SLP servers, their wire codecs, the database polling/replication ingestion path, and the change-data decoder — with reasoning of this shape:

> "this whole cluster delivers *to* or carries results *from* the core; it never itself interprets or generates spec content"

Read against the user's actual words, that justification answers a **different question**. The user asked what **may be executed**. The Planner answered what **owns the semantics**.

All three substitution modes were present at once:

| Mode | How it showed up |
|------|------------------|
| Narrowing proxy | "may be executed when..." became "understands ETL vocabulary (`watch`/`gate`/`emit`/`resolve`)" |
| Carryover framing | The semantic-ownership test was correct for the *previous* task and stayed active |
| Budget-driven shrink | 13 structurally identical generated modules were called "out of scope" when the real reason was redundancy — a cost decision |

The exclusions were confidently written and cited docstrings, which made them *look* evidence-based. They were: the evidence supported the proxy test, and the proxy test was never declared.

---

## The user's pushback

> "I don't know why 'Task-specific routing logic' changes my intent of 'all python files and code within our repo that may be executed when interpreting or generating any etl specifications'"

One sentence, one item class — but it invalidated the **test**, not just those eleven files.

---

## The correction (what right looks like)

The recovery was correct in four specific ways, each of which is now a rule in the skill:

**1. It named the substitution rather than just conceding.**

> "I was applying a semantic-ownership test instead of your actual, stated execution-trace test. Those are different questions, and I substituted the narrower one without saying so."

**2. It re-tested against the literal criterion with citations.**

| Module | Evidence under the literal test |
|--------|--------------------------------|
| `db_poll_ingest.py` | docstring: "dispatching newly-discovered rows through `TaskInterpreter.ingest_db_row()`" |
| `db_repl_ingest.py` | "re-dispatches through `TaskInterpreter.ingest_db_row()`, the identical entry point" |
| `slp_server.py` | answering `Get(<DataItem>)` requires calling `resolve()` |
| `push_trigger.py` | dispatched by a spec-declared `subscribe_push.push_trigger_strategy.kind` field |

Every one passed. All eleven were reinstated.

**3. It re-ran the whole pass, not only the items named.**

Applying the corrected test to candidates the user had *not* mentioned flipped one more file in (`compiler_selftest.py` — it constructs and executes both an interpreter instance and a generated module, so it passes an execution test even though it is a QA harness), and changed the *reason* for two that stayed out:

| Module | Old reason (role argument) | Corrected reason (criterion argument) |
|--------|---------------------------|----------------------------------------|
| `nav_math.py` | "deprecated compatibility shim" | `EXCL-UNREACHABLE` — never executed in any live path; reachable only from one legacy test import |
| `adr016_gate.py` | "a lint/CI gate, not part of the call graph" | `EXCL-FAILS-TEST` — statically scans source text; never invoked *by* interpretation or generation at runtime |

Same verdicts, different standing: the first pair were opinions about what kind of thing a file is, the second pair are results of the user's own test.

**4. It reclassified the budget call as a cost decision.**

The 13 generated modules moved from "excluded" to "in scope by the letter, recommend sampling 1-2 representatives because all 13 implement an identical 6-member seam" — with the sampling put to the user as a decision rather than absorbed as a scope judgement.

---

## The residue

Scope went from 6 files to ~20 — past what the agreed delegation budget covered at full depth. That is the honest downstream consequence of applying the user's criterion, and it surfaced as a `COST-*` decision for the user rather than being quietly avoided by keeping the scope small.

**This is the point of the skill.** The narrow scope was not chosen because it was right; it was chosen because it was tractable, and the proxy criterion made it *look* right.

---

## Second incident — target substitution (the same failure one level up)

The skill above was itself built during a session that reproduced the failure on a different axis.

**The setup.** The agent was working on the repository that holds these agent and skill definitions. The session had been started against a cloud clone of a GitHub remote. The user's actual working repository was a checkout on their own machine, at a path the agent could not reach and had never been told about.

**The substitution.** No criterion was misread this time. Every edit, the wiring, the hook, the doc updates, the smoke tests, the commit and the push were correct — and all of them landed in a repository the user considered abandoned. The agent never stated which working tree it was operating on, because the target had arrived through the session binding rather than through the request, and inherited context does not feel like an assumption.

**The discovery.** Not through review. The user volunteered it:

> "I realize I silently assumed something for a while now... I assumed we were talking about my repo here, not the abandoned github repo."

Both sides had held the same unstated assumption from opposite directions. Nothing in the work product could have exposed it, because the work product was *correct* — just correct about the wrong thing.

**The cost.** Every artifact had to be re-delivered as a patch for manual application, and the verification that mattered (does the PowerShell hook run?) could not be performed at all, because the agent was on the wrong operating system — a fact that follows directly from the wrong target and went unnoticed for the same reason.

**The near-miss in the same task.** That repository keeps a canonical source directory and generated, tool-discoverable copies of the same files, reconciled by a sync script. Editing the generated copies would have been silently reverted on the next sync — a second target trap inside the same request. That one was avoided only because the sync script was read first. It would not have been caught by any amount of care about the criterion.

**What would have prevented it.** One line, in the first response that touched a file:

```md
TARGET-001 (inherited from session binding, not user-stated):
  /home/user/vs-code-agents @ claude/busy-johnson-f1lzbs, origin github.com/<owner>/vs-code-agents
```

The user would have corrected it in the first thirty seconds instead of after the work was complete.

---

## Compressed lessons

1. A confident, well-cited exclusion can still be an answer to the wrong question. Citations validate the test you used — they cannot tell you it was the right test.
2. The most dangerous framing is the one that worked on the previous task.
3. "Redundant" and "out of scope" are different words with different owners: redundancy is the user's call, scope is the user's words.
4. When a user pushes back on one item, the test is what is broken. Re-run everything.
5. If the literal criterion blows the budget, say so — do not let the budget quietly rewrite the criterion.
6. A perfectly executed ledger applied to the wrong repository, branch, or working tree is worth nothing. Name the target out loud before the first edit — inherited context is an assumption that does not feel like one.
7. Where a project keeps canonical sources and generated copies, "which file do I edit" is a target question, not a style question: the wrong answer is reverted by the next sync, silently.
