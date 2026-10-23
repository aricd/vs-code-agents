# Mini-retro, deferral and orchestration review

Date: 2026-10-07 (revision 2). Not a lifecycle document: no ID minted, `.next-id` untouched.

**Evidence base.**
- axis-mcp: all 49 mini-retros (counts and every finding summary), about 6 in full, the DEFER-* rows across all of `.agent-output/`, and `guarantees/LEDGER.md` plus `failure-modes/INDEX.md`.
- vs-code-agents: the `mini-retro`, `requirements-enforcement`, `structured-labeling`, `execution-orchestration`, `backlog-grooming` and `document-lifecycle` skills; ADR-008/015/020/021; `planner.agent.md` and grep checks of the other agents; its own ledger and INDEX.

**Labels.**
- **V** = Verified in a file or by a count.
- **I** = Inference.
- **H** = Hypothesis.

**What revision 2 adds.**
1. §2: what the current mini-retro structurally cannot see.
2. §3: the deferred-item gap and a `NEEDS-HOME` state.
3. §4: a repo-independent catalog of orchestration guarantees and failure modes, built on `requirements-enforcement` (full catalog in Appendix A).
4. §5 and §6 are the earlier question and opportunity lists, extended to use them.

---

## 1. What the corpus says

| Fact | Label |
|---|---|
| 49 retro files hold 97 tagged findings. 70 land in the single `process` dimension. `agents` has 10, `skills` 13, `policy-fit` 4. | V |
| 66 of 97 findings are `confidence: high`. 96 are `fold-in: needs-bulk-review`; only 3 are `upstream-candidate`. I found no analysis that consumed them. | V (counts), I (no consumer) |
| The 20-question gradient scorecard is ON by default (ADR-015). Only 7 of 49 axis-mcp retros contain one. Retros 615 and the vs-code-agents batch skipped it on purpose. vs-code-agents' own `policy.yaml` says `require`, and its batch retro says it did not check the policy. | V |
| In the scorecards I read, most `prior` cells are `-` and scores cluster at 7–8. | V (sample), I (generalization) |
| Retros run up to 40 KB (434), 37 KB (056) and 27 KB (466). | V |

### Recurring failures the question set does not capture

| Recurring failure | Retros that hit it | Where it landed |
|---|---|---|
| **Verification scope narrower than blast radius.** `pytest src/etl/tests` missed the sibling `compact/tests`. An extension-filtered sweep missed an `.html`. A `src/oracle` break was found by accident. | 056, 585 (3 instances), 645 | `process` |
| **Shared dirty tree or concurrent session.** Includes `.next-id` clobbered or colliding, parallel Implementers confounding measurements, and a stale live-box lease. | 048, 164, 306, 434, 451, 466, 615, 636 | `process` |
| **Referenced gate tooling missing from the install.** | 036, 037, 040, 048, 082, 011-063-070, program-082 (6+ consecutive plans) | `process` |
| **Metric-budget exemption semantics.** | 036, 042, 056, 169, 209 | `process` |
| **Implementer self-report taken as evidence.** | 094, 585, 615, 645 | `agents` |
| **Defects that survived to a late gate.** | 006-010, batch-055, 191 | `process` |
| **The user had to catch it.** | 434 (twice), 443 | `process` |

The 4 categorical questions are catch-alls, so `process` absorbs 72% of findings and nothing can be trended inside it. The 20 gradient questions mostly score role quality, not these failures.

---

## 2. What the current mini-retro cannot see

These are structural limits of the design, not author mistakes. The retro is written by one orchestrator, from recall, at the commit boundary, against four coarse questions and a role-quality scorecard.

| # | Blind spot | Why the current design hides it | Evidence | Fix (where it lands) |
|---|---|---|---|---|
| 1 | **Deferred, dropped and waived scope.** What left the plan and where it went. | No dimension, template field or scorecard row covers it. | 6 of 49 retros mention DEFER at all (13 mentions); the corpus holds 268 distinct DEFER ids (§3). (V) | `deferral_flow` block, Q33, family G sweep |
| 2 | **Detection by luck.** | The rubric records defects found, not how they were found. A defect caught by accident looks identical to one caught by a gate. | 11 phrase hits for "by accident / incidental / happened to / only surfaced because / only caught". 585's third sibling-test miss was caught by an unrelated cross-check. (V phrase counts, I reading) | `detected-by` tag, Q34 |
| 3 | **Defect funnel and gate yield.** Which stage introduced a defect, which caught it, which could have. | Q18 asks whether each gate added distinct assurance but nothing tallies it. | The sibling-test miss slipped past the Implementer, Code Review and the first QA pass. (V) | Defect funnel table (§5.3), Q23 |
| 4 | **Late escapes.** | The retro is required before DevOps. Anything found after that is outside it. | 585: a regression was found by post-commit verification and a follow-up commit recorded it (commit `91864c7`). (V) | Late-escape amendment trigger |
| 5 | **The orchestrator's own errors and blind spots.** | Self-authored. An error the orchestrator did not notice cannot appear. | 636's CRLF defect was self-inflicted and found by QA. (V) | Subagent `friction` and `not_run` fields (§5.4); sampled independent audit (H) |
| 6 | **User corrections.** | The skill forbids soliciting the user, so the strongest signal is unmeasured. The orchestrator can still count corrections it received without asking. | 6 phrase hits for "user caught / had to / imposed / corrected". 434: the user imposed a numeric rule after catching a false "done" twice. (V) | Q32, counted from the transcript |
| 7 | **Cost.** Delegations, re-dispatches, context resets, wall-clock. | The pre-fill hint mentions round-trip counts but the template has no field. | Retros reach 40 KB with no cost figure. (V) | Cost block (§5.3), Q29/Q30 |
| 8 | **Context loss at resume.** | `Authorship: resumed` is recorded, but not what was reconstructed or what the reconstruction got wrong. | 3 retros (585, 615, 466-reconstructed). (V) | Q36 |
| 9 | **Decision quality.** | The retro scores agents, not the orchestrator's accept / waive / defer / fix-forward calls. | 636: QA's verdict was reversed after the Planner cited a skill carve-out. A good decision, visible only by luck. (V) | Q35 |
| 10 | **Link to the failure-mode registry.** | Retro findings are never triaged as escapes. | 49 retros contain 16 `FM-x-` and 13 `G-x-` mentions. axis-mcp's INDEX has 0 `FM-P/T/D` rows. vs-code-agents' INDEX has 7 rows, all `FM-T`. (V) | `fm_code` and attribution bucket on every finding (§4.5) |
| 11 | **Per-family trend inside `process`.** | One dimension holds 72% of findings. | §1. (V) | 8-family sweep (§4.5) |
| 12 | **Fold-in outcome.** Were past findings acted on? | `needs-bulk-review` has no owner or clock. | 96 of 97 findings. (V) | Recurrence counter and `NEEDS-HOME` on findings (§3.3) |
| 13 | **What is working.** | "What Worked" appears ad hoc in a few retros; the scorecard captures it only as high scores. | 636 has it; most retros do not. (V) | Optional `keep` list (low priority) |
| 14 | **Skill/agent load evidence.** | Q13 and the skills dimension are answered from recall. | No load trace in the template. (H that this matters; not measured) | Low priority |

