# vs-code-agents Domain Glossary

> **Owner**: Architect  
> For specific agent or skill names, consult the corresponding `agents/*.agent.md` or `skills/*/SKILL.md` file.

This glossary defines the generic class-of-thing terms that constitute the domain of this repository. Terms here are concepts, not specific instances.

---

## Core Concepts

**Agent**: An AI persona with a specific role, constraints, and responsibilities, defined in an `.agent.md` file. Agents are invoked to perform specialized tasks within a workflow. _Avoid_: Bot, assistant, mode, persona

**Skill**: A reusable capability package that agents load for domain-specific knowledge, templates, or guidance. Skills are defined in `SKILL.md` files within the `skills/` directory. _Avoid_: Plugin, module, extension, helper

**Plan**: A structured document in `.agent-output/planning/` that defines implementation work with requirements, tasks, risks, and acceptance criteria. Plans follow a rigid 16-section template per `structured-labeling` skill. _Avoid_: Spec, design doc, proposal, ticket

**Deferred Item**: Scope explicitly narrowed or withdrawn from a plan's active work, recorded in the plan's required `## Deferred Items (DEFER-*)` section with a "why now" rationale, a revisit trigger, and an owner, so it does not silently drop out of scope unnoticed. `DEFER-*` uses the composite `DEFER-<origin-doc-ID>-<local-seq>` numbering format (mirrors `OPENQ-*`), since a Deferred Item's whole purpose is to be citable from a different, later plan. _Avoid_: cut scope, backlog item, TODO, carry-forward (the ad-hoc, unlabeled forms this label replaces)

**ADR (Architecture Decision Record)**: A document in `docs/adr/` capturing a significant, hard-to-reverse architectural decision. ADRs follow the canonical template in `adr-authoring` skill and use their own numbering space (ADR-001, ADR-002, ...). _Avoid_: Decision log, meeting notes, changelog

**Findings**: A document recording analysis results, architectural review outcomes, or critique observations. Findings docs live in `.agent-output/{analysis,architecture,critiques}/` and inherit the work-chain ID. _Avoid_: Report, notes, summary

**Archaeological Comment**: A reference in a consumer-facing file to this repository's own internal change history — specifically: plan numbers ("Plan 015"), plan names, "Historical note" annotations, and "previously / formerly / renamed from / replaced by" commentary that only makes sense relative to a prior state of _this_ repo. Archaeological comments are banned from consumer-facing files (agents, skills, docs, scripts, root READMEs); they belong in `CHANGELOG.md` or `.agent-output/`. Exempt zones: `.agent-output/`, `CHANGELOG.md`, `docs/adr/`, functional plan-numbering mechanisms, illustrative examples, legitimate domain vocabulary, and embedded provenance/history blocks. See `docs/adr/ADR-014-no-archaeological-comments.md` for the normative rule and full exemption list. <!-- archaeology-ok --> _Avoid_: history note, changelog comment, provenance note

**Execution-State**: A YAML file tracking the current phase, handoffs, and completion status of a work chain. Lives alongside the plan at `.agent-output/planning/<ID>-execution-state.yaml`. _Avoid_: Status file, progress tracker