---

## 3. Deferred items: the missing "home"

### 3.1 Evidence

The plan template already has a required `Deferred Items (DEFER-*)` section (ADR-008, `structured-labeling` §9) with composite IDs `DEFER-<origin-doc-ID>-<seq>`. The mechanism catches deferrals made at plan-authoring time. The corpus shows what happens afterwards.

| Fact | Label |
|---|---|
| 268 distinct DEFER ids appear across axis-mcp `.agent-output/`. 223 have a defining table row (304 rows in total, because rows are re-copied across plans). | V |
| For those 223, the last row I scanned shows: 25 closed or `[ABSORBED]`, 27 name a plan, **131 "Unowned"**, 40 vague ("future plan", "Planner", "User decision pending"). So about 77% (171 of 223) have no named owner and no closure marker. The scan order is by file, not by date, so treat the split as approximate. | V (counts), I (proxy) |
| 78 of 268 ids are referenced from only one document-number prefix, so no later plan ever cited them. Some are legitimately closed in-plan. | V (count), I (reading) |
| Remediation so far is manual plans: 417 (deferred-items backlog grooming) and 626 (plan 466 deferred-item consolidation, which took three critique rounds: 630, 635, 648), plus at least 8 single-id analyses (155, 245, 504, 528, 614, 622, 623, 633). | V |
| ADR-008 names the root cause: "nothing resurfaces a prior deferral when a later plan touches the same area". The composite ID makes citation reliable but does not surface anything. The only consumer I found is `backlog-grooming`, which is manual and on demand. `planner.agent.md` has no intake scan for open DEFER items. | V (ADR text, grep) |

### 3.2 Where scope leaves a plan without a home

The DEFER section covers channel 1 only. Every other channel uses its own local vocabulary and none feeds a shared record.

| # | Channel | Where it is recorded today | Status |
|---|---|---|---|
| 1 | Plan-time deferral | Plan section 9, `DEFER-*` row | Has an ID; owner often "Unowned" (V) |
| 2 | Pre-plan: an analysis, critique, architect or brainstorm recommends "later" | Inside that document; brainstorm `GO-with-OPENQs` | No ID, no row. 434 F-2: nothing forces an alternative before accepting "defer to a follow-up plan" (V) |
| 3 | Pre-plan: a prior plan's row says "next X plan MUST check" | Closed plan | Relies on a future Planner remembering (V) |
| 4 | Pre-plan: user says "later" in chat | Chat | Lost at session end (H) |
| 5 | Mid-plan: Implementer blocker dispositioned by the Planner | Work-order `blockers[]`, execution-state | Dies with the chain (585 had 4 such dispositions) (V) |
| 6 | Mid-plan: pre-approved deferral | `execution-orchestration` says "record it in the execution-state file and continue" | Execution-state closes with the chain (V) |
| 7 | Mid-plan: phase truncation ("Phase 3 deferred") | Plan text | 585, 615 (V) |
| 8 | Mid-plan: live-gated tests marked `DEFERRED`, tests `xfail`-marked | Test code, plan text | 636, 626 (V) |
| 9 | Verdict qualifiers: Code Review "non-blocking", QA "ACCEPT WITH NOTES", UAT "APPROVED WITH EXCLUSIONS" | Inside the report | Exclusions are real scope decisions with no ledger entry (V that the verdict wording exists) |
| 10 | Planner "disposition note in the plan changelog" | Plan changelog | 645: a QA finding closed by a note, no ID (V) |
| 11 | Critic status `DEFERRED`; Implementer "Outstanding Items" | `critic.agent.md` line 122, `implementer.agent.md` line 217 | Local status words (V) |
| 12 | Mini-retro findings, `needs-bulk-review` | The retro | 96 of 97 (V). These are deferred items in all but name. |

### 3.3 Proposal: a `NEEDS-HOME` state

**Capability Admission walk (lean ladder).**

| Rung | Result |
|---|---|
| Need | Every deferral, from any stage, ends with a named owner and a trigger, or is explicitly dropped. |
| Decompose | (a) capture at the moment of deferral; (b) give it a durable home that is not the closing artifact; (c) force owner and trigger; (d) resurface it when relevant; (e) show it in the retro and close summary; (f) close it. |
| Represent now (no new code) | Treat `DEFER-*` as the single label for all 12 channels. A `DEFER-<origin-doc-ID>-<seq>` may be minted by any artifact type (analysis, critique, QA, UAT, retro), not only the plan section. Add a `State` column (below). |
| Extend a primitive | `structured-labeling`: extend the `DEFER-*` definition and the Deferred Items table. Verdict templates for Code Review, QA and UAT: every note or exclusion gets a `DEFER-*` id or "dismissed: reason". `fold-in: needs-bulk-review` becomes the state `needs-home`. |
| New primitive (needs your sign-off) | A report-only script `check-deferred-homes.{ps1,sh}` modelled on `check-chain-closure` (it reports and does not resolve). |
| Never | Do not hand-keep a central register at first. It would be candidate sprawl. Derive the list by scan. |

**States.**

| State | Meaning | Exit |
|---|---|---|
| `needs-home` | Created, but owner is "Unowned", vague ("future plan", "Planner"), or absent. This is the default for any deferral minted outside a plan, and for any row whose owner is not a named plan, stub, ADR or dated user decision. | Homed, dropped, or closed within the age rule below |
| `homed` | Owner is a named plan or stub ID, an ADR, or a dated user decision, and there is a concrete revisit trigger. | Closed, or back to `needs-home` if the owner closes without it |
| `closed` | Delivered, `[ABSORBED]`, `[RESOLVED]` or superseded. The corpus already uses `[ABSORBED date]` markers (V), so this reuses existing practice. | Terminal |
| `dropped` | Explicit won't-do with a one-line reason. | Terminal |

The exits match the `backlog-grooming` dispositions that already exist: keep, re-trigger, park, drop, re-home (V). `needs-home` is the state those dispositions act on.

**Rules.**
1. **Age.** A `needs-home` item older than 10 days (the threshold `structured-labeling` already uses for age-triggered escalation of OPENQ items) becomes BLOCKING in the next executive summary. Mirrors the ledger rule "deferral is allowed once; a twice-deferred candidate is decided or rejected".
2. **Authorization is unchanged.** `NEEDS-HOME` records. It does not authorize. The Critic still cannot approve deferrals, and an unapproved deferral of user-approved scope is still a hard stop in `execution-orchestration`. The gap this fills is the approved, pre-approved and incidental deferrals that do not stop the run and today end in execution-state.
3. **Close gate.** A chain may not reach DevOps with a `needs-home` item that it created or touched, unless the user acknowledges it. This is a report line first; promote to a hard gate only after the report has run for several plans (the same trajectory ADR-021 used for its own enforcement).
4. **Intake scan.** At plan start the Planner lists open DEFER items touching the plan's area before scoping (closes ADR-008's W-1). This is an adjudicated check: enumerate candidates from the open-item scan before reading the draft plan's own claims, the shape `requirements-enforcement` uses for completeness-of-consideration guarantees.

**Retro fields.** New block in the mini-retro template:

```
deferral_flow:
  opened: <n>            # new DEFER ids minted or touched by this chain
  homed: <n>
  needs_home: <n>        # list ids; must be 0 or user-acknowledged
  verdict_qualifiers: <n>  # notes/exclusions in Code Review, QA, UAT
  dismissed_with_reason: <n>
```

plus Q33 (§5.2) and the family G sweep row (§4.5).

---

## 4. Orchestration guarantees and failure modes: a common language

### 4.1 Where things stand

- `requirements-enforcement` already has what is needed: guarantees as one falsifiable clause, a three-level class/mode/instance model, a layer namespace that includes `P` (process/planning), three oracle types (structural, measured, adjudicated) and escape attribution (coverage / taxonomy / contract gap). (V)
- **No portable orchestration content exists.** The skill distributes templates and rules, and the ledger and registry live in each consuming project. (V)
  - axis-mcp's ledger entries I listed (35) are all `G-R-` product-runtime guarantees, and its INDEX has no `FM-P`, `FM-T` or `FM-D` rows. (V)
  - vs-code-agents' ledger has 11 candidates, all `G-T-` or `G-D-`. They guard its own scripts (work-order gate, chain-closure, validators) and one planning behaviour (`G-D-ASSERTBYPASS`). (V)
  - Those `G-T-` entries guarantee the **tool** works (does `run-work-order-gates` flag every scope violation). None guarantees the **behaviour** that uses the tool (does a chain actually verify the whole blast radius). They are different layers of the same problem.
- The mechanism to use a shared vocabulary already exists and is dormant. `document-lifecycle` Agent Self-Check step 5 tells agents to check `failure-modes/INDEX.md` for a matching process/infra row and increment `recurrence_count` instead of filing a new finding. With no process rows in the INDEX, step 5 can never match. (V)
- Meanwhile the recurring orchestration failures of §1 live only in retro prose (§2 row 10).

### 4.2 Shape: a seed catalog that respects the skill's rules

The skill has rules that a pre-built list could violate. The design below keeps each one.

| Skill rule | How the catalog complies |
|---|---|
| Rule 1: classes are minted lazily, never pre-generated. | The catalog is a **reference vocabulary of candidate statements**, not ledger entries and not class files. A project mints an entry into its own ledger only when triage cites it, by copying the ID and statement verbatim. |
| Pull, not push; avoid becoming the flood. | Nothing is loaded by default. The catalog is one index-style file read during triage and retro authoring. Class detail stays in the appendix. |
| Candidate sprawl; ratification is a human gate. | Catalog entries have zero obligations until a project mints and ratifies them. Evidence strength is shown per entry so thin ones stay "watch". |
| Mnemonics: 3–9 uppercase characters, unique within a layer. | All 22 mnemonics are 7–9 characters in layer `P`. A project's own `G-P-` IDs must not reuse them, which also gives stable cross-repo IDs. |
| Single-oracle rule for modes. | Each mode in Appendix A names the oracle that would catch it. Where one class has modes with different oracles, they are separate modes (for example `VERSCOPE.SIBLING-ROOT` and `VERSCOPE.INTERP-VARIANT`). |