**Work-Order**: A structured YAML artifact authored by the orchestrating owner before an executor delegation, encoding scope boundaries (allowed and blocked files), per-task acceptance criteria with kind labels (Asserted/Demonstrated), mechanical gate commands, and a blocker-communication channel. Stored at `.agent-output/handoffs/<ID>-<role>-phase-NN.yaml`. See `skills/execution-orchestration/SKILL.md` §Work-Order Contract for the schema reference and authoring procedure. _Delineation_: A work-order is the _instrument_ of a single Handoff, not a synonym for it. It supplements the Execution-State (which remains the chain's single source of truth for phase/task progress) rather than replacing it. Its `scope`, `checklist`, and `gates` fields refine the Delegation Contract but do not replace it. _Avoid_: brief, handoff-doc, task-spec, delegation-checklist

---

## Workflow Concepts

**Triple Gate**: The three-condition test for whether a decision warrants an ADR: (1) hard to reverse, (2) surprising without context, (3) result of a real trade-off. All three must be true. _Avoid_: ADR criteria, decision filter

**Handoff**: The formal transfer of work from one agent to another in a workflow, documented in execution-state and agent outputs. Includes context, deliverables, and acceptance criteria. _Avoid_: Pass, transfer, delegation (when used loosely)

**HARD BLOCK**: A blocking condition that halts work and requires external resolution (user decision, Architect approval, missing information). Returns control to the orchestrator with specific unblock requirements. _Avoid_: Error, failure, pause, wait

**Subagent**: An agent invoked by another agent to perform focused, scoped work. The calling agent maintains orchestration; the subagent returns results without autonomous continuation. _Avoid_: Helper agent, nested agent, child agent

**Orchestrator**: The agent (typically Planner) coordinating a work chain by delegating to subagents, tracking execution-state, and enforcing workflow gates. _Avoid_: Controller, coordinator, manager

---

## Scope Concepts

**Subproject**: A nested codebase with its own lifecycle, defined as either a git submodule or an independent nested project with its own manifest file. Subprojects get their own `CONTEXT.md`. Bounded contexts sharing a single manifest are NOT subprojects. _Avoid_: Subfolder, module, package (when referring to lifecycle scope)

**Alignment Session**: The interactive planning mode that resolves plan ambiguity by working through decisions one at a time, updating `CONTEXT.md` and proposing ADRs as decisions crystallize. Provided by the no-silent-assumptions planning skill's Interactive Alignment Mode. _Avoid_: Planning meeting, requirements gathering, design session

---

## Requirements Enforcement Concepts

**Guarantee**: A single falsifiable clause in a project's guarantee ledger, carrying exactly one maturity (candidate -> plan-local -> adopted -> formal). A guarantee is a project/runtime artifact of a _consuming_ project, governed by the `requirements-enforcement` skill. Distinct from a plan `REQ-*` label: `REQ-*` scopes one plan's work; a guarantee is a durable, maturity-tracked project invariant whose negation defines a failure-mode class. _Avoid_: requirement (unqualified), REQ, invariant (when used loosely), promise

**Guarantee Ledger**: The append-only register of a project's guarantees and their maturities, the source of truth for guarantee statement text (referenced elsewhere by ID only). Lives in the consuming project (recommended `guarantees/LEDGER.md`), not in this distribution repo. _Avoid_: Requirements doc, backlog, spec

**Failure-Mode Registry**: The ledger's enforcement dual: a three-level register of classes (negation of a guarantee), modes (one mechanism, individuated by a single detection oracle), and instances (concrete regressions). Recommended `failure-modes/INDEX.md` in the consuming project. _Avoid_: Bug list, risk register, defect log

**Oracle**: The single detection test that defines a failure mode -- a property/invariant (structural) or a fixed evaluation procedure + corpus + threshold (measured) that catches every instance of the mode, including unseen ones. Distinct from an instance regression test, which only re-detects one known manifestation. _Avoid_: Test (unqualified), assertion, check, regression test

**Defect Escape**: A defect that reached a later phase or production undetected. In QA, every escape is filed through triage and attributed to exactly one bucket (coverage gap / taxonomy gap / contract gap) -- the escape-attribution metric. Not to be confused with information _leakage_ across a module boundary in `deep-modules` (which uses "escape/leak" for a different concept). _Avoid_: Leak / leakage (that is a deep-modules term), miss, slip, bug

**Escape Attribution**: The act of assigning a defect escape to one of three buckets (coverage gap, taxonomy gap, contract gap), whose distribution over time names which layer -- CI wiring, the registry, or the ledger -- is failing. _Avoid_: Triage (broader), root-cause (broader), blame

---

## Live-Access, Citation Fidelity, and Demonstrated-Evidence Concepts

**Live-Access Disposition Rule**: A `structured-labeling` rule requiring any narrative use of defined scarcity/proportionality-judgment vocabulary, applied to a decision about mutating, resetting, configuring, or inserting into a live/shared environment, credential, permission, or data store, to be immediately adjacent to an explicit citation that the user was asked, a `USER-TASK-*` ID, an `OPENQ-*` ID, or a `RISK-*` ID. A bare narrative disposal with none of these adjacent is a template violation, not a style choice. _Avoid_: proportionality check, scope judgment (when referring to this specific rule)

**Citation Fidelity Rule**: A `structured-labeling` rule requiring any citation of another `.agent-output` document's finding that carries a hedge or confidence qualifier to reproduce that qualifier verbatim at first citation in a new document. Generalizes the verbatim-citation discipline already required for composite `OPENQ-*` entries to any hedge-qualified finding, and cross-references `agents/analyst.agent.md`'s Uncertainty Protocol for what counts as a qualifier. _Avoid_: citation check, source fidelity (when referring to this specific rule)

**Demonstrated-Evidence Disposition Rule**: A `structured-labeling` rule requiring any narrative disposition of a `[Demonstrated]` criterion not met at runtime, and any claim offered as grounds for not re-verifying it (an environmental / external / library root cause, an infeasibility claim, a blocker claim, or an "already covered/verified" claim), to be immediately adjacent to differential evidence, a `RISK-*` ID, an `OPENQ-*` ID, a `USER-TASK-*` ID, or an explicit citation that the user was asked. Pairs with `execution-orchestration`'s root-cause-first disposition rule (the owner-side check that a re-verification excuse is proven, not asserted) and `code-review`'s `DEMOGATE-*` review gates (the review-time check). _Avoid_: excuse check, re-verification check (when referring to this specific rule)

---

## Interface Definition Concepts

**Propagation Test**: A deterministic five-probe classifier (Caller-surface, Sibling-coupling, Extensibility, Downstream-inheritance, Oracle-definition) applied to a design choice touching a plan's Contracts section, deciding whether that choice must be written into the section (any probe fires YES) or may be left to the Implementer's discretion (all probes fire NO). Distinct from the Stage-0/Stage-1 ask-worthiness gates in `no-silent-assumptions-software-planning`, which decide whether to ask the user a question at all -- the Propagation Test runs after a choice is already resolved and decides only whether that resolution must be captured in writing. See `no-silent-assumptions-software-planning` and `structured-labeling`. _Avoid_: specify-vs-detail check, contract completeness test (when referring to this specific classifier)

**Claimed-Support Map**: An embedded table (`Claim | Cited source | Structural mechanism | Status`) nested under a `CONTRACT-*` entry when the Propagation Test fires, mapping each claimed interface capability to a real, verifiable citation and the structural mechanism that delivers it. Reuses the existing `CONTRACT-*` label family rather than minting a new global label-prefix family. See `structured-labeling`'s Contracts documentation and `no-silent-assumptions-software-planning`'s ground-truth-first corollary. _Avoid_: capability matrix, traceability table (when referring to this specific artifact)

---

## Example Dialogue

**Dev**: "The Planner created a plan but there's an open question about the API contract."

**Domain Expert**: "Did the plan include an `ADR-PROPOSED-*` label for that decision?"

**Dev**: "No, it's just marked as `OPENQ-001`."

**Domain Expert**: "Then it's an open question, not an ADR candidate yet. The Critic should flag it. If it meets the triple gate -- hard to reverse, surprising, real trade-off -- then Planner should draft an ADR with `Status: proposed` and route it to Architect before implementation proceeds."

**Dev**: "What if the Implementer discovers mid-implementation that a decision needs an ADR?"

**Domain Expert**: "That triggers a HARD BLOCK. The Implementer stops, drafts the ADR, and returns control to the orchestrator. Work resumes after Architect approves the ADR."