**Admission record.**

| Rung | Result |
|---|---|
| Need | A shared, repo-independent name for each recurring orchestration failure, so retros, QA triage and plans can reference the same ID. |
| Represent now | A reference file `skills/requirements-enforcement/references/orchestration-catalog.md` (Appendix A is its draft). One clause added to triage step 1: "check the catalog for a matching `G-P-` guarantee before minting a fresh candidate." |
| Extend a primitive | Mini-retro template: `fm_code` and attribution bucket on findings (§4.5). |
| New primitive | None. |

### 4.3 The catalog at a glance

22 guarantees in 8 families, all `G-P-<MNEMONIC>` with mode IDs `FM-P-<MNEMONIC>.<MODE>.<NNN>`. Full text, modes, checks and evidence are in **Appendix A**.

| Family | Guarantees |
|---|---|
| A. Delegation | WOPRECISE, CTXCARRY |
| B. Boundary | SCOPEHOLD, ROLEHOLD |
| C. Verification | VERSCOPE, REDERIVE, BASELINE, DEMOREAL, PASSDECAY |
| D. Shared state | ISOLATE, IDALLOC, LEASEREL, TOOLAVAIL |
| E. Continuity | STATETRUE |
| F. Gates | GATEORDER, GATEINTEG |
| G. Deferral | DEFERHOME, RESURFACE |
| H. Loop and authority | LOOPCLOSE, CLAIMTRUE, USERCALL, CEREMONY |

### 4.4 How each is checked explicitly

The skill's three oracle types map onto the catalog, which is what makes "check for these explicitly" concrete.

| Oracle type | Fits | Examples |
|---|---|---|
| **Structural** (script or invariant, runs in CI or a gate) | Properties a script can read from the repo | SCOPEHOLD (scope check anchored at the first `base_commit`, including untracked files), TOOLAVAIL (resolve every named gate before delegating), IDALLOC (uniqueness, monotonic), BASELINE (failing node-ID set at base vs after), DEFERHOME (`check-deferred-homes`) |
| **Measured** (procedure, corpus and threshold) | Rates and distributions | LOOPCLOSE (`recurrence_count` ≥ 3 with no owner), CEREMONY and REDERIVE (Q29/Q30/Q22 against change size), escape latency (Q23) |
| **Adjudicated** (an agent runs a versioned procedure) | **Completeness-of-consideration guarantees**, where a violation leaves no site in the artifact to point at | VERSCOPE, RESURFACE, WOPRECISE, DEMOREAL |

VERSCOPE and RESURFACE are the clearest adjudicated cases. The sibling-test miss is exactly a failure with no visible site: the narrower test command looked complete. The skill's rule for adjudicated oracles fits directly: the reviewer **enumerates candidates from named sources before reading the artifact's own claim**, then records every candidate including the ones ruled inapplicable. For VERSCOPE the named sources would be (1) every test root found by a repo scan, (2) every derived-artifact generator the repo declares, (3) sibling directories of any root that was executed, (4) importers of the changed modules. Reading the Implementer's "zero regressions" first would anchor the reviewer on the Implementer's set, which is what happened in 585 and 645.

### 4.5 Retro integration

1. **Split `process` into the 8 families** (a sweep, not 22 questions, so it does not become a per-guarantee checklist that the skill warns against):

```
family_sweep:
  - family: C-verification
    hit: yes|no|n/a
    impact: <1-10>            # 10 = no effect
    round_trips: <n>
    detected_by: gate|incidental|user|post-commit|author
    codes: [FM-P-VERSCOPE.SIBLING-ROOT]   # or NEW
  # ... A through H
```

   Codes are filled only on a hit. This makes the family the trend unit and removes the 72% catch-all.

2. **Every finding gets `fm_code` and `attribution`** using the skill's own three buckets (coverage gap / taxonomy gap / contract gap). `NEW` means taxonomy gap and becomes a candidate mode.
3. **Recurrence uses the existing mechanism.** A hit increments `recurrence_count` and `last_seen` on the project's INDEX row, per `document-lifecycle`'s Agent Self-Check, instead of writing a new finding paragraph. Retros then cite the code and stop re-narrating (§2 row 12).
4. **Health metric.** The skill says taxonomy-gap share should fall as mechanisms get named, and contract-gap escapes should convert to ratified guarantees. Retros become the intake that makes both measurable at the orchestration layer.
5. **Who files.** The skill makes QA the only mandatory registry write path. Orchestration escapes mostly surface to the orchestrator, so the retro author files `NEW` codes as candidate mints (the one-line mint format), and ratification stays a human gate.

---

## 5. Question set additions

### 5.1 Design rules

1. **Every dimension gets a paired numeric.** Letter option plus **Impact 1–10** plus **round-trips (integer)**. Written rationale stays mandatory for any non-default answer.
2. **Behavioural anchors per question**, count-based where possible ("countable over taste"). A single generic anchor table invites the 7–8 clustering seen in the sample.
3. **Evidence class on every score:** `observed`, `inferred` or `recalled`.
4. **Counterfactual on every score ≤ 6:** "what single change would have made this +2?" It becomes the finding's detail.
5. **`prior` = rolling mean of the last 5 retros in the same plan class**, not "last comparable retro".
6. **Findings carry `recurrence: n, cites: [ids]`, `fm_code` and `attribution`** (§4.5). Findings with n ≥ 3 auto-promote to a backlog stub.
7. **`detected_by` on every defect:** `gate`, `incidental`, `user`, `post-commit`, `author`.

### 5.2 New gradient questions (Q21–Q36)

All are 1–10 with an evidence class and a one-line rationale. Family letters link to §4.3.

| # | Question | Anchors (1 = / 5 = / 10 =) | Family |
|---|---|---|---|
| Q21 | **Verification-scope fidelity.** Did each "full suite / zero hits / no regressions" claim cover the blast radius? | A claimed-full run missed a whole test root or file class / one gap caught at review / scope derived, not authored, and matched | C |
| Q22 | **Independence of closing evidence.** Share of closing claims re-derived by a different agent. | Nearly all repeated from the author's report / half / all re-derived | C |
| Q23 | **Escape latency.** How late was the latest-caught defect found? Also record the earliest stage that could have caught it. | After commit / QA or UAT = 4 / Code Review = 7 / author's own check = 10 | C |
| Q24 | **Baseline integrity.** Was every "pre-existing" claim traced to a base state captured before the change? | Accepted on assertion / some / all baseline-diffed | C |
| Q25 | **Environment isolation.** Contamination from dirty tree, concurrent sessions, leases, `.next-id`. | A contaminated measurement drove a wrong verdict / noticed and worked around / none | D |
| Q26 | **Tooling availability.** Did every gate, script and validator the contract names exist and run? | A referenced gate was absent or unusable / one workaround / all resolved | D |
| Q27 | **Work-order precision.** Was scope and acceptance wording literal enough that no executor had to guess? | Mid-flight redesign / one re-delegation for ambiguity / none | A |
| Q28 | **Boundary integrity.** Edits outside role or scope, including orchestrator edits and mid-chain commits. | A silent out-of-scope change reached QA / disclosed and fixed / none | B |
| Q29 | **Rework ratio.** Record delegations and re-dispatches next to the score. | More than 50% re-dispatched / ~25% / 0 | H |
| Q30 | **Orchestrator verification labour** beyond delegating. | Orchestrator re-did most checks / some / delegates carried them | H |
| Q31 | **Prior-lesson application.** Did the chain re-hit a documented lesson? Cite the retro or code. | Repeated a known mistake / lesson partly applied / a known lesson visibly prevented one | H |
| Q32 | **User-intervention necessity.** Corrections the user had to make that the system should have caught. Counted from the transcript, never asked. | 3 or more / 1 / 0 | H |
| **Q33** | **Deferral hygiene.** Every item deferred, waived, excepted or accepted-with-notes has a named home and trigger. | Items left `needs-home` and unacknowledged / most homed, a few vague / all homed or dropped with reason | G |
| **Q34** | **Detection by design.** Share of defects first caught by a designed gate rather than by luck, the user or post-commit verification. | Most found incidentally or by the user / half / all by designed gates | C |
| **Q35** | **Disposition quality.** The orchestrator's accept, waive, defer and fix-forward calls, judged in hindsight. | A call was reversed or caused rework / mostly sound, one weak / all held up | H |
| **Q36** | **Resume fidelity** (N/A if not resumed). How much state was reconstructed, and how many reconstruction errors surfaced. | Reconstruction errors reached a gate / minor, caught by reconciliation / state reconciled before first delegation | E |

### 5.3 Structured blocks to add to the template

**Defect funnel.** One row per defect:

```
defect | introduced_at | caught_at | catchable_at | detected_by | code
```

Gate yield, escape latency (Q23) and detection-by-design (Q34) are derived from it rather than guessed.

**Cost block.**

```
cost: { delegations: <n>, re_dispatches: <n>, context_resets: <n>, authoring_minutes: <n> }
```

**Late-escape amendment.** If post-commit verification finds an escape, the retro is amended with a dated `late_escapes:` entry and the same funnel row. The existence rule and non-blocking posture are unchanged.

### 5.4 Per-role triple, subagent fields, meta-calibration

- **Per-role triple** (replaces single-score Q5–Q12): first-return correctness, evidence quality, boundary adherence. In the corpus Implementers were often strong on correctness but weak on evidence scope.
- **Subagent return format** gains three fields, aggregated by the orchestrator so the retro has first-hand data from the people who did the work:

```
friction: <1-10, 10 = frictionless>
ambiguity: <what in the work order I had to guess>
not_run: <verification surfaces I did NOT run>
deferred: <items I dropped or postponed, each with a proposed home>
```

  `not_run` alone would have surfaced three of the sibling-test misses before QA. `deferred` is channel 5 and 7 of §3.2 captured at source.
- **Meta-calibration:** a confidence 1–10 that answers reflect observed evidence (capped at 6 for resumed or reconstructed authorship), and authoring minutes.

---

## 6. vs-code-agents: orchestration and role opportunities

### 6.1 Already addressed (V, do not re-propose)

| Prior issue | Fix in vs-code-agents |
|---|---|
| Gate scripts absent from install | `scripts/run-work-order-gates.{ps1,sh}` and `check-plan-scope-collision` exist. ADR-020 sets the resolution contract and `link_setup.py`. A missing script is now a `blockers[]` HARD BLOCK. |
| CRLF plan rejected by the validator | `validate-plan-template.sh` strips `\r`. |
| `.next-id` races among parallel delegates | `document-lifecycle` §Orchestrated sessions: one allocation by the orchestrator, delegates inherit. |
| Deferral of a failed Demonstrated criterion | Root-Cause-First disposition in `planner.agent.md` (plan 037). |
| Claimed-but-unmapped interface capabilities | Propagation Test and Claimed-Support Map (ADR-021). |
| Chain identity and closure | Plan 039. |
| Recurrence tracking | `recurrence_count` / `last_seen` in the INDEX and Agent Self-Check step 5 (dormant for lack of process rows, §4.1). |

### 6.2 Open opportunities

Ranked by recurrence and cheapness. Rungs follow the lean ladder. "Sign-off" marks a new primitive that needs your decision.

| # | Opportunity | Evidence | Rung | Targets |
|---|---|---|---|---|
| **O1** | **Derive the verification surface** instead of authoring it. Add a work-order field listing test roots and regen commands, plus a gate comparing roots found by a repo scan against roots executed. `qa.agent.md` says "run the complete suite" but never defines "complete". | Sibling-test miss: 056, 585 (3), 645 | Extend schema and gate | `execution-orchestration`, `qa`, `run-work-order-gates` |
| **O2** | **Baseline node-ID diff as a gate**; Code Review traces any "pre-existing" claim to a commit. | 615 F-1; 645 did it by hand | Gate config | `code-reviewer`, work-order gates |
| **O3** | **`not_run`, `friction`, `ambiguity`, `deferred` in every delegation return.** | 585, 645, 094 | Return-format field | `implementer`, `execution-orchestration` |
| **O4** | **Orchestration preflight (start and resume):** existing work-order files for this plan; reconcile execution-state against plan frontmatter; tree dirty from another actor; `.next-id` monotonic; commits since the plan's first `base_commit`. | batch-055 F-3, 011-063-070, 048, 306, 451, 466, 615 | Checklist | `planner`, `execution-orchestration` |
| **O5** | **Resolve the Planner role boundary.** `planner.agent.md` says "Never edit source code". Retros 585 and 645 record Planner-made fixes; 035 flagged a direct edit. Either enforce delegation or define a **micro-fix lane** (line cap, logged, re-reviewed by the next gate). | 035, 585, 645 | Spec change | `planner` (your call) |
| **O6** | **Isolate parallel delegations** with a worktree each, or serialise. | 466 F-4, 636 F-3, 011-063-070 | Process rule | `execution-orchestration` |
| **O7** | **QA: check the TDD carve-out before blocking on chronology.** No hit for `exploratory`/`retroactive` in `agents/`, so still open. | 636 F-2 | Checklist line | `qa`, `testing-patterns` |
| **O8** | **Code Review: claim re-derivation checklist.** Walk each enumerated requirement; re-verify an exemption's stated root cause; multi-run flaky tests; check flipped assertions. | 040, 083, 094, 169, 191 | Checklist lines | `code-reviewer` |
| **O9** | **Review-loop stop rule** keyed on "no new severity or new class of finding", not a round count (the 209 chain showed a further round finding something worse). | 615 (Critic ×4, Architect ×2), 209 | Rule | `critic`, `planner` |
| **O10** | **Retro validator** (`validate-mini-retro`): required `policy.yaml` dimensions honored, scorecard rows present with rationale, a finding for every score ≤ 6, `fm_code` present. | 96/97 findings unconsumed; `require` bypassed in the vs-code-agents batch retro | New script (sign-off) | `mini-retro`, `pi` |
| **O11** | **Pre-commit full-repo test gate** (a standard `GATE-00N`) for plans touching shared fixtures. | 585 F-3 | Standard gate | `execution-orchestration`, `devops` |
| **O12** | **De-duplicate `planner.agent.md`** (41.5 KB; orchestration rules also in the skill). | Size V; duplication H | De-duplication | `planner` |
| **O13** | **`NEEDS-HOME` lifecycle:** any artifact may mint `DEFER-<its-ID>-n`; state column; verdict templates enumerate exclusions; Planner intake scan of open DEFER items. | §3 | Extend primitives | `structured-labeling`, `planner`, `code-reviewer`, `qa`, `uat` |
| **O14** | **`check-deferred-homes` report** and a close-time report line, promoted to a gate later. | 131/223 unowned | New script (sign-off) | `scripts/`, `devops` |
| **O15** | **Orchestration catalog** as a reference in `requirements-enforcement`, one triage clause, and Agent Self-Check step 5 pointing at it. | §4 | Represent now | `requirements-enforcement`, `document-lifecycle` |
| **O16** | **Retro template restructure:** family sweep, `detected_by`, defect funnel, deferral flow, cost block, late-escape amendment, Q21–Q36, paired numerics. | §2, §5 | Extend template | `mini-retro` |
| **O17** | **Close the retro-to-action loop:** auto-create a backlog stub when `recurrence_count` reaches 3 (the `backlog-grooming` skill exists). | LOOPCLOSE evidence | Rule | `mini-retro`, `backlog-grooming` |

### 6.3 Role-by-role summary

| Role | Strongest evidence of value | Biggest open gap |
|---|---|---|
| Planner | Run-to-target, work orders, mini-retro gate. | Boundary ambiguity (O5), no start/resume preflight (O4), no deferral intake scan (O13), size (O12). |
| Critic | Template and semantic catches; dual-blind passes (172). | Diminishing-returns loops (O9). |
| Implementer | Complete, well-evidenced builds. | Self-reported evidence scope (O3). |
| Code Reviewer | Caught the most Critical defects (039, 191). | Pre-existing attribution (O2), re-derivation checklist (O8), non-blocking notes with no home (O13). |
| QA | Most regression catches (585, 615, 645). | TDD carve-out (O7), "complete suite" undefined (O1), "ACCEPT WITH NOTES" with no ledger (O13). |
| UAT | Re-traces sources independently (636). | "APPROVED WITH EXCLUSIONS" exclusions have no ledger (O13). |
| DevOps | The retro existence gate works. | Pre-commit full-repo gate (O11), `needs-home` close report (O14). |

---

## 7. Suggested order

1. **Template and vocabulary, no code (O15, O16, O13 minus the script):** the catalog reference, the retro restructure, and `NEEDS-HOME` as a state and label. They share one vocabulary, so land them together. Pilot on 3–5 existing retros first.
2. **Return-format fields and verification surface (O3, O1):** `not_run` and `deferred` address the two most repeated finding classes.
3. **Scripts needing your sign-off (O14, O10):** the deferred-homes report, then the retro validator.
4. **O2, O4, O6, O8, O11:** gate and checklist additions.
5. **O5:** needs your decision. O9, O12 and O17 afterwards.

## 8. Limits of this review

- I read all 97 finding summaries but only about 6 retros end to end. Rationale text in the other 40-plus was not read.
- The DEFER split (§3.1) uses "last row scanned per id" in file order, with regex owner classification ("names a plan" may include false positives from three-digit numbers). It shows scale, not an exact audit.
- I did not check which agent versions axis-mcp currently consumes. Some findings may predate fixes in vs-code-agents.
- The "write-only" claim for retro findings is an inference from the analysis listings I read.
- Phrase counts (luck, user-catch) are weak proxies for the underlying behaviour.
- The catalog's evidence cites are retro IDs I saw in finding summaries. A few modes (ROLEHOLD for 585/645, USERCALL.PRESENTATION) rest on a single summary line and are marked "watch".
- Proposed anchors are untested. Pilot before treating them as calibrated.

---

## Appendix A: Orchestration catalog (draft of the reference file)

**Convention.** Guarantee IDs are `G-P-<MNEMONIC>`; each anchors class `FM-P-<MNEMONIC>`; modes are `FM-P-<MNEMONIC>.<MODE>.<NNN>`. Evidence IDs are axis-mcp retro numbers; `vsc-batch` is the vs-code-agents batch-055/037/039/056 retro. **Strength:** core = three or more independent chains, watch = one or two. Candidate only: a project mints an entry into its ledger by copying the ID and statement verbatim, and ratification stays a human gate.

### A. Delegation

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| WOPRECISE | A delegation's scope and acceptance criteria can be met only by doing the intended thing: an executor's literal reading yields the orchestrator's intent. | `AC-NOT-LITERAL` (a directory sweep run as an extension sweep); `SCOPE-OVERBLOCK` (blocked list contradicts the plan's own ruling); `MIXED-GATES` (live-gated and offline work bundled); `TEMPLATE-GATE-OMIT` (a reused template drops a gate); `PATH-FRAME` (wrong root prefix) | adjudicated: a second reader restates each criterion from the work order alone; compare to intent | 037, 038, 042, 083, 169, 191, 451, 645. Core |
| CTXCARRY | Everything a stateless delegate needs is in its delegation text, not in the orchestrator's memory or an earlier turn. | `BY-REFERENCE` ("the previously agreed list"); `STALE-BASE` (`base_commit` captured before pre-delegation edits) | structural: delegation lint for unresolved references; `base_commit` taken after the last owner edit | 056, 082. Watch |

### B. Boundary

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| SCOPEHOLD | Every change attributable to a chain lies inside the declared scope of the delegation that made it, including mid-chain commits and orchestrator edits. | `UNTRACKED-BLIND`; `MIDCHAIN-COMMIT` (an earlier delegation's commit predates the current base); `OWNER-PREEDIT` (owner edit to a blocked file indistinguishable from the executor's); `SCOPE-OMITS-DERIVED` (generated outputs not in scope); `INDEX-SWEEP` (a pathspec-less commit takes another actor's staged files); `BASE-ANCHOR` | structural: scope check anchored at the plan's first `base_commit`, including untracked files and a commits-since list (tool side exists as `G-T-WOSCOPE`) | 035, 049, 056, 082, 306, 466, 615. Core |
| ROLEHOLD | Each role writes only what its definition permits. | `ROLE-OVERREACH` (orchestrator edits source); `ROLE-MISROUTE` (a task sent to a role whose output path forbids it); `FIELD-CLOBBER` (one agent overwrites another's lifecycle field) | structural: path ownership per role vs the diff; adjudicated for routing | 1, 035, 048; 585 and 645 (I, from delegation chains). Watch |

### C. Verification

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| VERSCOPE | Every completion claim names the surface it covered, and that surface includes the change's blast radius. | `SIBLING-ROOT`; `EXT-FILTER`; `DERIVED-STALE` (generated code, sidecars or manifests not regenerated before the verifying run); `INTERP-VARIANT` (verified under a runtime other than the shipped one); `ENUM-SKIP` (aggregate checked, enumerated items not walked) | adjudicated (`A-`): enumerate test roots, derived-artifact generators and sibling directories from a repo scan before reading the claim; record inapplicable candidates. Structural supplement: the O1 gate | 056, 169, 585, 645, vsc-batch. Core |
| REDERIVE | A closing claim is re-derived by an agent other than the one that made it. | `SELF-REPORT-ACCEPTED` (diffstat, counts); `COUNT-MATCH` (failure count matches, members not compared); `STATED-CAUSE-ACCEPTED` (an exemption's root cause taken on narrative); `ASSERT-FLIP` (expected values changed to fit code); `FIRST-CONFIRM-STOP` | measured: Q22. Structural: the re-derivation record names a different agent | 040, 056, 083, 094, 209, 615. Core |
| BASELINE | A failure called pre-existing or unrelated is attributed to a base state captured before the change. | `PREEXIST-ASSERTED`; `CONTAMINATED-BASE` (another plan's in-flight work in the measurement); `BASELINE-NARROW` (the named baseline is narrower than the invocation) | structural: failing node-ID set at `base_commit` diffed against after-change (O2) | 615, 636, 645. Core |
| DEMOREAL | A `[Demonstrated]` criterion exercises the real path the risk lives on. | `INTERCEPTED-PATH` (an earlier check fires first); `SYNTHETIC-SATISFACTION`; `HALVES-UNSPLIT` (a compound mechanism evidenced only as a whole); `SINGLE-RUN-TRUST` (a nondeterministic path trusted on one run) | adjudicated; the tool side exists (`G-T-DEMODISCONF`) | 037, 038, 042, 191, 209, vsc-batch. Core |
| PASSDECAY | An acceptance test that depends on repo-wide state is re-run at commit time, not only at implementation time. | `REPO-WIDE-DECAY` | structural: a re-run list consumed at the DevOps gate | vsc-batch, 585. Watch |

### D. Shared state

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| ISOLATE | A delegation's measurements are not confounded by another actor's uncommitted work. | `CONCURRENT-SESSION`; `PARALLEL-IMPLEMENTERS`; `DIRTY-TREE-NOISE` | structural: preflight tree/owner check; worktree per parallel delegation (O6) | 011-063-070, 048, 164, 451, 466, 636. Core |
| IDALLOC | Every minted identifier is allocated exactly once and never moves backward. | `PARALLEL-MINT`; `BACKWARD-CLOBBER`; `COLLISION-UNDETECTED` | structural: uniqueness and monotonic check (the chain-closure tool covers part) | 048, 306, 434, 466. Core |
| LEASEREL | A holder releases an exclusive shared resource on every exit path. | `ABANDONED-LEASE`; `RELEASE-SKIPPED-ON-BLOCK` | structural: lease-age check at preflight | 615. Watch |
| TOOLAVAIL | Every gate or tool a contract names resolves and runs in the executing environment; if not, the chain blocks. | `GATE-ABSENT`; `DOC-DRIFT` (schema doc differs from script behaviour); `UNRESOLVABLE-AS-WRITTEN` (null command); `TOOL-ABSENT` | structural: resolve-before-delegate (ADR-020; tool side `G-T-SCRIPTCOMPLETE`) | 036, 037, 040, 048, 056, 082, 306, 466. Core |

### E. Continuity

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| STATETRUE | The execution record states only confirmed, evidenced transitions, and a resumed chain reconciles it against artifacts before its first delegation. | `ASPIRATIONAL-STATE`; `UNRECONCILED-RESUME`; `DUPLICATE-WORK` (already-complete work redone) | structural: reconcile state against plan frontmatter and existing work-order files at resume | 1, 011-063-070, 585, 615, vsc-batch. Core |

### F. Gates

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| GATEORDER | No gate runs before the earlier gates' artifacts exist, and every gate the repo's precedent includes is in the chain. | `GATE-OMITTED`; `GATE-LATE` (retro written retroactively); `GATE-MISORDER` (cross-plan execution-order deadlock) | structural: existence checks (retro check exists) | 1, 006-010, 191. Watch |
| GATEINTEG | The party being gated cannot widen, exempt or reinterpret its own gate. | `SELF-EXEMPT`; `MECHANISM-MISREAD` (exemption semantics); `GATE-FALSE-POSITIVE` | structural: the bypass-surface check in `code-reviewer.agent.md`; adjudicated for the stated mechanism | 035, 040, 056, 209, 459. Core |

### G. Deferral

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| DEFERHOME | Every item deferred, dropped, waived, excepted or accepted-with-notes, at any stage and in any artifact, has a durable home outside the artifact that records it, with a named owner and a revisit trigger. | `UNOWNED-ROW`; `DEAD-IN-CLOSED-DOC`; `NOTE-DISPOSITION` (closed by a changelog note); `VERDICT-QUALIFIER` (APPROVED WITH EXCLUSIONS or ACCEPT WITH NOTES with no ledger entry); `LIMBO-FINDING` (retro `needs-bulk-review`); `PREPLAN-DROP` (a "later" recommendation with no row); `PHASE-TRUNCATE`; `PARKED-TEST` (xfail, skip, live-DEFERRED); `STATE-ONLY` (recorded only in execution-state) | structural: `check-deferred-homes` (O14). Measured: Q33 | Corpus: 131 of 223 unowned. 434, 585, 615, 636, 645. Core |
| RESURFACE | Before a plan is scoped, the open deferred items touching its area are listed. | `NO-INTAKE-SCAN`; `ID-CITED-NOT-SURFACED` | adjudicated: enumerate open DEFER items by area before reading the draft plan (same shape as `G-D-BLIND`) | ADR-008 W-1; plans 417, 626. Core |

### H. Loop and authority

| ID | Guarantee | Modes | Check | Evidence |
|---|---|---|---|---|
| LOOPCLOSE | A finding observed in a third independent chain is converted into a gate, rule or class, or explicitly rejected, before the fourth. | `WRITE-ONLY-FINDING`; `MEMORY-NOT-APPLIED` (lesson recorded, mistake repeated); `RECURRENCE-UNCOUNTED`; `CLASS-UNMINTED` | measured: `recurrence_count` ≥ 3 with no owner. Structural: auto-stub (O17) | 006-010, 011-063-070, 037-040, 209, 451, 459, 585. Core |
| CLAIMTRUE | A claim of done, green or live state carries its evidence class and follows a verification spend. | `PREMATURE-DONE`; `SOFT-CHECKPOINT` (remaining work presented as a pause); `UNLABELED-CLAIM`; `LOCAL-EXPANSION-MISREAD` (a shell expands locally, giving a false remote reading) | adjudicated. `G-D-ASSERTBYPASS` is the planning-time instance | 164, 434, 443. Core |
| USERCALL | Decisions reserved to the user are neither self-selected nor re-asked once pre-authorized. | `SELF-SELECTED-DEFERRAL`; `REDUNDANT-CHECKPOINT`; `PRESENTATION-LAYER-SKIPPED` | adjudicated | 164, 434, 443. Watch |
| CEREMONY | Process cost is proportionate to the risk and size of the change. | `OVER-CEREMONY` (a lightweight session pays full lifecycle); `UNDER-CEREMONY` | measured: Q29/Q30 against change size | 193, program-082. Watch |
