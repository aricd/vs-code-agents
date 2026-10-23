# Changelog

All notable changes to this repository will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 3.25.0 -- 2026-10-22 -- New skills: basis-redesign and obs-create (staged skills)

### Added

- **`skills/basis-redesign/`** (new): a hub `SKILL.md` plus ten stage files under `references/` (intent and scope, catalog, necessity ladder, joint removal, re-imagine, intake constraints, realize, output equivalence, compatibility, report) and `scripts/joint_removal.py` with pytest tests. It re-imagines or compresses an existing DSL, grammar, schema or API vocabulary under a declared output-equivalence oracle and a declared compatibility contract. The skill's Run Declaration fixes `run_goal` (`snapshot`, `compress`, `redesign`), `equivalence_strength` (`hard` or `advisory`), the composition relation and the version notions; the joint-removal script enumerates every inclusion-minimal remaining set as a candidate set only, and stage 08's executed oracle decides finality. `minimal-basis-audit`, from which it was built, was never committed or released, so it carries no migration.
- **`skills/obs-create/`** (new): the OBS (Orthogonal Basis Set) workflow as a skill, one `references/` file per stage. Service-target behavior is unchanged. A new vocabulary-target mode covers Stages 0-4 for DSLs and grammars, adds an old -> new mapping to the tournament's seed schema, and can be entered from `basis-redesign` stage 05. The tournament stage is a standalone file that `basis-redesign` links.

### Changed

- **`skills/skill-authoring/SKILL.md`**: the Repo-Local Convention section gains "Staged skills and cross-skill references" (hub plus `references/NN-<stage>.md`; the hub indexes every file a run reads, including other skills'; must-hold rules stay in the hub; links point to the skill that owns the concept; a stage file is shared only once a second skill links to it; workflows other skills must link to are skills, not prompts, a deployment-policy limit).
- **`prompts/obs-to-mcp-spec.prompt.md`**: references the `obs-create` skill instead of the retired prompt.

### Removed

- **`prompts/obs-create.prompt.md`**: replaced by the `obs-create` skill, with no prompt shim. Skills are slash-invocable, so `/obs-create` keeps working; only the name's case changes from `/OBS-Create`. On Claude Code, re-run `python scripts/link_setup.py --target claude-code` to prune the stale generated `~/.claude/commands/obs-create.md`; until then the skill wins the name clash.

## 3.24.0 -- 2026-10-21 -- deep-modules-interface-cost-audit: Cross-Module/Cross-Batch ILC schema (closes UAT gap)

### Added

- **`skills/deep-modules-interface-cost-audit/references/line-item-yaml-schema.md`**: gains a "Cross-Module Findings" section (`cross_module_line_items`, staged across the same 3 forms as `line_items`, each item requiring a `modules: [...]` field with >=2 entries), with a worked example reusing a real, already-verified finding from a completed 5-file audit (a `router.py`↔`session_db.py` private-method reach-through, reconciled as a `bucketing_dispute` resolved to `ILC`), plus a deliberately non-conformant counter-example demonstrating the new evidence-tuple uniqueness rule fires unconditionally even with zero `cross_module_line_items` entries present. Also gains a "Cross-Batch Findings" section (`cross_batch_line_items`, single reconciled-stage shape, `modules`/`batches` fields each requiring >=2 entries) with one clearly-labeled-hypothetical worked example.

### Changed

- **`skills/deep-modules-interface-cost-audit/SKILL.md`**: Step 3 item 1's cross-module-ILC-check bullet and item 5's Reconciliation step now require `cross_module_line_items` (including the evidence-tuple uniqueness rule and the anti-double-count rule), cross-referencing the extended references file. Step 4's Cross-Batch Assembly and Cross-Batch Assembly Review bullets now require `cross_batch_line_items` the same way. Frontmatter `metadata: version` bumped to `"1.2"`. No Phase-1-shipped prose altered.

## 3.23.0 -- 2026-10-21 -- deep-modules-interface-cost-audit: Candidate-C YAML schema for itemized line-items

### Added

- **`skills/deep-modules-interface-cost-audit/references/line-item-yaml-schema.md`** (new): the full Candidate-C-shaped (Provenance-Rich Audit Trail) `line_items` YAML schema, staged across 3 progressively-populated forms -- raw single-pass (Audit A/B), critique-annotated (Critique A/B, adds only `critique_status`), and reconciled-with-`totals` (Reconciliation, adds `reconciliation` + a script-derived `totals` block) -- each with one worked, illustrative example. The reconciled example represents all 4 `reconciliation.status` values (`agreed`/`omission`/`bucketing_dispute`/`interpretive_disagreement`). The `growth_trajectory` shape is widened beyond analysis 082's own skeleton to the 3-value `evidence_label: Observed|Projected|Hypothesis` enum plus a required `reference` citation field.

### Changed

- **`skills/deep-modules-interface-cost-audit/SKILL.md`**: Step 3 item 1 (Audit A) now requires one YAML code-fence per module per the raw single-pass schema (replacing the prose-only "itemized line-items, never a bare number" instruction); item 2 (Audit B) inherits it via "same instructions." Items 3-4 (Critique A/B) now each require adding a `critique_status` verdict per item from both raw manifests, keyed by `uid`, without altering `proxy_claimed`/`evidence`/`description`. Item 5 (Reconciliation) now requires merging both raw manifests by `uid` (with evidence-tuple fallback), completing `found_by`/`proxy_claimed`, carrying over `critique_status`, filling `reconciliation.status`/`resolved_proxy`/`resolution_note` on every item, and emitting a script-derived `totals` block. The unchanged CHEC->ILC->ISC->RCK precedence rule and Reconciliation Guardrail prose are preserved verbatim. Frontmatter gains a `metadata: version: "1.1"` block.

## 3.22.0 -- 2026-10-21 -- New skill: deep-modules-interface-cost-audit

### Added

- **`skills/deep-modules-interface-cost-audit/SKILL.md`** (new): an orchestrated snapshot-audit procedure applying the `deep-modules` skill's CHEC/ILC/ISC/RCK proxies across a codebase subsystem scoped by a user-stated literal criterion. Step 0 locks the scope criterion and delegation budget; Step 1 is an independent scope-confirmation delegation guarding against silent criterion substitution; Step 2 computes batch count (~15-20 files/batch); Step 3 is a fixed 6-delegation "audit unit" per batch (forward Analyst audit, reverse Analyst audit, forward Critic critique, reverse Critic critique, Reconciliation, Review-of-Reconciliation) with an explicit guardrail against introducing untabulated "adjusted" numbers that contradict a tabulated value elsewhere; Step 4 adds Cross-Batch Assembly + Review when `batches > 1`; Step 5 is the final human-readable report (not a delegation).

## 3.21.0 -- 2026-10-18 -- structured-labeling: RISK-\* Impact/Likelihood annotation

### Changed

- **`skills/structured-labeling/SKILL.md`**: gained the new "Risk Entries -- Impact/Likelihood Annotation (Required for New Entries)" subsection (prospective-only; High/Medium/Low scale; `·`-separated badge ending in a single colon; no em dash), inserted immediately before the existing "FM Exposure" subsection. The `RISK-*` row's Example cell in the Required Label Prefixes table updated to match. Skill `version` bumped to `1.5`.

## 3.20.0 -- 2026-10-14 -- design-rubrics: Lens-Applicability compact-grammar reformat

### Changed

- **`skills/design-rubrics/SKILL.md`**: the required `Lens Applicability declaration` reformatted from the spelled-out `Lens applicability: deep-modules <in|out — reason-if-out> · functional-core <in|out — reason-if-out> · lean-design <in|out — reason-if-out>` string to the compact `Lens[DM<+|-(reason)> FC<+|-(reason)> LD<+|-(reason)>]` grammar, per `ADR-022`. All 5 literal-rendering sites in the Lens-Applicability section updated for consistency: the canonical code block + its reason-placement sentence, the derivation-invariant (C1) table + its flanking prose, the fixed canned-token quote (`FC-(not a within-unit decomposition)`), the Capability Admission Record override paragraph, and the Verbosity-vs-auditability rationale paragraph. `ADR-018`/`ADR-021`'s own frozen citations of the old wording are left byte-unchanged (forward-only adoption, no retroactive rewrite).
- **`docs/adr/ADR-022-lens-applicability-compact-grammar.md`**: `Status: proposed` -> `accepted`.
- **`docs/architecture/system-architecture.md`**: Decisions Index row added for `ADR-022`.

## 3.19.0 -- 2026-10-14 -- skill-authoring: Claude Code and claude.ai conformance

### Changed

- **`skills/skill-authoring/SKILL.md`**: rewritten around a portable contract (the strictest rule across VS Code, Claude Code, and claude.ai/Skills API). Adds what Claude Code accepts silently but other surfaces reject: `---` on line 1, strict YAML (fold descriptions with `>-`), the 1,024-char description limit (Claude Code's 1,536 cap is truncation, not allowance), third-person descriptions with no XML tags, and the six spec-only frontmatter keys for uploads. Also adds Claude Code-specific hazards: unknown keys ignored silently, argument placeholders and inline shell injection live in `SKILL.md`, cwd-relative script paths, bundled-skill name collisions (yours silently replaces the built-in), the `synced` reserved name, compaction keeping only the first 5,000 tokens, and the shared listing budget. The Claude Code section corrects the dynamic-injection syntax. Worked examples moved to `references/worked-examples.md`; Example 3 no longer runs scripts relative to the user's project; new Example 5 repairs invalid YAML and an over-long description. `SKILL.md` goes from 476 to 311 lines.
- **`skills/skill-authoring/references/claude-code.md`** (new): Claude Code skill behavior in full -- locations and precedence, every frontmatter field with portability, parsing failures, invocation control, substitutions and escaping, dynamic injection, content lifecycle, listing budget, subagents, upload rules, and a fresh-session verification procedure.
- **`skills/skill-authoring/scripts/validate_skill.py`** (new): checks one skill or a directory of skills; each finding names the surfaces it breaks. `--upload` makes non-spec keys errors. Against `skills/` it currently reports 7 errors: 5 descriptions over 1,024 chars (`deep-modules`, `design-rubrics`, `functional-core`, `lean-design`, `no-silent-assumptions-software-planning`), an XML tag in `executive-summary`'s description, and invalid YAML in `prototype`. Those skills are not changed here.

## 3.18.0 -- 2026-10-13 -- link_setup.py: claude-code target

### Added

- **`scripts/link_setup.py`**: a target with `format: "claude-code"` generates Claude Code agents (`<target_root>/agents/<name>.md`) and commands (`<target_root>/commands/<name>.md`) from `agents/*.agent.md` and `prompts/*.prompt.md`: lowercase names, VS Code tools mapped to Claude Code tools, `Skill`/`ToolSearch` added, repo-owned paths made absolute. Generated files carry a marker; only marked files are overwritten or pruned, and a hand-written file at a destination gets the existing drift protection.
- **`scripts/test_link_setup_claude_code.py`** (new): standalone oracle for conversion, idempotence, hand-written-file protection, and orphan pruning.
- **`LINKING.md`**: "Claude Code" section (skills via one hand-made `~/.claude/skills` junction; agents/prompts via the generated target; re-run after edits). **`scripts/link-config.example.yaml`**: commented `claude-code` target.

## 3.17.0 -- 2026-10-01 -- New skill: communication-signal-to-noise

### Added

- **`skills/communication-signal-to-noise/SKILL.md`** (new): applies the `deep-modules` interface-cost proxies (CHEC, ILC, ISC, RCK) to chat answers rather than code -- a verbose, heavily-cited, deeply-hedged reply is a shallow communication interface even when every claim is true. Triggers whenever an agent answers a question with an expectation of affecting a plan, actionable status, addressable/fixability, uncertainty, or urgency; headline rule is "resolve, don't narrate."
- **`agents/analyst.agent.md`**, **`agents/planner.agent.md`**, **`agents/critic.agent.md`**, **`agents/architect.agent.md`**, **`agents/security.agent.md`**: each gains a load instruction for the new skill, scoped to conversational findings/status/verdict answers (not the file artifacts each agent already produces, which keep their own Response Style formats).

## 3.16.0 -- 2026-09-30 -- Plan 039 Phase 5: record-keeping and baseline audit

### Added

- **`guarantees/LEDGER.md`**: `G-T-CHAINJOIN-A` (the join behaviour: `check-chain-closure` assigns a document to a chain only by its `uuid`) and `G-T-CHAINJOIN-B` (the corpus property: every chain artifact carries its chain's `uuid`), both `candidate` maturity, split rather than conjoined because the corpus already violates `G-T-CHAINJOIN-B` on day one (instance `.002` below).
- **`failure-modes/FM-T-CHAINJOIN.md`** (new): two modes -- `PREFIX-COLLISION` (instance `.001`, the measured prefix-27 three-chain split, re-verified 2026-09-30) and `MISINHERITED-UUID` (instance `.002`, chain 030's known mis-inherited `UUID`, `DEFER-039-7`, deliberately unrepaired and left open).
- **`failure-modes/INDEX.md`**: `FM-T-CHAINJOIN` registered.
- **`.agent-output/implementation/039-chain-identity-and-closure-implementation.md`** (new): the baseline corpus audit (`TASK-025`) -- `scripts/check-chain-closure.ps1 -Report` run across all 32 live chains, reproducing and updating plan 039 §1's original counts with a dated, mechanical measurement rather than a prose assertion.

## 3.15.0 -- 2026-09-30 -- Plan 039 Phase 4: gated Plan/Apply mutation path

### Added

- **`scripts/check-chain-closure.ps1`** / **`scripts/check-chain-closure.sh`**: `-PlanMoves`/`--plan-moves` writes a closure manifest OUTSIDE the repo tree (default `$TMPDIR/chain-closure/<uuid>-closure-manifest.yaml`), prints a world-bound confirmation token, and changes nothing inside the repository. `-Apply`/`--apply` requires the manifest and token, recomputes the move set and token from the CURRENT observed world (source content hashes, `git rev-parse HEAD`, dirty `.agent-output/` paths minus the infrastructure exemption set), and refuses on any mismatch. Every move uses `git mv` only; an untracked file is skipped and reported, never plain-moved; application is all-or-nothing (a mid-run failure rolls back every already-applied move via `git mv` in reverse); `-Apply` refuses while `.agent-output/` carries uncommitted changes outside the exemption set.
- **`skills/execution-orchestration/SKILL.md`**: Work-Order Contract gains a closure-run gate example -- the `[Demonstrated]` checklist shape whose `entry_point` is the `-PlanMoves` invocation and whose `disconfirm` is "delete the manifest and `-Apply` must refuse."

### Verified (demonstrated against an isolated scratch git repository, never against this repo's own live chain documents)

- `-PlanMoves` changes zero files inside the repo tree; manifest lands outside it.
- Mutating one byte of a queued source file after `-PlanMoves` makes `-Apply` refuse (token mismatch).
- A successful `-Apply` leaves `git status` showing ONLY renames; `git reset --hard` (equivalently `git restore` of the staged renames) fully reverses it.
- An untracked satellite is skipped and reported, never moved.
- `-Apply` refuses while `.agent-output/` has uncommitted changes.
- A forced mid-run `git mv` failure (obstructed destination directory) rolls back the one already-applied move, leaving the tree exactly as found.
- Both `.ps1` and `.sh` arms independently verified against the same scenarios, with matching decisions and messages (tokens are arm-local and not required to be byte-identical across languages).

## 3.14.0 -- 2026-09-30 -- Plan 039 Phase 3: chain-closure report (read-only)

### Added

- **`scripts/check-chain-closure.ps1`** (new): `-Report` mode -- joins on `uuid` ONLY (never filename prefix or path), lists every corpus document carrying a target chain's uuid with its Status, terminal-ness, and co-location, and distinguishes all six REQ-011 outcomes (no uuid; planless; suspected mis-inheritance; ambiguous; destination collision; destination duplicate, including the plan-document form). A `-CorpusRoot` override supports fixture-scoped testing without a second git repository. Default and only implemented mode in this phase is read-only (SEC-001); makes no change of any kind.
- **`scripts/check-chain-closure.sh`** (new): bash port of `-Report`/`--report` at decision, exit-code, and message parity with the PowerShell arm, independently verified against the same fixtures and against the live corpus.
- **`scripts/test-fixtures/chain-closure/corpus/**`** (new): a fixture corpus covering each of the six rules, including reproductions of the real historical `027-execution-state.yaml`destination-collision shape and the real`006-depth-lean-remediation.md`byte-identical-duplicate shape (both already resolved in the live corpus by the time of this implementation, per plan 039's own`DEFER-039-1`/`DEFER-039-2` discharge), plus a happy-path chain with an empty move set.

## 3.13.0 -- 2026-09-30 -- Plan 039 Phase 2: uuid backfill across the YAML corpus

### Added

- **60 YAML chain artifacts backfilled with `uuid`**: 38 `.agent-output/handoffs/*.yaml` work-orders, 12 `.agent-output/planning/*.yaml` (11 open execution-states + `036-mirror-check.yaml`), and 10 `.agent-output/planning/closed/*-execution-state.yaml` files. Each join was made from the file's own `plan_name`/`mission`/`plan_path` text to the plan carrying that name, then independently verified via git commit co-occurrence (or, where the file predates or postdates the co-occurring commit, an independent commit-message cross-reference to the same plan) -- never by re-reading the same text that produced the join. Full per-file join-basis and verification-arm table recorded in `.agent-output/implementation/039-chain-identity-and-closure-implementation.md`.
- **`.agent-output/planning/036-mirror-check.yaml`** and **`.agent-output/mini-retro/policy.yaml`** (REQ-007): explicitly classified rather than left to fall through -- the former backfilled as a chain artifact of plan 036 (join basis: its own header comment), the latter exempted by name as non-chain configuration (it governs every plan's mini-retro uniformly, not scoped to one chain).
- `.agent-output/planning/036-task-017-rebaseline.yaml` left unchanged (already carries markdown-style `ID:`/`UUID:` frontmatter, per plan 039's own explicit exemption).

## 3.12.0 -- 2026-09-30 -- Plan 039 Phase 1: chain-identity schema contract

### Added

- **`skills/execution-orchestration/references/execution-state.schema.md`**: Required Top-Level Fields gain `uuid` (8 hex chars, the chain's authoritative join key, inherited verbatim from the originating plan's frontmatter). The existing `id` field is renamed to `plan_id` as the canonical spelling/type/padding (quoted string, zero-padded to three digits) for newly authored files, with `id` retained as a deprecated backward-compatible alias. Both illustrative examples updated to the new `plan_id`/`uuid` shape.
- **`skills/execution-orchestration/references/work-order.schema.yaml`**: `meta` gains `uuid` (string, REQUIRED, same definition) and a padding/spelling declaration on `plan_id`, scoped to newly authored work-orders only. Inside `meta`, so the file's root-level "top-level keys" comment is unaffected.
- **`skills/execution-orchestration/SKILL.md`**: `Execution-State Artifact` and `Owner pre-delegation steps` gain a chain-identity authoring obligation (`plan_id`/`uuid` inherited verbatim from the plan's frontmatter at creation time), citing the schemas rather than restating the field definitions.
- **`agents/planner.agent.md`**: Work-Order Pre-Delegation step gains the same `meta.uuid` authoring obligation, citing `work-order.schema.yaml`.
- **`skills/document-lifecycle/SKILL.md`**: new "YAML Chain Artifacts" subsection -- a one-line pointer stating YAML chain artifacts inherit `uuid` on the same terms as a markdown document's `ID`/`Origin`/`UUID`, owned by the two schemas above rather than restated as a parallel rule.

## 3.11.0 -- 2026-09-30 -- Plan 037 Phase 4: propagation and diagnosis fold-ins

### Added

- **`skills/mini-retro/references/memory-model.md`**: `fold-in` gains a third value, `upstream-candidate`, plus a new `patches` finding tag (required when `fold-in: upstream-candidate`) naming the shared Tier-1 skill/rule a project-tier practice was minted to harden. The Bulk review & fold-in lifecycle's Promote step gains a dedicated bullet so an `upstream-candidate` finding is aggregated by its `patches` target rather than being consumed by the ordinary `target-tier: project` -> `policy.yaml` path and losing its link back to the shared artifact it patches.
- **`skills/mini-retro/SKILL.md`**: step 5 (tag every finding) documents the `upstream-candidate` fold-in value and points at the memory-model reference for its disposition.
- **`skills/diagnose/SKILL.md`** Phase 3: new standing hypothesis -- deployed-vs-source drift MUST be stated and falsified before accepting any other root cause for a result captured from a deployed/already-running instance, cross-referencing `execution-orchestration`'s differential-evidence standard.

## 3.10.0 -- 2026-09-30 -- Plan 037 Phase 3: owner-side disposition text

### Added

- **`skills/execution-orchestration/SKILL.md`** rule 3: generalised from "an environmental / external / library root cause" to any claim offered as grounds for not re-verifying, retaining the environmental case as the named canonical instance and naming infeasibility/blocker claims as the others; gains a routing line handing planning-time premise verification to `no-silent-assumptions-software-planning`, and two worked micro-examples (one legitimate, one illegitimate) directly beneath it.
- **`skills/execution-orchestration/SKILL.md`** "Demonstrated vs Asserted acceptance criteria": reduced to a cross-reference. The kind table, default-classification rule, hard rule, and the two disqualifying evidence shapes were duplicated here and in `structured-labeling`; `structured-labeling` is now the sole owner, closing the duplicate-definition gap. Grepped both files' current line ranges directly before editing rather than trusting a prior snapshot.

## 3.9.0 -- 2026-09-30 -- Plan 037 Phase 2: Demonstrated-Evidence Disposition Rule and DEMOGATE-\* gates

### Added

- **`skills/structured-labeling/SKILL.md`**: new **Demonstrated-Evidence Disposition Rule**, a sibling of the existing Live-Access Disposition Rule and Citation Fidelity Rule -- any narrative disposition of a `[Demonstrated]` criterion not met at runtime, or any claim offered as grounds for not re-verifying, MUST be immediately adjacent to differential evidence, a `RISK-*`/`OPENQ-*`/`USER-TASK-*` ID, or an explicit citation that the user was asked. Carries an explicit trigger vocabulary and a definitional/quoting exclusion clause. The Acceptance-Criterion Kind section gains the two disqualifying evidence shapes (wiring-bypass, co-derived evidence), cross-referencing the work-order schema's `disconfirm` field and `code-review`'s `DEMOGATE-001` rather than restating them.
- **`CONTEXT.md`**: matching glossary entry under the (retitled) Live-Access, Citation Fidelity, and Demonstrated-Evidence Concepts section.
- **`skills/code-review/SKILL.md`**: new **`DEMOGATE-001`** (independent-arm test for a Demonstrated criterion, including a criterion mislabelled `[Asserted]`) and **`DEMOGATE-002`** (unproven claim used to excuse re-verification) review gates, in the established gate-family format, each backed by exactly one owning rule (`testing-patterns`' oracle-independence standard; `structured-labeling`'s Demonstrated-Evidence Disposition Rule respectively). Routing rules added against `BOUNDGATE-001` and against `CAPGATE-001`/`GROUNDGATE-001`. The Finding Format's gate-ID category rule now lists `DEMOGATE-*` alongside the other four families.
- **`.agent-output/implementation/037-root-cause-first-policy-hardening-implementation.md`** (new): retrospective application of `DEMOGATE-001` to plan 024's real escape and `DEMOGATE-002` to an in-repo corpus, with findings and precision/recall recorded.

## 2026-09-30 -- Plan 056: documentation rot and example sanitization (record-keeping close-out)

### Changed

- **`.agent-output/implementation/056-documentation-rot-and-example-sanitization-implementation.md`** (new). Closes out Plan 056's implementation record; the content edits themselves (mechanical link/markdown/format fixes; renaming and genericizing the `mdt-mcp-proxy-*` files and the `[MDT Exec Probe]` sentinel family; a documented sanitization glossary applied across ADR-005/008/018 and ~10 skill/prompt files; `dorsca1`/`aricd` author-field removal; `failure-modes/*.md` glossary extension) were already made and verified across two prior work-orders -- this entry and the linked doc supply independent re-verification (live TEST-001 through TEST-005 re-runs, plus a representative spot-check of claimed edits against current file content) rather than trusting recorded evidence text alone. One genuine, out-of-scope discrepancy was found and flagged, not silently fixed: 5 `axis-mcp` mentions introduced 2026-09-28/29 by an unrelated later feature (predating none of Plan 056's own work) reproduce a term this plan's glossary otherwise fully retired.

## 2026-09-30 -- Plan 055: FM-D-ASSERTBYPASS hardening (record-keeping close-out)

### Changed

- **`.agent-output/implementation/055-fm-d-assertbypass-hardening-implementation.md`** (new). Closes out Plan 055's implementation record; the code/prose edits themselves (`agents/critic.agent.md`'s `SRH-3` widened trigger + three illustrative claim-shape examples; `skills/no-silent-assumptions-software-planning/SKILL.md`'s trigger-word list + worked example) were already made and verified in a prior session -- this entry and the linked doc supply the missing paper trail, with file:line evidence re-verified against current content. `TASK-005` (promotion decision checkpoint) is confirmed already resolved (keep `candidate` maturity); `TASK-006` (registry promotion) remains correctly deferred and unexecuted.

## 2026-09-26 -- Run-to-target orchestration contract

### Changed

- **`skills/execution-orchestration/SKILL.md`**: new **Run-to-Target Contract**. It replaces the interim "continuous execution" clause, whose third stop condition (an unresolved decision with no safe default) still let ambiguity halt a run.
  - **Run target.** An approved instruction such as "until closed and fully committed locally" is recorded verbatim, and every plan in the run is orchestrated to it.
  - **Status updates.** Plan start and plan completion are announced as status lines, never as questions or permission requests. A turn may not end while the target is unreached, unless a legal stop applies.
  - **Stop reasons.** There are exactly two agent-initiated stop reasons: `hard-block`, and `unapproved-deferral` (avoiding a block would require deferring, waiving or weakening scope the user has not pre-approved for deferral). Pre-approved deferrals proceed without stopping.
  - **Ambiguity Resolution Ladder.** Ambiguity is never a stop reason. It goes to an Analyst (from the run's budget); if unresolved, then to a Critic frame challenge (false constraints, measurement, solution space, stated vs assumed); and only on a `confirmed-block` verdict to a hard block.
  - **Standard Hard Block Format** gains `Stop Reason`, `Ladder Evidence` and `Deferral Needed` fields.
- **`skills/execution-orchestration/references/execution-state.schema.md`**:
  - new optional `run_target` object (verbatim text, target state, items, pre-approved deferrals, ambiguity-resolution log);
  - optional blocker fields `stop_reason`, `ladder_evidence` and `deferral_needed`.
- **`agents/planner.agent.md`**: new mandatory "Run to target -- never ask to continue" orchestration rule pointing at the contract.
- **`agents/critic.agent.md`**: new **Frame-Challenge Delegation** section, the one sanctioned exception to pre-implementation-only review. It defines the brief's four challenge areas, the output path, and the three-verdict return.

## 2026-09-26 -- backlog-grooming skill

### Added

- **`skills/backlog-grooming/`** (new, manual-only via `disable-model-invocation: true`; invoke with `/backlog-grooming` from the Planner agent). A goal-anchored portfolio review of every open plan. It works in stages:
  - classifies open items as fact / design / user / settled;
  - resolves facts through batched Analyst delegation (the Planner's 10-delegation budget, then asks);
  - scorecards design items via `design-rubrics`;
  - runs eight mandatory checks (`references/grooming-checks.md`): code trace, ADR overlap, demonstration feasibility, supply-and-demand necessity, side effects, internal consistency, approval-state consistency, recorded-decision conformance;
  - applies only mechanical fixes;
  - builds a dependency DAG over the plans (hard edges, soft edges from shared files/seams, and decision gates) and recommends a **serial** execution order. Ties are broken by goal priority, readiness, unblocking power, risk retirement, then size. The order is shown as a table with a start gate and a "why this position" for each plan. Cycles are reported as Blocking findings. Parallel waves are produced only on user request;
  - writes a decision packet (`assets/decision-packet-template.md`) to `.agent-output/critiques/`, with a readiness board, the execution-order table and batched user decisions;
  - stops for the user, then folds the recorded decisions on reply.
- **Why a skill and not a prompt:** skills are discovered system-wide through the `~/.agents/skills` link, while prompts have no system-level discovery location (README, Quick Start note). `disable-model-invocation: true` keeps it out of automatic routing.
- **New Skill Gate:**
  - Overlapping skills are reused, not extended. `plan-status-reporting` is a read-only status snapshot with no delegation or decisions. `design-rubrics`, `execution-orchestration` and `no-silent-assumptions-software-planning` supply the scorecard, the delegation contract and the routing gate.
  - The cross-plan, goal-anchored grooming workflow has no existing home.
  - With manual-only invocation, the new skill adds no automatic routing surface.

## 2026-09-24 -- Plan 050: Propagation Test and Claimed-Support Map

### Added

- **`docs/adr/ADR-021-propagation-test-and-claimed-support-map.md`** (new, `Status: proposed`). Records the decision to add a deterministic five-probe Propagation Test classifier and a companion Claimed-Support Map artifact, single-owned by `no-silent-assumptions-software-planning`, reusing the existing `CONTRACT-*` label family, with mechanical validator enforcement deliberately deferred in favor of Critic-semantic enforcement first.
- **`CONTEXT.md`**: new `## Interface Definition Concepts` heading defines "Propagation Test" and "Claimed-Support Map" as canonical domain terms, cross-referencing `no-silent-assumptions-software-planning` and `structured-labeling`.
- **`skills/no-silent-assumptions-software-planning/SKILL.md`**: new "Propagation Test" section (positioned directly after the existing Proposed Contract concept) -- the five-probe table (Caller-surface, Sibling-coupling, Extensibility, Downstream-inheritance, Oracle-definition), the any-YES->SPECIFY / all-NO->DETAIL rule, the static-verifiability and ground-truth-first corollaries (each with a self-contained worked example), and a "Distinction from the OPENQ-emission gates" callout naming Stage-0/Stage-1 explicitly.
- **`skills/design-rubrics/SKILL.md`**: short cross-reference paragraph near the "Which rubric?" routing table naming the Propagation Test as the sibling gate deciding definition-completeness, distinct from this file's own framing-format router; the five-probe table is not duplicated here.
- **`skills/structured-labeling/SKILL.md`**: new "Claimed-Support Map -- Conditional Subsection within Contracts" documents the conditional `#### Claimed-Support Map` table format, the citation-grounding rule, the legal `None -- Propagation Test: all NO` form, the mandatory one-line Propagation Test disposition statement on every `CONTRACT-*` entry regardless of outcome, and the self-delivering-plan citation pattern, with a worked example. A new Numbering Rules note confirms no new global label-prefix family is minted, citing the collapsing `deep-modules` lens by name.
- **`agents/critic.agent.md`**: new `SRH-11 -- Claimed-Support Traceability` heuristic, format-matched to `SRH-1`..`SRH-10` (High only, no promotion path), covering both a missing/mechanism-less Claimed-Support Map and a `CONTRACT-*` entry with no disposition statement at all; distinguished explicitly from `SRH-3`/`SRH-4`. One line added to the step-5 template-validation checklist cross-referencing the (semantic, not mechanical) Claimed-Support Map presence check.
- **`agents/planner.agent.md`**: the "Deep-Modules Orchestration" line and Process step 5 now run the Propagation Test whenever drafting or revising a `CONTRACT-*`, and emit the Claimed-Support Map when it fires -- pointer only, no duplication of the five-probe table.

## 3.8.0 -- 2026-09-20 -- Plan 033 Phase 6 (final): recurrence memory and intake

### Added

- **`failure-modes/INDEX.md`**: added `recurrence_count` and `last_seen` columns to every row, with a header note defining them. `document-lifecycle`'s Agent Self-Check gains a consult-and-append hook: before treating a process/infra defect as new, an agent checks the registry for a matching row and increments `recurrence_count`/`last_seen` instead of filing a fresh finding. `skills/mini-retro/references/memory-model.md`'s Bulk review & fold-in lifecycle now requires citing the promoting plan's ID and treats a match against an existing registry row as an increment, not a refile. No `KNOWN-ISSUES.md` was created -- the failure-mode registry remains the single home for this class of defect.
- **`agents/pi.agent.md`**: Phase 1 now accepts `*-fold-in-candidate-analysis.md` documents as input, alongside mini-retro artifacts. Closure rule: an in-repo candidate closes into `.agent-output/analysis/closed/` once its disposition is recorded; a consuming project's own candidate document is never moved by this repo's PI agent -- disposition is recorded, not enacted, across a repo boundary this agent does not own. (Verified `agents/retrospective.agent.md` is absent -- Plan 036 TASK-014's removal already landed -- before layering this in.)
- **`skills/mini-retro/SKILL.md`**: `Authorship`/`authorship` field admits a third value, `resumed` -- a chain handed off mid-execution to a different orchestrating context that lived part of it first-hand and reconstructs the remainder, distinct from pure `reconstructed`. Grounded via a workspace-wide grep for the enum's `first-hand | reconstructed` definition pattern before editing (3 files carry it: `skills/mini-retro/SKILL.md`, `skills/mini-retro/assets/mini-retro-template.md`, `skills/mini-retro/assets/brainstorm-retro-template.md`) -- `resumed` added to all 3 definition sites.

This is the final content-phase of Plan 033 (`verification-discipline-hardening`). All eight checklist items' content is complete and direct-read-verified. `GOAL-007` (Phase 6) is **complete** -- `BLK-033-P56-1` (a scope-declaration conflict between `scope.blocked_files`' blanket `"agents/"` entry and `scope.allowed_files`' explicit `"agents/pi.agent.md"` entry) and `BLK-033-P56-2` (a missing implementation-doc scope entry) were both Planner-dispositioned same day; the work-order's gate re-ran clean (exit 0) and the plan moved to Code Review, QA, and UAT. **Correction, 2026-09-20 (QA finding, document-lifecycle Correction Propagation):** this entry originally said the two asset templates were "a known residual gap for a follow-up task" and that `GOAL-007` was held at `blocked` -- both were closed out the same day (see commit `3e2dd63`) but this entry was never updated to match. Corrected in place rather than silently rewritten.

## 3.7.0 -- 2026-09-20 -- Plan 033 Phase 5: correction propagation, oracle independence, failure-path posture

### Added

- **`skills/document-lifecycle/SKILL.md`**: new **Correction Propagation** subsection -- a correction MUST reach the document it corrects via a dated in-place amendment or a `Corrected-By:` frontmatter pointer. `Corrected-By:` (optional) is now shown in §Document Header Format's YAML example, closing the gap where `CONTRACT-003` promised the key but no earlier task had added it to the header block.
- **`skills/testing-patterns/references/testing-anti-patterns.md`**: new **Anti-Pattern 7: Blind Differential Oracle** -- a differential/equivalence oracle comparing two arms mutually derived from the same source is blind to a shared bug; at least one arm MUST be grounded in independent truth (spec-derived value, invariant, or third-party reference). Cross-referenced from a new **Oracle Independence** subsection in `skills/testing-patterns/SKILL.md`, and added to the anti-patterns Quick Reference table.
- **`skills/no-silent-assumptions-software-planning/SKILL.md`**: new **FAILURE-PATH POSTURE** soft-default domain (parallel to the existing PERFORMANCE POSTURE) -- plans must state a default failure-path posture (surface the error, no silent swallow/retry-forever, no dedicated recovery machinery unless required) and ask once for any specific requirement.

## 3.6.0 -- 2026-09-20 -- Plan 033 Phase 4: mechanical registry scope and collision detection

### Added

- **`scripts/check-plan-scope-collision.ps1`** / **`.sh`** (new): read-only, pre-draft checker that detects a shared Files-registry entry between a plan document and every other non-closed plan document under a scanned planning directory, minus a declared registry/shared-infrastructure exemption set (the guarantee ledger, the failure-mode index, the changelog, the version manifest, and the validator scripts). A strikethrough-wrapped registry-entry id (already withdrawn/transferred elsewhere) contributes nothing. Never writes to any file it scans. Both arms accept an optional `-Explain`/`--explain` flag.
- **`scripts/test-check-plan-scope-collision.ps1`** (new): fixture-and-regression runner for the checker above, exercised against both the `.ps1` and `.sh` arms in isolated, hermetic scratch directories. 8/8 cases pass: a non-exempt shared entry is flagged as a collision; an entry shared only from the exemption set is not; no-overlap and missing-target-file controls; a withdrawn entry is not counted; a colliding plan placed under a `closed/` subdirectory is ignored.
- **`scripts/test-fixtures/collision-plan-shared-nonexempt-{a,b}.md`** and **`collision-plan-shared-exempt-only-{a,b}.md`** (new): the committed fixture pairs the checker's harness copies into per-case scratch directories.
- **`skills/execution-orchestration/SKILL.md`** §Owner pre-delegation step 6: raised from "at minimum two gates" to "at minimum three", naming a collision gate that runs `scripts/check-plan-scope-collision.{ps1,sh}` against the plan document a phase touches -- already a plain `pwsh`/`bash` command, so no change to the gate runner's allowlist was needed.
- **`skills/no-silent-assumptions-software-planning/SKILL.md`**: new **Pre-Draft Files-Registry Collision Check** subsection -- the Planner-side complement to the mechanical gate above, run against a plan's `FILE-*` section before it is finalized.
- **`docs/VALIDATOR-PARITY-CHECKLIST.md`**: restructured under a new "Plan-Template Validator" H2 (wrapping the prior top-level CLI Contract / Validation Rules Enforced / Required Sections / Traceability Map Validation Rules / Parser and Runtime Boundary Rules / Behavior Differences content as H3 subsections), sitting alongside the pre-existing "Work-Order Gate Script" and "Smoke-Test Plugin Parity" H2 siblings. The new checker's own CLI Contract and rules table are added under Plan-Template Validator (a pre-draft/collision tool, not a work-order gate). Both Plan-Template Validator and Work-Order Gate Script now carry a Testing Parity list.

## 3.5.0 -- 2026-09-20 -- Plan 033 Phase 3: work-order authoring integrity

### Added

- **`skills/execution-orchestration/SKILL.md`** §Owner pre-delegation steps: new **re-diff rule** (`REQ-011`) -- when the plan has changed in-session, the owner MUST re-read the plan's current ratified section before authoring the delegation checklist, rather than proceeding from a summary or an earlier revision.
- **`skills/execution-orchestration/SKILL.md`** §Owner COMPLETE-acceptance step: new **record-completeness** obligation (`REQ-012`) -- documentation/changelog completeness (e.g. the phase's `CHANGELOG.md` entry, `plugin.json` bump) is part of the same acceptance bar as functional correctness, not a follow-on check.
- **`skills/execution-orchestration/references/work-order.schema.yaml`**: new OPTIONAL root-level `carried_forward_context` field (`REQ-013`), additive and ignored when absent per `BACKCOMPAT-001`. The file's "exactly these six" root-key header comment is updated to seven.

## 3.4.0 -- 2026-09-20 -- Plan 033 Phase 2: Grounding Rule, GROUNDGATE-001, two-signal completion

### Added

- **`skills/structured-labeling/SKILL.md`**: new **Grounding Rule** (`REQ-007`) -- any exhaustiveness or absence claim ("no failure modes registered", "all callers updated", "zero instances found") MUST be immediately adjacent to the literal command executed and its literal result, structured like the adjacent Live-Access Disposition Rule (trigger vocabulary table, required-evidence form, worked example). Also corrects the file's stale meta-repo FM Exposure instruction, which still said `none -- not bootstrapped` though both `guarantees/LEDGER.md` and `failure-modes/INDEX.md` now exist.
- **`skills/code-review/SKILL.md`**: new **`GROUNDGATE-001`** review gate (`REQ-008`), the review-time check for the Grounding Rule, with the ground-truth-first obligation in its severity calibration (HIGH when the claim concerns code behaviour and the review chain has reached round 3+ with no ground-truth grep on record). States explicitly that `GROUNDGATE-*` is backed by exactly one owning rule, preserving the family invariant `BOUNDGATE-*`/`LIVEGATE-*`/ `CITEGATE-*` all satisfy. Adds `REQ-023.4`: the originating gate ID MUST appear in `[Category]` of the Finding Format, making `grep -r GROUNDGATE-001 .agent-output/code-review/` the aggregation query.
- **Two-signal completion rule** (`REQ-009`) landed in its three homes: canonical statement in `skills/document-lifecycle/SKILL.md` §Terminal Statuses (new "Two-Signal Completion Rule" subsection, citing `FM-T-OPENQGATE`, the Critic's own rev-0 single-signal review of this plan, and this plan's own `Critic_Approved: true` as in-repo instances); authoring obligation added to `skills/execution-orchestration/SKILL.md` §Owner pre-delegation steps; one row added to `skills/code-review/SKILL.md`'s Critic Plan Completeness table.

## 2026-09-20 -- Plan 033 Phase 1: gate correctness, resolution, and observability

### Fixed

- **`scripts/run-work-order-gates.ps1` / `.sh`.** The file-scope gate's change source is now `git diff --name-only <base_commit>` plus a `git status --porcelain` untracked/rename query, never `--stat` (which both abbreviates long paths for display and cannot see untracked creations at all). Handles git's quoted-rename form (`R "old" -> new`) on both sides, disables path octal-escaping (`core.quotepath=false`), and pins every git invocation to the resolved repo root (`git -C <root>`) so behaviour is independent of the script's own launch directory. `scope.allowed_files`/`scope.blocked_files` entries are interpreted in a canonical, repo-root- relative path frame (`CONTRACT-004`): a workspace-root-prefixed entry (nested-repo layout) resolves correctly, and an entry that cannot resolve under the repo root at all is a hard error naming the entry, never a silent skip.
- **`scope.blocked_files` is now enforced**, evaluated BEFORE the allowed-list check (so a path declared in both fails as blocked, not passes as allowed), with a distinct `ERROR: blocked file: <path>` message. Checked regardless of gitignore status -- a gitignored blocked path is compared directly against its `base_commit` content via `git show`, not inferred from `git status`, which silently omits ignored paths. A new infrastructure-exemption set (starting with `.agent-output/.next-id`) is consulted before either scope list, so a delegation's own record-keeping counter bump never self-blocks.
- **`meta.base_commit`** is now a required work-order field: the gate anchors to it instead of a moving `HEAD`, so anything committed mid-delegation is still visible to the diff. Absent (older work-orders): falls back to `HEAD` with an explicit `[WARN]`, never silently.
- **`disconfirm` is now machine-checked** for every `kind: Demonstrated` checklist item (plain scalar, `>`/`|` block scalars, and an absent key all parsed correctly), evaluated AFTER the existing `entry_point` check, with its own distinct `ERROR: Demonstrated item <id> missing disconfirm` message. This closes a gap that existed since Plan 024: the schema, an accepted ADR (`ADR-004`), and `REQ-004` all required the field, but neither gate arm ever read it. Folded from Plan 037 per `DECISION-006`.
- **Observability.** An opt-in `-Explain`/`--explain` flag (off by default) prints the resolved repo root, the literal git commands run, and each `allowed_files` entry paired with the path actually compared. The gate scripts track exit code/command/root in-memory per gate for this reporting. A gate command naming an allowlisted-but-not-installed binary, or one whose `Invoke-Expression`/`eval` produces no exit code at all, is now distinguished explicitly from a genuine non-zero gate failure rather than silently treated as pass or an ambiguous failure. YAML double-quoted-scalar escapes (`\"`, `\\`) in a gate `command:` string now decode correctly instead of reaching the shell as literal backslashes.
- **`docs/adr/ADR-004-work-order-handoff-artifact.md`** amended (dated, in place): the documented nine-prefix command allowlist is corrected to the implemented eight (`Select-String` was never actually allowlisted), and the "first-level defense... residual trust-boundary" framing is corrected to state plainly that the allowlist is a typo/mistake guard, not a trust boundary (`DECISION-001`/`SEC-001`) -- work-order authors already hold repo-write access. The dead `Select-String -Path` command-parsing fallback in the label-audit check (for a gate with no `paths[]` list) is removed; `paths[]` is now required for every `label_audit` gate.
- **`docs/VALIDATOR-PARITY-CHECKLIST.md`.** New "Work-Order Gate Script" section supersedes the `# KNOWN GAP: disconfirm is not validated here` comment block that shipped in both gate arms with the Plan 036 merge -- its claim that the field "is enforced through Code Review, not this script" named a gate (`DEMOGATE-001`, Plan 037) that did not exist when the comment was written. `work-order.schema.yaml`'s `disconfirm` comment (L109-112) is corrected to match `entry_point`'s (now that both are enforced, the prior asymmetry -- one field said "enforced", the other did not -- is stale).
- **`failure-modes/INDEX.md`.** Corrected a mode-ID collision discovered while registering this phase's own findings: the existing `FM-T-WOSCOPE` row described Plan 038's `REQ-013` (an unrelated `validate-plan-template.*` FM-registry-citation rule), not the work-order-gate mechanism at least 15 other planning/architecture documents already use the name for. The row is corrected to Plan 033's own `G-T-WOSCOPE` mechanism; Plan 038's mechanism is preserved, unchanged in substance, under its own distinct ID, `FM-T-FMCITE`. Plan 038's own closed artifacts are untouched.

### Added

- **`scripts/test-run-work-order-gates.ps1`** (new). Fixture runner: every static YAML fixture under `scripts/test-fixtures/` plus new hermetic, temp-git-repo-backed scenarios for untracked creation, blocked-file enforcement, the infrastructure exemption, quoted renames, non-ASCII paths, gitignored declared paths, a realistic long path, the nested-prefix canonical path frame, and a valid control -- each run against BOTH the `.ps1` and `.sh` arms independently, and the disconfirm/untracked-violation cases additionally asserted red-against-the-pre-fix-script (materialized live from `git show HEAD:...`) and green after.
- **`scripts/test-property-oracle.ps1`** (new). Two generative property oracles: `G-T-WOSCOPE` (random change-sets checked against an independently-computed reference verdict) and `G-T-DEMODISCONF` (the full `kind` x `disconfirm`-representation x arm space, including representations no fixture covers).
- **`scripts/test-fixtures/invalid-work-order-{missing,absent,empty}-disconfirm.yaml`, `valid-work-order-block-scalar-disconfirm.yaml`** (new). `invalid-work-order-missing-entry- point.yaml` repaired to carry a non-null `disconfirm`, restoring single-rule failure.
- **`guarantees/LEDGER.md`**: `G-T-WOSCOPE`, `G-T-DEMODISCONF` minted (candidate).
- **`failure-modes/FM-T-DEMODISCONF.md`** (new), registered in `INDEX.md`. `FM-T-OPENQGATE.md` gains instance `.003`, pinned on the composite-OPENQ-ID-collapse mechanism per Plan 033's own FM Exposure wording.
- **`docs/adr/ADR-020-mechanical-gate-resolution-and-distribution.md`** (new, `Status: proposed`). Records the gate-resolution contract (workspace `scripts/` -> linked `scripts/` -> `blockers[]` HARD BLOCK) and states the command-allowlist trust posture verbatim (`DECISION-001`/`SEC-001`). Numbered `020`: `019` is contested by Plan 040's own open task, and `016`-`018` are already taken (`016` was reassigned to an unrelated decision after Plan 033 first reserved it).
- **`skills/execution-orchestration/SKILL.md`**: Work-Order Contract rewritten to the gate-resolution contract above; the waiver rule (`status: waived` requires owner sign-off AND non-null `evidence`) is now stated explicitly rather than implied by the schema alone.

### Fixed

- **`skills/code-review/SKILL.md`**: restored the "Free Function vs Method Rule" checklist item (+20 lines), un-propagated content that existed in the deployed tree's `origin/deep-and-lean`-derived snapshot but in no git ref. Recovered verbatim via `git show 5c80df3^:_incoming/agents-skills-snapshot-2026-09-02/code-review/SKILL.md` (the commit before `_incoming/`'s deletion) and classified Additive per `DECISION-008`.
- **`skills/mermaid-diagrams/references/syntax-rules.md`**: restored the literal-quote (`#quot;`) rule block (+19/-4 net), same provenance and classification.
- **`skills/mermaid-diagrams/SKILL.md`**: renumbered the quick-syntax-rules cross-reference (+3/-1) to match the restored `#quot;` rule; the neighbouring main-only previewer-caveat bullet was left untouched (not part of the residue).
- **`skills/functional-core/tools/tests/README.md`**, **`skills/functional-core/tools/tests/requirements-dev.txt`**: ported verbatim from `tools/tests-incoming/`, which retained these two files with no `tools/tests/` counterpart. All 7 other `tests-incoming/` files were re-verified byte-identical to their `tests/` counterparts by SHA-256 (not the prior 3-file spot-check); `tests-incoming/` was then deleted in its entirety.

This is the Phase 0 residue identified by `DECISION-008`'s reopening of `TASK-027`/`TASK-028` (the origin/deep-and-lean branch itself was already merged into `main` under Plan 036/v3.0.0; this entry covers only the narrow content gap a Planner-commissioned Analyst re-baseline found still open). No `Conflicting` or `Removal`-classified item was found in this residue.

## 2026-09-20 -- Plan 033 Phase 1 closeout: TEST-010/TEST-SCOPE-003 executed, REQ-004 discharged

### Fixed

- `ADR-020-mechanical-gate-resolution-and-distribution.md` accepted by the Architect, unblocking `TEST-010`/`TEST-SCOPE-003` -- the plan's own stated marquee-value test ("a work-order gate that actually executes and actually exits non-zero on a real scope violation, in the consuming workspace"). Executed entirely against a scratch target directory and a throwaway config file under the OS temp folder; `scripts/link-config.yaml` and `~/.agents/skills` were never touched. A dry-run (`--check`) was inspected before any real link was created (27 would-link destinations, all under the scratch target, 0 drift, 0 failed); the real link produced a genuine hardlink/junction (verified via `fsutil hardlink list` and `LinkType`), not a copy; and the linked gate script, run from inside a throwaway git repository nested under the scratch target, correctly resolved its own repo root and exited non-zero (`ERROR: out-of-scope file: violation.txt`) against a declared scope violation. `REQ-004` is fully discharged; Phase 1 (`GOAL-001`) is complete.

## 2026-09-20 -- Plan 033 Phase 1 defect fix: `BLK-TEST010-1` (untracked blocked-path false positive)

### Fixed

- **`scripts/run-work-order-gates.ps1` / `.sh`.** `Test-DeclaredPathTouched` / `test_declared_path_touched` unconditionally reported any existent, never-git-tracked `blocked_files` path (e.g. the deliberately gitignored `scripts/link-config.yaml`) as "touched" on every run, regardless of whether the delegation being gated actually created or modified it -- found by `TEST-010`'s own honest self-check (`033-impl-phase-01-test010.yaml`). Fixed at the root cause: the function now compares such a path's own last-write-time against `meta.created` (already a required ISO-8601 field) to distinguish "existed before this delegation" from "created/modified during it". Four new hermetic regression cases in `scripts/test-run-work-order-gates.ps1` prove both directions on both arms; fixture suite now 53/53 PASS (was 49/49), property-oracle suite unchanged at 73/73 PASS. Independently re-reproduced fixed against the real `scripts/link-config.yaml` via an isolated diagnostic work-order.
- `TASK-011`'s plan-table row flipped `in-progress` -> `complete` (`ADR-020` was already accepted by the Architect; the row had not been updated to reflect it).

## 2026-09-19 -- Subproject-prefixed ADR identifier convention (opt-in)

### Added

- **`skills/adr-authoring/SKILL.md`.** New "Subproject-Prefixed ADR Identifiers (Multi-Module/Multi-Service Consumers)" section defines an opt-in `ADR-<SUBPROJECT>-NNN` identifier format for a consuming repo whose own local ADR sequence spans multiple modules or services (e.g. `example-mcp`'s `EXAMPLEMCP` prefix, forking away from a shared/root sequence). Numbering is an independent per-prefix max-plus-one scan, identical in mechanism to the base convention, just scoped to files matching the chosen prefix. Adoption is opt-in only -- triggered exclusively by (a) a brand-new local sequence, or (b) an existing repo's own explicit, user-directed, one-time conversion of its entire sequence -- never silent, retroactive, or partial. Pure insertion: the base "ADR Location & Numbering" section is unchanged, and `vs-code-agents` itself (single-context, per `ADR-001`) continues using plain `ADR-NNN`, including for this ADR.
- **`docs/adr/ADR-018-subproject-prefixed-adr-identifiers.md`** (new, `Status: accepted`). Ratifies the convention; records the opt-in-only activation trigger and the rejected mandatory- and silent-application alternatives.
- **`docs/architecture/system-architecture.md`.** Decisions Index row added for `ADR-018`.

## 2026-09-19 -- OPENQ-resolution and required-section-presence validator fix

### Fixed

- **`scripts/validate-plan-template.ps1` and `scripts/validate-plan-template.sh`.** OPENQ resolution detection is rewritten to a single unified rule shared by both validators: entry-scoped (only rows/list items inside the Open Questions section are scored), composite-id aware (`OPENQ-<origin>-<seq>` ids are tracked intact, never collapsed to their shared origin), and per-line (the separator run structurally excludes `\r`/`\n` and any other `OPENQ-` id, so a match can never cross a line or borrow a different entry's resolution marker). An id referenced anywhere else but never declared as an entry now raises a warning ("undeclared OPENQ reference") instead of hard-gating the plan. Required-section presence is anchored to each section's heading pattern only, never a bare label-prefix or prose mention elsewhere in the document; the dead unanchored `$RequiredSections[].Pattern` and `$LabelPrefixes` structures are removed. A missing required section now WARNS (instead of ERRORS) when the plan's `Status` is terminal or the file lives under `closed/`. Bash gains the same 15 anchored heading patterns (previously a prose comment only) and the same line-sorted section-ordering check PowerShell already had, closing a standing PowerShell/Bash divergence. A new WARNING rule fires when a plan's FM Exposure declares FM ids but neither `guarantees/LEDGER.md` nor `failure-modes/INDEX.md` is cited in Files. Eight new fixtures under `scripts/test-fixtures/openq-*.md` plus a fixture pair for the FM-registry-citation warning rule capture each defect red-then-green; both binaries were run independently against every fixture and against the full `.agent-output/planning/**` corpus with zero new false failures.

## 2026-09-17 -- BL-7 gate run; failure report filed; tooling closeout

### Added

- **Analysis 043 — the deferred cross-axis corpus re-score.** Analysis `263` raised it as its own Open Question 1 with owner `TBD` and never ran it; report `268` made it BL-7's precondition and also did not run it. Run now: 5 scorecards, 790 lines. **Verdict: build BL-7 — and the gate's own criterion is defective.** "How often would a note flip a verdict" is unrunnable here: four of five scorecards are not A-vs-B comparisons (`216` says so itself — _"single artifact scored, not two designs compared"_), so the measure returns ~0 from corpus shape, not from absence of the phenomenon, and run literally would have retired BL-7 on a false negative. What the corpus does show is the mechanism already improvised in three phrasings, the third self-citing _"this document's own convention (Reg §ILC precedent)"_.
- **Analysis 044 — option-framing omission failure report.** User-reported, not detected. Ten decisions presented with two or more options across one session; zero carried the framing two ambient skills require, while the agent was editing both. Root cause: an ambient obligation stored inside a file that must be loaded to know it is ambient cannot fire for an agent that has not loaded it — the shape ADR-016 already diagnosed and fixed once. Records assumed context (opaque labels, unstated provenance, effort by analogy) as a second, currently unowned obligation.
- **Plan 045 (stub)** — secondary-burden annotation, unblocked by 043, held at stub because 043 recommends restating its acceptance criterion first.
- **Plan 046 (stub)** — option-framing activation, scoped around root cause; `OPENQ-046-1` (can any hook observe a chat response?) is sequenced first because it may invalidate most of the scope.

### Fixed

- **`make list` / `verify` / `clean` POSIX assumptions.** `list` and `verify` walked target roots with `find`/`readlink`, reporting nothing and exiting clean on Windows — an operator reads "Verification complete" from a check that never ran. Both now delegate to `link_setup.py --check`, which is cross-platform, understands junctions, and detects content drift the link walk could not see at all. `clean` stays POSIX-only but refuses loudly instead of silently no-opping; the `2>/dev/null || true` that swallowed every error is gone.

## 2026-09-17 -- Report 268 backlog complete through Phase 2

### Changed

- **Bucket precedence is convention, not severity** (268 BL-3). The counting convention justified _having_ an order ("keeps the buckets mutually exclusive and the total free of double-counting") but not _this_ order, since any order achieves both. Owner confirmed conventional; the text says so rather than adopting 268's parenthetical guess at a severity rationale. Two findings the question surfaced are now recorded: only **CHEC-before-ILC** was ever a free choice (ISC takes what is "not already CHEC/ILC", RCK what is "NOT visible in the signature", so both are residual by construction), and precedence **selects the prescribed remedy** via ADR-003's proxy→guideline mapping while `TOTAL` stays identical. The order is deliberately stable: reordering would move cross-axis items between buckets and break comparability with every existing scorecard.
- **Author:client asymmetry ratio** in guideline-1 economics (268 BL-5). Scores `InterfaceCost` separately for author-written and client-written callers and records `client-caller : author-caller` in design-rubrics' existing `Attention` column -- no template change, template pointed at rather than restated (design-rubrics CON-001). A ratio well above 1 means the interface is affordable only to someone already holding the internal model: small, but not deep. Carries critic 266's FATAL `F265-1` (both operands are durable per-caller costs; `AuthorCost` is a one-time cost and must not appear in the ratio -- a real trap, since guideline 1 defines `AuthorCost` two paragraphs above) and `M265-1` (the unproven near-1-implies-shallow reading is stated as absent, not silently dropped). Non-summed, scoped to ≥2 caller classes.
- **Disclosure converts an unknown unknown into a counted one** (268 BL-8). A named limitation becomes a visible ISC/RCK line-item; the same limitation unstated is counted nowhere -- so on `TOTAL` alone silence outscores candor. The note names that as a measurement artifact rather than a property of the design, and points at `G-D-BLIND` for the obligation, satisfying 268's "do not ship alone" condition with a mechanism rather than a sentiment.
- **CHEC/CCT abbreviation collision** pre-empted (268 BL-10, evidence incident E-7 in analysis 264). The collision mis-scores in both directions at once: a derived count summed into a scored proxy, and an overexposure signal the firewall keeps unsummed disappearing from view.

### Status

Report 268's backlog is complete through Phase 2. BL-7 was the only item left and was gated on a corpus re-score of `216`/`232` that had never been run. **That gate has since run — see the 2026-09-17 entry above; BL-7 is unblocked and stubbed as plan 045.** BL-9 stays dropped. BL-6 landed as a candidate guarantee with its procedure written; it needs corpus growth and ratification, not further edits.

## 2026-09-16 -- Adjudicated oracles, G-D-BLIND, and report 268 Phase 1

A single arc: BL-6 from report 268 asked for a mandatory blind-spot disclosure obligation, which turned out to need an oracle type the framework did not have, and a viability probe that report 268 had never run. Three backlog items and one escaped defect came out of the same pass.

### Added

- **`measured (adjudicated)` oracle type** (`requirements-enforcement`). For guarantees about _completeness of consideration_ -- properties whose violation leaves no site in the artifact to point at, so they cannot be found by inspection and must be re-derived independently. Requires the reviewing agent to enumerate from named sources **before** reading the artifact's own claims, and to record every candidate raised including those ruled inapplicable; those are the oracle's false positives and precision is not computable without them. The threshold validates the procedure, never the artifact: no review claims completeness, the measured detection rate is itself the disclosure.
- **Oracle ID convention documented** (`enforcement.md`) -- `T-` a test, `E-` an eval harness, `A-` a versioned procedure document. It previously existed only by example.
- **`G-D-BLIND`** (candidate) and provisional `FM-D-BLIND`, with **`A-001`**, the blind-spot enumeration protocol (`failure-modes/oracles/`). Scoped to registry adjacency, prior in-repo precedent, and document-internal consistency; template-required fields are deliberately routed away to a structural gate instead.
- **Probe 041** -- the viability gate BL-6 rested on and 268 never ran. Labelling rule pre-registered before any finding was read; sampling done at document level so findings could not be cherry-picked. 24 enumerable / 0 unforeseeable / 2 out-of-scope over 4 critiques.
- **Plan 042 (stub)** -- convert the `design-rubrics` Lens-Applicability declaration from a reminder into a hard gate. Same finding at least thirteen times (figure corrected 2026-09-17 from an inaccurate in-corpus citation) is a coverage gap by the triage procedure's own definition, which prescribes exactly this conversion.
- **`G-T-SELFLINK`** (candidate), `FM-T-SELFLINK`, and `scripts/test_link_setup.py` -- see below.

### Changed

- **`deep-modules`: substrate schema stability is measured, not asserted** (268 BL-2). Primary measure is the observed count of breaking schema changes over the last N released versions; `code-metrics`' `instability`/`sdp_violations` are reference only and never summed into `InterfaceCost` (ADR-003 firewall).
- **`lean-design` rung 2 gains a capability-_add_ depth trigger** (268 BL-1). Shrinking a facade's capability was already routed to `deep-modules`; growing one was not, so any fold read as a clean rung-2 win -- precisely where the lean reflex does damage, since folding is what lean recommends. If the fold adds caller-visible surface to the seam it folds into, route out before claiming the rung.
- **`lean-design` rung 2's "independently justified" now points at the trajectory test** (268 BL-4) -- growth unit, Δ per unit, slope. It was a rhetorical escape hatch; it is now a measurement.
- **Critic phase hook states its method** under an adjudicated oracle (`enforcement.md`) -- enumerate before reading the declaration -- without becoming a third question.

### Fixed

- **`scripts/link_setup.py` refuses a destination that resolves to the source itself.** Running `make setup` with a home-level target moved all 43 skill directories aside and linked none: `~/.agents/skills` is a whole-directory junction onto `<repo>/skills`, so each destination resolved back to its own source, and `trees_differ()` necessarily reported "no drift" because the two paths were the same directory. The drift guard asked whether dest _differs_ from source and never whether dest _is_ source -- so the one condition under which replacement is unconditionally destructive was the one it read as safe. Recovered by rename; no content lost. Covered by `scripts/test_link_setup.py`, demonstrated red before green.
- **`Makefile` linking targets work on Windows.** `./scripts/link-setup.sh` forced the recipe shell to resolve a relative path against Make's CWD, and bash consumed the backslashes (`C:devmdt...`). Now invokes `link_setup.py` as an argument to the interpreter. Also repairs the `TARGET_ROOTS` quoting that printed a shell error on every invocation.
- **Home-level linking documentation corrected.** `LINKING.md`, `README.md`, `USING-AGENTS.md` and `link-config.example.yaml` described the home link as linker-managed per-item targets -- following those instructions is what emptied the repo. It is **one whole-directory link made once by hand**; `link_setup.py` does not manage it, and `targets: []` is correct for a machine needing only that link. ADR-017 amended in place: its decision and its Remote-SSH evidence are unaffected, only the mechanism detail was wrong.

## 2026-09-16 -- Retire the VS Code Agent Plugin install path; system-level linking is now the one supported way in

The repo documented three overlapping ways to get its agents/skills into VS Code: installing as a VS Code Agent Plugin (`chat.plugins.enabled`, **Chat: Install Plugin From Source**), manual per-workspace/user-level copy, and the config-driven symlink system. Investigating a Remote-SSH linking question surfaced that the Plugin path has a real, currently-unresolved defect: its registration is cached on the local client machine and is never discovered once a workspace is reopened over Remote-SSH -- every agent/skill silently disappears, with no error. See [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md).

### Changed

- **Single supported install path**: system-level linking via `scripts/link_setup.py`'s `claude-user` target (`~/.agents/skills`), documented as the default in `README.md`, `USING-AGENTS.md`, and a substantially rewritten `LINKING.md`. VS Code reads this location for every local workspace on a machine automatically; setting it up once per machine (this desktop, and separately on each Remote-SSH host used) has no plugin cache to go stale.
- Per-workspace linking is retained as a documented fallback (`LINKING.md`'s "Per-Workspace Fallback" section) for agents/prompts specifically, or for a workspace that should not inherit the shared set at all -- not as a co-equal default, to avoid the double-registration risk `README.md`'s prior "Migrating from Workspace-Level Agents to Plugin" section existed to clean up after the fact.
- `scripts/link-config.example.yaml` now shows the `claude-user` system-level target as the primary example; the per-workspace form is commented out as the fallback.

### Removed

- **"Install as a Plugin" instructions** from `README.md` and `USING-AGENTS.md`. This does **not** remove `plugin.json` or `hooks/hooks.json` -- those remain this repo's separate Claude Code plugin manifest (`hooks/hooks.json`'s `${CLAUDE_PLUGIN_ROOT}`-templated hooks are Claude Code's own plugin-hook schema, unaffected by anything above), and `scripts/smoke-test-plugin.{sh,ps1}` still validates them.
- **`scripts/install-probe.{sh,ps1}`**: existed solely to register this repo as a VS Code Agent Plugin in a scratch profile and confirm VS Code discovered it. Deleted along with the install path it probed.

### Left explicitly open

- Agents and prompts have no confirmed system-level VS Code discovery location as of this writing (`~/.copilot/agents/` has a documented, unrelated upstream defect where agents placed there do not load at all; `~/.claude/agents/` is plausible but unverified; prompts have no candidate location at all). `LINKING.md` and `ADR-017` say so directly rather than routing either primitive to an unconfirmed location.

## 2026-09-16 -- Executive Summary: extract into its own skill, add firing enforcement

The Executive Summary auto-trigger measured a 0-of-6 firing rate. Root cause: its trigger conditions and field schema lived inside `structured-labeling`'s SKILL.md, a skill whose own description never mentions "executive summary" -- plus five broken `Process step 15` cross-references in `planner.agent.md` that had drifted to step 16, one of them also conflating the `awaiting-user-approval` and `approved` `Review_State` values. See [ADR-016](docs/adr/ADR-016-executive-summary-skill-extraction.md) (supersedes [ADR-008](docs/adr/ADR-008-deferred-items-and-executive-summary-dual-trigger.md)).

### Added

- **`executive-summary` skill**: Owns the Executive Summary's required fields, glyph convention, age-triggered escalation, MUST NOT list, and MANDATORY auto-trigger conditions (Architect-approval snapshot, Critic-approval final, HARD BLOCK snapshot, and explicit-ask phrasing) -- mirroring the proven `mini-retro` self-triggering pattern.
- **`Executive_Summary_Fired` / `Executive_Summary_Fired_Date`** plan frontmatter fields (`structured-labeling` Approval Tracking Frontmatter Schema), set by Planner at the Critic-approval firing. Enforced by a new `agents/critic.agent.md` TEMPLATE VALIDATION checklist line: if `Critic_Approved: true`, `Executive_Summary_Fired` must also be `true`.
- **`Review_State`** backfilled into `structured-labeling`'s Approval Tracking Frontmatter Schema (Schema / Field Definitions / Field Ownership tables) -- decided at ADR-001 Decision 7 (D9) and referenced in `planner.agent.md`'s Approval Routing text, but never actually added to the schema until now.

### Changed

- `skills/structured-labeling/SKILL.md` (1.3 -> 1.4): removed the Executive Summary Required Fields section (moved to the new skill; a pointer remains); added `Review_State` and `Executive_Summary_Fired`/`_Date` to the Approval Tracking Frontmatter Schema; added the Critic enforcement checklist line.
- `agents/planner.agent.md`: all executive-summary references (Core Responsibilities #17/#18/#20, Process step 16, Approval Routing, the Orchestration Rules bullet, and HARD BLOCK handling) now point at the `executive-summary` skill by name instead of by numeric process-step cross-reference; fixed the `approved`/`awaiting-user-approval` conflation in Approval Routing.
- `agents/critic.agent.md`: TEMPLATE VALIDATION gains the `Executive_Summary_Fired` enforcement check.
- `skills/document-lifecycle/SKILL.md` and `agents/planner.agent.md` (Process step 15, the template validation checkpoint): corrected stale "16 sections" references to 17, matching the section count ADR-008 established -- the last two survivors of the renumbering sweep ADR-008's own Negative Consequences section predicted.
- `docs/architecture/system-architecture.md`: Decisions Index updated (ADR-016 added; ADR-008 row marked `superseded by ADR-016`).

## 2026-09-16 -- Literal Intent Fidelity: stop criterion and target substitution

New skill addressing **criterion substitution** -- the failure where a user states an explicit, testable criterion and an agent silently applies a narrower or semantically adjacent test, then reports the result as though it answered the original request -- and its sibling failure, **target substitution**, where a correct answer is delivered against the wrong working tree, remote, or branch because the target was inherited from context rather than confirmed.

### Added

- **`literal-intent-fidelity` skill**: Defines the Criterion Ledger procedure (verbatim `CRIT-*` capture, a confirmed `TARGET-*` the criterion applies to, mechanical per-candidate testing, cited evidence for every verdict), the valid exclusion taxonomy, the separation of scope decisions from cost decisions, and the pushback protocol (one correct objection invalidates the test, so the full pass is re-run). Companion to `no-silent-assumptions-software-planning`: that skill covers what the user did NOT say, this one covers what the user DID say.
- **`literal-intent-fidelity/references/criterion-ledger-template.md`**: Copy-paste ledger template with field rules and a minimal inline form for small decisions.
- **`literal-intent-fidelity/references/worked-example-scope-substitution.md`**: End-to-end case studies of a criterion-substitution incident and a target-substitution incident, and their corrections.
- **Scope & Criterion Fidelity label prefixes** (`structured-labeling` skill): `TARGET-*`, `CRIT-*`, `PROXY-*`, `EXCL-*`, `COST-*`, `DRIFT-*`. These are artifact-local (used inside a Criterion Ledger), not plan-template sections, and are not checked by the plan validators.
- **`[Literal-Criterion Check]` prompt injection**: `hooks/user-prompt-submit.sh` and `.ps1` now read the UserPromptSubmit payload and inject a literal-criterion reminder when the prompt states a testable scope criterion or disputes how stated intent was interpreted, so the guardrail fires without relying on the agent choosing to load the skill.
- **"Literal Intent Fidelity" feature section** in `README.md`.

### Changed

- **CONTRACT-003 (UserPromptSubmit hook output)**: `contextInjection` may now carry two blocks -- `[Literal-Criterion Check]` (first, when triggered) and `[Active Orchestrations]`. Either block may be absent; output remains `{}` when neither applies or on any error. Orchestration-block content and formatting are unchanged.
- **Agent wiring for `literal-intent-fidelity`**:
  - `planner.agent.md`: new skills-header directive plus Process step 5b (stated-criterion fidelity), the counterpart to the existing step 5 ambiguity detection.
  - `analyst.agent.md`: applies when investigation scope comes from a stated criterion; candidate population must be enumerated from the repository, not a prior document.
  - `architect.agent.md`: architectural categories ("transport layer", "domain core", "plumbing") may describe an exclusion but never justify one; canonical-vs-generated-copy target note.
  - `critic.agent.md`: Critic is named as the gate that catches criterion substitution in plan scope.
  - `implementer.agent.md`: change sets defined by a criterion ("every caller of X") must be enumerated mechanically and cited.
  - `qa.agent.md`: coverage reported against a narrower population than the one requested is a false pass.
- **`no-silent-assumptions-software-planning` skill** (2.5 -> 2.6): added companion-skill section distinguishing unstated scope (ask) from stated-and-narrowed scope (quote and test literally).
- **`structured-labeling` skill** (1.2 -> 1.3): added the Scope & Criterion Fidelity prefix table.

## 3.1.0 -- 2026-09-10 -- Creation timestamps on agent-owned artifacts

Every agent-owned artifact now records when it was created, and downstream rules can rely on it. Before this, **no plan carried a date field of any kind** — which is why the planned rule that gates required-section severity on a plan's age had nothing to read.

Deriving the date from git instead was considered and rejected on measurement: git is distorted three ways across a mature `.agent-output/` tree. Bulk-tracking commits flatten artifacts to the day the tree started tracking them (80 of 159 here, across two separate commits); `git mv` resets the add-date (11 artifacts, one such rename performed during this repo's own routine housekeeping); and a handful of artifacts carry no date anywhere. A derivation that ordinary housekeeping silently corrupts is not a source of record, so the value is stored.

### Added

- **`Created` in the Document Header Format** (`skills/document-lifecycle/SKILL.md`) — now five mandated fields, joining `ID`, `Origin`, `UUID` and `Status`. This is the **single owning definition**; every other site cites it rather than restating it.
  - The value is an ISO-8601 timestamp with an **explicit UTC offset** or `Z`. A bare date loses same-day ordering; a local time without an offset is worse than a date, because it is ambiguous while looking precise.
  - **It must be stamped, not typed.** An agent has no clock: asked for a time of day it emits a plausible string, typically a round hour. The skill gives the exact command for each shell.
  - It is **immutable** — authorship, not modification. Revisions belong in the Changelog; execution-states already carry `updated_at`.
  - Reconstructed values carry `Created_Derived: true`.
- **`.agent-output/policy.yaml`** — a per-project convention config, generalising the pattern already used by `.agent-output/mini-retro/policy.yaml`. It sets the date from which each convention is enforced. **Consuming projects set their own adoption date**, so introducing a rule never invalidates a repository's existing artifacts. Absent file means warnings only.
- **`scripts/check-created-coverage.{ps1,sh}`** — walks every artifact under `.agent-output/`, not just plans, checking presence, format, unmarked whole-hour values, and immutability. The immutability comparison resolves through renames, since a path-only comparison passes silently on exactly the `git mv` that motivated storing the field.
- **`created` / `created_derived` in both YAML schemas** — `execution-state.schema.md` (top level) and `work-order.schema.yaml` (under `meta:`).

### Changed

- **`scripts/validate-plan-template.{ps1,sh}`** enforce `Created` on plans, gated by the project's adoption date. Absence and malformation produce **distinguishable messages** — they send an author to different fixes. Verified at parity: both validators agree on exit code _and_ on reason across every case, including three negative ones.
- **`work-order.schema.yaml`**: `meta.issued_date` is **deprecated**, superseded by `meta.created`. Existing work-orders keep validating. Widening a date-only value invents both a time and an offset, so migration pins `T00:00:00Z` and marks the result derived rather than inheriting whatever offset the migrating machine happens to have.
- **`skills/structured-labeling/SKILL.md`**: `Created` added to the plan frontmatter template.
- **`agents/analyst.agent.md`**: its header block now cites `document-lifecycle` as the owning definition instead of duplicating a four-field copy of it.

### Notes

- **Existing artifacts are untouched.** This repo's adoption date is `2026-09-10`; its 154 pre-convention artifacts are skipped, and two carrying a legacy date-only `created:` are reported as warnings. No backfill was performed — the convention changes expectations going forward.
- One artifact, `mini-retro/028-mini-retro.md`, has no recoverable creation date (no date in content, and its only git date comes from a bulk publish). It is named individually in the coverage check rather than covered by a numeric budget, so the exception set cannot silently grow.

## 2026-09-09 (Plan 033, Phase 0) -- Reconciliation close-out and chain-artifact disambiguation

Phase 0's premise changed under it. The deployed-tree reconciliation it was scheduled to perform was carried out by Plan 036's branch merge and released as 3.0.0; `TASK-028` is recorded as **superseded** rather than complete, because nobody on this chain made the per-hunk decision it was blocked on. What Phase 0 delivers here is the close-out and the corrections that came out of it.

**No version bump.** Nothing distributed to consumers changed — no skill, agent, prompt or script. Bumping would signal a change consumers did not receive. The first phase that alters distributed content carries the bump.

### Changed

- **`.agent-output/handoffs/033-phase-0-analyst.yaml`**: supplied the missing `disconfirm` on item `AC-004`, which was `status: complete` with full evidence and had simply never had the field populated. The work-order gate passes on it.
- **Chain-artifact names disambiguated.** Document ID 027 was allocated to three distinct chains; four artifacts carried names that did not identify which, and two collided on the same destination in `closed/`. Renamed by chain against frontmatter UUID, content untouched.

### Fixed

- **Deployment topology corrected in the record.** The claim that `~/.agents/skills` held unlinked copies was wrong: it is itself a junction targeting the repository's `skills/`, so the observed zero drift was structural rather than coincidental. `dod-1` now closes on two genuinely independent signals — content equality and link topology — where the earlier reading compared a directory with itself twice.
- **Work-order census corrected.** The recorded figure of "13 Demonstrated items across 10 work-orders" was wrong by roughly sevenfold: there are **91 across 23**. The 13 work-orders belonging to Plan 036 have been tracked since `10589c6` and were present for every measurement taken. The independent re-measurement cited as corroboration had re-run a better parser over the same file list, so the two signals shared a scoping error and were one signal.

### Known

- `036-phase-1.yaml` items `AC-002` and `AC-003` are `status: satisfied` with no evidence and no `disconfirm`, in a Committed chain. Recorded rather than rewritten, per the prospective-only correction rule. The forthcoming `REQ-028` gate would fail that work-order if re-run — the correct behaviour, and what the requirement exists to surface.
- Running `scripts/link_setup.py` deleted 41 skill directories from the worktree and created zero links; fully restored from git, `HEAD` unaffected. The tool assumes per-item linking and does not check whether the parent is already a link. Its dry run reported identical output for a safe and a destructive configuration. Recorded as `INCIDENT-001`; the tool must not be run until Plan 033's `TASK-010` reviews it.

## [3.0.0] - 2026-09-07

Plan 036 integrates the reviewed `deep-and-lean` capability set into the local default branch. The independently authored `ddbff63` ancestor remains outside Plan 036 attribution.

### Added

- Integrated deep-module, lean-design, functional-core, orchestration, and mini-retro capabilities, including metric-budget support and stronger smoke, archaeology, and workflow gates.
- Added durable guarantee and failure-mode records for validator parity and agent ordinal checks.

### Changed

- Reconciled ADR identities to 011-015 and reassigned the colliding historical plan to Plan 038, preserving permanent allocation history and cross-document traceability.
- Made PowerShell and Bash plan validation deterministic across numbered headings, strict-mode cardinality, and repeated `pipefail` execution.
- Routed continuous-improvement input through mandatory mini-retros and PI synthesis.

### Removed

- Removed the public Retrospective agent. Workflows that previously delegated to Retrospective must now record `.agent-output/mini-retro/` evidence and route synthesis through PI.

### Fixed

- Closed fail-open archaeology enumeration and duplicate agent-ordinal defects found during merge QA.

## 2026-09-01 (Plan 030, Phase 1) -- Deferred Items label, Traceability Map Guarantee column, Executive Summary rewrite

Establishes `DEFER-*` as a first-class label with a canonical plan-template home (Section 9, composite `DEFER-<origin-doc-ID>-<local-seq>` numbering, mirroring `OPENQ-*`), replacing the ad-hoc, inconsistently-named "carry-forward" sections found in analysis 028. Extends the Traceability Map with a `Guarantee` column (WARNING-level coverage-gap check, mirroring the Failure Mode column). Rewrites the Executive Summary Required Fields to match the user-approved design (analysis 029, Variation 3): forced-visibility Deferred Items, a condensed Traceability Matrix, the Convention 5/Chosen glyph set with `[TAG]` + emoji paired in section headers, no `<details>`/`<summary>` collapsing, and per-phase task nesting; removes the Scope Snapshot "cap at 10" rule. Mints `G-T-DEFERGATE` in `guarantees/LEDGER.md`. See ADR-008 (accepted). Phase 2 (mandatory dual-trigger orchestration) and Phase 3 (validator parity) ship in later work-orders.

### Changed

- **`skills/structured-labeling/SKILL.md`**: added `DEFER-*` to the Required Label Prefixes table and a Composite DEFER Identity numbering rule; inserted `## Deferred Items (DEFER-*)` as Plan Template Section 9 (renumbered Sections 10-17) with its own required-format subsection; added a `Guarantee` column to the Traceability Map required format; rewrote the Executive Summary Required Fields section per analysis 029's Variation 3; added Quick Reference and Validation Checklist coverage for both new mechanisms. Version bumped.
- **`agents/critic.agent.md`**: updated the two hardcoded "sections 1-16" cross-references to "sections 1-17", including the section-name breadcrumb (now includes Deferred Items).
- **`agents/planner.agent.md`**: updated the Response Style section's own embedded 1-16 section enumeration to 1-17, inserting Deferred Items at position 9 and the Guarantee column into the Traceability Map format description.
- **`skills/document-lifecycle/SKILL.md`**: updated the "rigid 16-section template" reference to 17 sections.
- **`guarantees/LEDGER.md`**: added `G-T-DEFERGATE` (Deferred Items required-sections check), candidate maturity, `FM-T-DEFERGATE (provisional)`.
- **`CONTEXT.md`**: added a glossary entry for "Deferred Item" / `DEFER-*`.
- **`plugin.json`**: version bumped (minor, additive convention change).

## 2026-08-31 (Plan 027) -- Live-Access Disposition and Citation Fidelity ask mechanisms

Two independently-diagnosed gaps in how agents handle undecided things: an agent unilaterally disposing of a small live-environment/data judgment call in bare narrative prose with no downstream re-examination, and a hedged or bounded finding eroding into unbounded settled fact through repeated cross-document retelling. Both close with prose-only amendments across four already-symlinked skills, reusing the existing USER-TASK/OPENQ/RISK labels and the existing boundary-aware review-gate structure -- no new registry, skill, or automation script. See ADR-005 (live-access disposition) and ADR-006 (citation fidelity and staleness), both recorded `Status: proposed` pending a post-merge backtest-confirmed ratification.

### Changed

- **`skills/structured-labeling/SKILL.md`**: added the Live-Access Disposition Rule (trigger vocabulary
  - adjacent-label requirement) as a sibling section to the existing USER-TASK policy; added the composite open-question identity format to the Numbering Rules section; added a Citation Fidelity Rule cross-referencing the Analyst's Uncertainty Protocol for hedge vocabulary; added an age-triggered mandatory-blocking escalation rule to the Executive Summary Open Questions handling. Version bumped.
- **`skills/no-silent-assumptions-software-planning/SKILL.md`**: added a four-part live-action-permission ask template, co-located with and explicitly distinguished from the existing Enriched design-decision ask template. Version bumped.
- **`skills/document-lifecycle/SKILL.md`**: retitled the per-agent self-check to also fire at citation time (5-day staleness annotation on aged citations); extended the Roadmap periodic sweep with an open-question staleness sweep (10-day mandatory-blocking threshold) and a citation fan-out tracking procedure (4-citation cap). Version bumped.
- **`skills/code-review/SKILL.md`**: added two new review-gate families modeled on the existing boundary-aware gate structure -- one for live-access disposition narrative, one for citation fidelity and staleness/fan-out mechanics. Version bumped.
- **`CONTEXT.md`**: added glossary entries for the Live-Access Disposition Rule and the Citation Fidelity Rule.
- **`plugin.json`**: version bumped (minor, additive convention change).

## 2026-07-13 — Diff-scoped metric budgets: planning-time bands, implementer iteration loop, reviewer hard gate

### Added

- **`crest_metrics.py --diff-base <ref> [--budget <file>] [--diff-report <out>]`**: per-change metric gate. Measures the whole tree twice (base ref via `git archive`, then the working tree) and scopes the judgment — file-level proxies ratchet over the changed-file region only (removes the worst-offender shield of repo-wide maxima), `import_cycles`/`dead_export_count` ratchet tree-wide, and brand-new files are held to absolute `new_code_bands` from the budget. Renames compare old content vs new; untracked files count as new. Exit 0/1/2 = pass/firm violation/usage error. `--diff-report` emits machine-readable evidence (before/after region vectors, per-new-file vectors, violations, budget sha256) for implementation docs and independent reviewer re-verification.

- **Metric-budget artifact** (`.agent-output/metrics/<plan-id>-metric-budget.yaml`): restricted-YAML schema parsed stdlib-only (`parse_budget_text`/`validate_budget`) — `new_code_bands` (firm), `advisory_bands` (reported only), `ratchet_exempt_keys`, per-path `exemptions` requiring a `reason`, optional `effect_policy_version` pin. Template: `skills/functional-core/tools/references/metric-budget-template.md`; example: `skills/functional-core/tools/crest_budget.example.yaml`.

- **`tools/tests/test_diff_gate.py`** (27 tests): budget parser/validator, band direction/exemption/empty-region semantics, changed-file scoping (add/modify/ delete/untracked), end-to-end exit semantics over temp git repos, CLI misuse guards.

### Changed

- **Planner**: MANDATORY metric-budget authoring + `metric_budget` work-order gate when a phase touches Python source; exemptions require recorded rationale; budget + work-order listed in `scope.blocked_files`.
- **Implementer**: `metric_budget` gate is part of the inner loop (run early, iterate to exit 0); never edits budget/effect-policy/baseline/gate command — needed exemptions become `blockers[]` entries for the Planner.
- **Code Reviewer**: independent hard gate — re-runs the exact gate command, compares fresh vs recorded diff-report, and REJECTS on bypass-surface touches (budget, work-order gate command, effect policy, baseline, or `crest_metrics.py`) or a narrowed `--src`.
- **`execution-orchestration` SKILL** §Work-Order Contract: optional third standard gate (`metric_budget`) documented; command allowlist already covers `python`, so the gate scripts are unchanged.
- **`code-metrics` SKILL**: reference-implementation section documents the diff gate.
- **`check_ratchet()`** gains an optional `keys` restriction (backwards-compatible) so region and tree scopes reuse the same direction-aware comparison.

## 2026-07-12 (Plan 029) — ON-by-default gradient scorecard as a standing mini-retro dimension

### Added

- **`skills/mini-retro/references/gradient-scorecard.md`** (new): Canonical single-owner Tier-1 rubric for the 20-question 1–10 gradient scorecard. Contains all 20 questions across four groups (repo/system Q1–Q4, agents Q5–Q12, skills Q13–Q16, interworking Q17–Q20), the calibration anchor table (1–2 deficient … 9–10 exemplary), the sensitivity rule (Δ ≥ ±2 = signal; ±1 = noise unless it repeats), the finding rule (aspect ≤ 6 or Δ ≤ −2 → tagged finding required), the first-run convention (`prior = —`; Δ omitted), the roll-up format, and the per-aspect rationale requirement. Zero fabricated scores.

- **`skills/mini-retro/assets/gradient-scorecard-blank.md`** (new): Standalone blank fill-in template with four grouped score/prior/Δ/rationale tables, roll-up table, and finding-linkage note. Rows use `Q1..Q20` identifiers pointing to the rubric — no aspect-prompt text duplicated here.

- **`skills/mini-retro/assets/gradient-scorecard-example.md`** (new — relocated from `.agent-output/mini-retro/`): Kept walk-through example with fabricated scores showing a fully-populated gradient scorecard run. Retains its ILLUSTRATIVE-ONLY / fabricated-score caveat. Aspect rows converted to `Q1..Q20` pointers citing the canonical rubric.

- **`.agent-output/mini-retro/policy.yaml`** (new): This repo's Tier-2 mini-retro policy. Sets `dimensions.gradient-scorecard: { override: require, practice: gradient-scorecard }` so every plan wrap-up here runs the 20-question scorecard and any gap (missing section or a sub-floor score without a finding) becomes a finding.

- **`docs/adr/ADR-010-mini-retro-gradient-scorecard.md`** (new, accepted): Documents the decision to adopt the gradient scorecard as an optional, ON-by-default Tier-1 mini-retro dimension with a `disable` opt-out.

### Changed

- **`skills/mini-retro/references/question-bank.md`**: Added the resolution model section (deterministic `default-asked` rule; `enable` no-op semantics; `disable` opt-out semantics; unmarked-default rule). Added `gradient-scorecard` as `optional, default-asked: true` (pointer-only; questions live in `gradient-scorecard.md`). Explicitly marked `failure-mode-analysis` as `optional, default-asked: true` to preserve its existing asked-by-default behavior.

- **`skills/mini-retro/references/memory-model.md`**: Updated the effective-policy resolution section to be deterministic (`default-asked` rule; `enable` no-op for ON-by-default dims; `disable`/`suppress` semantics). Added worked example for gradient scorecard opt-out alongside the existing failure-mode-analysis example.

- **`skills/mini-retro/references/project-policy.schema.md`**: Registered `gradient-scorecard` in the known dimension-id list. Documented the numeric (1–10/prior/Δ) answer shape distinct from letter-option answers. Reconciled `enable`/`disable`/`require` override rows for the ON-by-default state so schema, question-bank, and memory-model agree.

- **`skills/mini-retro/SKILL.md`**: Updated Procedure step 2 to reference the `default-asked` marker in effective-policy resolution. Added gradient dimension description to the self-assessment rubric section. Updated References list with all three gradient artifacts (rubric, blank, example).

- **`skills/mini-retro/assets/mini-retro-template.md`**: Added `gradient-scorecard` row to the Effective Policy In Force table. Added a thin-pointer `## Gradient Scorecard` section (rendered only when the dimension is active) pointing to the standalone blank.

- **`skills/mini-retro/assets/project-policy.example.yaml`**: Added Example 3 — a worked `gradient-scorecard: require` block with a `practices` entry and evidence-hint.

## 2026-07-09 (Plan 028) — Mandatory Lens-Applicability Declaration on Every User-Facing OPENQ

### Added

- **`skills/design-rubrics/SKILL.md` — Lens Applicability declaration (new spine section):** Defines the single canonical `Lens applicability:` line format (stated once, in the shared output-contract spine) with the derivation invariant: interface-shaping → `deep-modules in · lean-design in`; scope/policy → `deep-modules out · lean-design in`; `functional-core` is a constant `out` in this domain with fixed canned token `functional-core out — not a within-unit decomposition`. Includes inline verbosity-vs-auditability rationale (no ADR, per Architect ruling). Slot references (anchor link only, no format restatement) added to the Compact decision template, both OPENQ-framing template branches, and the proportionality guardrail paragraph.

### Changed

- **`skills/no-silent-assumptions-software-planning/SKILL.md`:** Added Lens Applicability slot as the required first line in both Enriched OPENQ skeletons (interface-shaping and scope/policy) and a reference note in the Stage-2 classifier — all pointing to the `design-rubrics` owner section. Format is not restated.

- **`skills/lean-design/SKILL.md`:** Extended the Activation visible obligation so lean applicability (`in` or `out`) must be stated on every two-or-more-option presentation via the Lens Applicability declaration, not only when lean is the active rung.

- **`agents/planner.agent.md`:** Added a single pointer in the Design Rubrics bullet requiring the Lens Applicability declaration on every OPENQ/option comparison, referencing the `design-rubrics` owner section. No restatement of the format.

## 2026-07-08 (Plan 027) — No-archaeological-comments convention; publish `.agent-output/` history zone

### Added

- **`docs/adr/ADR-009-no-archaeological-comments.md`** (`Status: proposed`): Codifies the ban on archaeological comments in consumer-facing files — plan numbers, plan names, "Historical note" annotations, and rename/replacement commentary that only makes sense relative to this repo's own change history. Defines exemptions: `.agent-output/`, `CHANGELOG.md`, `docs/adr/`, functional numbering mechanisms, illustrative examples, legitimate domain vocabulary, and embedded provenance/history blocks.

- **`AGENTS.md`** (repo root): New root-level instruction file directing agents and contributors to load `CONTEXT.md` at the start of every session in this repository, and to honor the no-archaeological-comments convention.

- **`scripts/validate-no-archaeology.ps1`** and **`scripts/validate-no-archaeology.sh`**: Dual cross-platform validator (PowerShell + bash parity) that checks high-signal archaeological patterns case-sensitively, skips all exemption zones, and supports a path allowlist plus inline `<!-- archaeology-ok -->` suppression. Wired into `make check-archaeology`.

- **`scripts/test-fixtures/archaeology-positive.md`** and **`scripts/test-fixtures/archaeology-negative.md`**: Validator test fixtures — known-positive (should be flagged) and known-negative (should be ignored) cases for TEST-001/TEST-002.

### Changed

- **`CONTEXT.md`**: Added `Archaeological Comment` glossary entry (immediately after `Findings`) defining the banned class, its exemptions, and a pointer to ADR-009.

- **`docs/architecture/system-architecture.md`**: Added ADR-009 (`proposed`) row to the Decisions Index (CON-007 exempt changelog column updated).

- **`.gitignore`**: Removed the `.agent-output/` ignore rule. The process-history zone is now versioned. Global ignores (`*.env`, `*.local`, `.DS_Store`, `**/__pycache__/`) remain in effect and still apply inside `.agent-output/`.

- **`Makefile`**: Added `check-archaeology` target (wires the new validator with its path allowlist).

- **`USING-AGENTS.md`**: Removed archaeological "Renamed from `agent-output/`" migration callout.

- **`README.md`**: Removed archaeological "(renamed from `agent-output/`)" reference.

- **`skills/mini-retro/SKILL.md`**: Removed `(Plan 006, Phase 5)` plan-number reference from the Retrospective coverage section.

- **`skills/system-integration-gate/SKILL.md`**: Removed plan-number from Author metadata.

- **`scripts/validate-plan-template.ps1`** and **`scripts/validate-plan-template.sh`**: Removed plan-number references from internal code comments.

- **`.agent-output/`**: Newly tracked — all local process-history contents (plans, critiques, QA reports, implementation docs, mini-retros) are now committed. Contents untouched; REQ-SEC-001 secrets scan confirmed clean before un-ignoring.

## 2026-07-08 (Plan 027) — Stage-0 scope extension: inherited OPENQ re-triage + brainstorming wiring

### Changed

- **`skills/no-silent-assumptions-software-planning/SKILL.md`** (v2.3 → v2.4): Added `### Inherited OPENQs` subsection to the Stage-0 Routing Gate. The gate now explicitly applies to OPENQs inherited from any delegated or subagent session (brainstorming `GO-with-OPENQs` gate, Analyst handback, census, critic pass). Inherited OPENQs must be re-run through the three-outcome classification before surfacing; undischargeable Outcome-1 OPENQs follow the same tiered-exhaustion behavior (high-blast → HARD BLOCK / unblock request; low-blast → labeled `ASSUMPTION-*`); hard-gate ambiguity domains remain unconditionally blocking.
- **`skills/brainstorming/SKILL.md`**: Inserted Session Protocol sub-step `7a — Discharge (Stage-0 re-triage)` between steps 7 and 8 (step 8 not renumbered); routes every OPEN blocker through the Stage-0 Routing Gate before `GO-with-OPENQs` is emitted, citing `#inherited-openqs`. Sharpened Load-Bearing Rule #4 with a resolution-owner split on the blocker row (self-resolvable = Outcome-1/2, discharged; user-judgment = Outcome-3, surfaced). Added Anti-Pattern entry for self-resolvable OPENQs surfaced as gate decisions.
- **`skills/brainstorming/references/artifact-templates.md`**: Annotated the LOCKED/OPEN Ledger `OPEN blockers` line with `stage0_outcome:` and `discharge:` fields. Split the Convergence Output `User-ratification questions:` line into `Discharged before gate (self-resolvable):` and `User-ratification questions (judgment only):`.

## 2026-07-07 (Plan 006 Phase 5) — Portfolio hygiene: Retrospective agent removal, domain-content removal, new-skill gate

### Removed

- **`agents/retrospective.agent.md`**: Retrospective agent deleted per ADR-008. Its charter is split between `skills/mini-retro/SKILL.md` (lesson capture at the commit boundary) and `agents/pi.agent.md` (intake of lessons into the next PI cycle). All inbound references migrated: `agents/devops.agent.md`, `skills/document-lifecycle/SKILL.md`, `skills/mini-retro/SKILL.md`, `skills/release-procedures/SKILL.md`, `skills/release-procedures/references/release-templates.md`, `skills/plan-status-reporting/SKILL.md`, `skills/adr-authoring/SKILL.md`, `skills/structured-labeling/SKILL.md`.

  **Consumer prune command** (run after next `link-setup.sh` if you symlink agents):

  ```bash
  find <links-dir>/agents -type l ! -exec test -e {} \; -print
  # then remove stale links, e.g.: rm <links-dir>/agents/retrospective.agent.md
  ```

- **`skills/optical-camera-diagnostics/`**: Device-specific runbook for NDI optical tracking cameras on Stealth Axis (Juno / Mazor X / S7 / S8) development systems. Removed from this generic distribution repo (OPENQ-004 resolution). Consumers: relocate to your project's own skills or knowledge base.

  **Consumer prune command** (run after next `link-setup.sh` if you symlink skills):

  ```bash
  find <links-dir>/skills -type l ! -exec test -e {} \; -print
  # then remove stale links, e.g.: rm <links-dir>/skills/optical-camera-diagnostics
  ```

- **`docs/knowledge-base/python-best-practices.md`**: Python project best-practices research document (May 2026). Removed from this generic distribution repo — unreachable by any skill trigger (OPENQ-004 resolution). Consumers: relocate to your project's own knowledge base.

### Changed

- **`agents/pi.agent.md`**: Added explicit "Lesson-intake owner (ADR-008)" note in Purpose section, confirming PI as the designated consumer of mini-retro and legacy retrospective artifacts.
- **`skills/mini-retro/SKILL.md`**: Updated "Relationship to the Retrospective agent" section to reflect ADR-008 retirement; PI agent is now the lesson-intake owner.
- **`skills/skill-authoring/SKILL.md`**: Added "New Skill Gate" section with rung-2 fold-into- seam justification checklist (lean-design rung 2 owner). Required before creating any new skill directory.
- **`skills/structured-labeling/SKILL.md`**: Removed Retrospective row from Agent Coverage table.
- **`skills/document-lifecycle/SKILL.md`**: Removed Retrospective rows from ID Assignment Rules and agent closure table.
- **`skills/adr-authoring/SKILL.md`**: Removed Retrospective row from ADR Roles table.
- **`skills/plan-status-reporting/SKILL.md`**: Removed `retrospective` from agent name list.
- **`skills/release-procedures/SKILL.md`**: Updated Stage 2 workflow to reference mini-retro.
- **`skills/release-procedures/references/release-templates.md`**: Updated Next Actions to reference mini-retro instead of Retrospective agent.
- **`agents/devops.agent.md`**: Updated post-release delegation to reference Planner/mini-retro.
- **`docs/architecture/system-architecture.md`**: Removed Retrospective agent from Components list.
- **`scripts/smoke-test-plugin.{sh,ps1}`**: Updated hardcoded agent count assertion from 13 to 12.
- **`README.md`**: Removed Retrospective from agent table; updated workflow and agent count.

## 2026-07-07 (Plan 006 Phase 4) — Skill consolidation: deep-modules-orchestration fold, plan-alignment-session merge, baseline-catalog cuts, three ADRs

### Removed

- **`skills/deep-modules-orchestration/`**: Standalone orchestration skill deleted and folded into `skills/deep-modules/references/orchestration.md` (progressive disclosure per ADR-003 and ADR-005). Inbound reference in `agents/planner.agent.md` migrated to point at `deep-modules`.

  **Consumer prune command** (run after next `link-setup.sh` if you symlink skills):

  ```bash
  find <links-dir>/skills -type l ! -exec test -e {} \; -print
  # then remove stale links, e.g.: rm <links-dir>/skills/deep-modules-orchestration
  ```

- **`skills/plan-alignment-session/`**: Merged into `skills/no-silent-assumptions-software-planning/` as its Interactive Alignment Mode section (ADR-006). `CONTEXT-FORMAT.md` relocated to `skills/no-silent-assumptions-software-planning/references/CONTEXT-FORMAT.md`. Inbound references migrated: `agents/planner.agent.md`, `skills/improve-codebase-architecture/SKILL.md`. `CONTEXT.md` "Alignment Session" glossary entry updated.

  **Consumer prune command** (run after next `link-setup.sh` if you symlink skills):

  ```bash
  find <links-dir>/skills -type l ! -exec test -e {} \; -print
  # then remove stale links, e.g.: rm <links-dir>/skills/plan-alignment-session
  ```

### Changed

- **`skills/deep-modules/SKILL.md`**: Added one-line pointer to `references/orchestration.md` in the References section.
- **`skills/deep-modules/references/orchestration.md`**: New file — orchestration workflow (progressive-disclosure reference, per ADR-005).
- **`skills/no-silent-assumptions-software-planning/SKILL.md`**: Description updated to union of both skills' trigger sets (batch + interactive alignment). Added "Interactive Alignment Mode (Plan Alignment Session)" section at the end.
- **`skills/no-silent-assumptions-software-planning/references/CONTEXT-FORMAT.md`**: New file — relocated from `skills/plan-alignment-session/CONTEXT-FORMAT.md`, ownership references updated.
- **`skills/architecture-patterns/SKILL.md`**: Removed frontier-baseline catalog content (Common Patterns code examples, Anti-Patterns table, System Architecture docs required-sections list, Diagram Standards, and the "When to Write ADRs" table — triple-gate duplicate of `adr-authoring`). Retained: ADR pointer, Reconciliation Changelog Template, Design Debt Registry Template, Agent Responsibilities. Version bumped to 1.1.
- **`skills/security-patterns/SKILL.md`**: Removed frontier-baseline catalog content (OWASP Top 10 Quick Detection, Security Headers Checklist, STRIDE Threat Modeling table). Retained: Core Security Principles, Security Review Phases, Language-Specific Patterns reference links. Version bumped to 1.1.
- **`agents/planner.agent.md`**: Migrated `deep-modules-orchestration` and `plan-alignment-session` load-directives to `deep-modules` and `no-silent-assumptions-software-planning` respectively.
- **`CONTEXT.md`**: "Alignment Session" glossary entry updated to reflect merge.
- **`docs/adr/ADR-005-deep-modules-orchestration-fold.md`**: New ADR — deep-modules-orchestration fold decision, status: accepted.
- **`docs/adr/ADR-006-plan-alignment-session-merge.md`**: New ADR — plan-alignment-session merge decision, status: accepted. Notes relationship to ADR-001 D4/D5.
- **`docs/adr/ADR-008-retrospective-agent-removal.md`**: New ADR — Retrospective agent removal decision, status: accepted (execution deferred to Phase 5 / TASK-017). Numbered 008 (not 007) because ADR-007 is reserved for the analyst-delegation-budget ADR already referenced by `agents/planner.agent.md` §"Analyst Delegation Budget".
- **`docs/architecture/system-architecture.md`**: Decisions Index updated (ADR-003/004/005/006/008 rows added); Skills list updated (plan-alignment-session → no-silent-assumptions-software-planning).

## 2026-07-07 (Plan 026) -- Add deep-modules worked example 10: convention/definition ownership

### Added

- **`skills/deep-modules/examples/10-convention-ownership.md`**: New depth-scoring A-vs-D worked example (non-code surface). Scores where a code-health metric's counting convention lives — one canonical owner (`code-metrics`) versus federated inline across non-owning rubrics. Verdict: A (single owner) is deeper; InterfaceCost 5 vs 10. Dominant driver: RCK + ILC — federating removes the central affiliation index and splits the counting-convention contract. Includes a "Related — the lean half" note cross-linking `lean-design` rung 1 and guideline-4.

### Changed

- **`skills/deep-modules/SKILL.md`** Examples Index: added row 10 for the new example.
- **`skills/deep-modules/SKILL.md`** guideline-4 ILC paragraph: appended a one-sentence pointer to `examples/10-convention-ownership.md` as the canonical non-code case of cross-unit convention ownership scoring as ILC.

## 2026-07-07 -- Add `vertical-slice` skill (tracer bullets)

### Added

- **`skills/vertical-slice/SKILL.md`**: End-to-end vertical-slice discipline ("tracer bullets," _The Pragmatic Programmer_): fire one thin, kept, end-to-end slice through the riskiest seam under real conditions — no stub at the boundary under test — before building horizontal layers. Adapted from the upstream `tracer-bullets` skill (external name `vertical-slice`; tracer-bullet metaphor retained in the body). Cross-references repo siblings: `prototype` (opposite disposability), `lean-design` (two-zone split; ladder applied to sequencing), `structured-labeling` (§7 phase ordering, `BOUNDARY-NNN`, `[Demonstrated]` acceptance criteria), `requirements-enforcement` (first oracle), `deep-modules` (slice depth).

### Changed

- **`skills/prototype/SKILL.md`**: Bidirectional sibling routing with `vertical-slice` -- "which design?" stays in `prototype`; "does the wired path actually connect under real conditions?" routes to `vertical-slice`. Added routing clause to the description and a disposability note under the intro.

## 2026-07-07 (Plan 025) -- Standardize skill frontmatter: version-only metadata, history in CHANGELOG.md

### Changed

- **`skills/code-metrics/SKILL.md`**: Removed `changelog` field from `metadata` block; history already covered by the 2026-07-06 (Plan 024) entry below.
- **`skills/design-rubrics/SKILL.md`**: Removed `changelog` field from `metadata` block; history ported to the 2026-07-02 (Plan 023) entry below.
- **`skills/no-silent-assumptions-software-planning/SKILL.md`**: Removed `changelog` field from `metadata` block; history ported to the Plans 023, 021, and 337+343 entries below.
- **`skills/skill-authoring/SKILL.md`**: Added repo-local convention note establishing that `metadata` blocks carry only `version` (and optionally `author`); change history belongs in `CHANGELOG.md` (single source of truth).

## 2026-07-06 (Plan 024) -- code-metrics ownership refactor

`code-metrics` is now the canonical owner of counting conventions, direction, and gate-status for the ~21 deep-modules and lean-design metrics; it defers to `functional-core` for its 8 metrics (PLR, CC, ND, FLC, TCC) and points there by section reference. Baselines and schema keys remain consumer-workspace-owned (de-hardcoded the `<peer-repo>` path in all three files that carried it). The broken `scripts/fds_metrics.py` pointer is corrected to `../functional-core/scripts/fds_metrics.py` with an honest scope note. A drift note on the CC convention (adds `else`/bare `try` incorrectly vs. radon) is resolved by deletion. Added trigger tokens in the description for agent auto-load. Added cohesion back-pointers in `deep-modules` and `lean-design`, a cross-link to `defect-observability`, and one-line breadcrumbs in the Code Reviewer and QA agents.

### Changed

- **`skills/code-metrics/SKILL.md`**: Ownership refactor (canonical for ~21 metrics; defers to functional-core for 8; de-hardcoded consumer path; deleted drifted PLR/CC/ND conventions; corrected fds_metrics.py pointer; added trigger tokens, Temporal Contract disambiguation, defect-observability cross-link).
- **`skills/design-rubrics/SKILL.md`**: Replaced hardcoded `<peer-repo>` path with "consuming workspace's metrics reference document (baselines are repo-specific)".
- **`skills/deep-modules/SKILL.md`**: Added back-pointer to `code-metrics` in References for automated metrics affiliated with this rubric.
- **`skills/lean-design/SKILL.md`**: Added back-pointer to `code-metrics` in Composition for affiliated automated metrics.
- **`agents/code-reviewer.agent.md`**: Added code-health metric breadcrumb (item 16).
- **`agents/qa.agent.md`**: Added code-health metric breadcrumb (item 13).

## 2026-07-02 (Plan 023) -- OPENQ-framing single source of truth; design-rubrics enrichment

### Changed

- **`skills/design-rubrics/SKILL.md`** (v1.1): Added `metadata.version`; updated OPENQ-framing placement breadcrumb to reference example corpus/index; added OPENQ Framing Example Index section with 7 worked examples.
- **`skills/no-silent-assumptions-software-planning/SKILL.md`** (v2.2): Removed inline four-proxy table skeleton and lean-axes skeleton from Enriched OPENQ Template; replaced with labeled in-position pointers to `design-rubrics` OPENQ-framing mode (single source of truth). Deeper:/Lean axes: labels retained in-position.

## 2026-07-02 (Plan 021) -- no-silent-assumptions Stage-2 OPENQ classifier

### Changed

- **`skills/no-silent-assumptions-software-planning/SKILL.md`** (v2.1): Added Stage-2 OPENQ classifier (interface-shaping vs scope/policy, post-gate at emission); updated Enriched OPENQ Template to show both branches (compact scorecard expands Deeper: for interface-shaping; lean cost axes replace Deeper: for scope/policy); added honesty clause, orthogonal-to-blast-radius note, and proportionality bound.

## 2026-07-01 (Plan 005) -- Absorb `agile_fc` into `functional-core` skill as opt-in FDS kit

### Added

- **`skills/functional-core/scripts/fds_metrics.py`**: Canonical measurement and enforcement engine. Computes the FDS proxy vector (own-PLR, deep-PLR, CC distribution, CC-max, ND-max, FLC-max, functions > 100 LL) over any Python source tree using `radon` + AST. Modes: `--json` (report), `--check` (ratchet, exit 1 on regression), `--write-baseline` (freeze), `--snapshot` (write one immutable snapshot file). The `[CUSTOMIZE]` block at the top holds all project- specific effect patterns. Includes a clean-tree provenance gate (`--snapshot` refuses if any measured `.py` is untracked, dirty, or staged) and atomic write-once persistence via the `os.link` idiom.
- **`skills/functional-core/scripts/fds_scorecard.py`**: Independent visualization tool. Reads the snapshot directory (glob `*.json`, sort by in-payload `ts`), writes a self-contained HTML scorecard with Plotly charts loaded via CDN. No dependency on the measurement engine, `radon`, or any source tree.
- **`skills/functional-core/scripts/Makefile.snippet`**: Makefile targets for `fds-snapshot`, `fds-scorecard`, `fds-ratchet`, `fds-baseline`.
- **`skills/functional-core/scripts/github-fds-ratchet.yml`**: GitHub Actions workflow template (placeholder source path, read-only `--check` ratchet, no `--open`).
- **`skills/functional-core/scripts/pre-commit.example.yaml`**: Pre-commit hook template (read-only ratchet, placeholder source path).
- **`skills/functional-core/scripts/README.md`**: Two-tool split explainer, snapshot-directory contract, quick-start commands, and CI/pre-commit wiring guide.
- **`skills/functional-core/references/effect-policy-template.md`**: Generic three-tier effect policy template (HARD/SOFT/AMBIENT). Project-specific call sites replaced with `[e.g. your-framework.*]` placeholders. Logging-as-ambient presented as an explicit opt-in, not a default.
- **`skills/functional-core/references/roadmap-guide.md`**: Generic phased functional-core improvement roadmap (where-you-are → approach menu → phased ROI roadmap → conversion playbook → ratchet mechanism). Project-specific metrics and filenames stripped.
- **`skills/functional-core/references/scorecard-optional.md`**: One-page opt-in guide for the visualization layer.
- **`skills/functional-core/examples/fds-baseline.example.json`**: Annotated format guide for the ratchet baseline; numbers marked illustrative.
- **`skills/functional-core/examples/python-sample-module.py`**: Generic sample module exercising all engine classification cases (own-pure, logging-ambient, local-mutation, hard-io, async, deep-nesting, high-CC).

### Changed

- **`skills/functional-core/SKILL.md`**: Added "Implementation Kit (opt-in)" section before the Examples and Recipes Index. States the two tools, the snapshot-directory contract, supporting references, and the own-PLR / logging-exemption doctrine reconciliation (the kit is one configured stance, not a change to the scoring rubric's deep-purity default).

### Removed

- **`skills/functional-core/agile_fc/`**: Entire directory deleted after all contents were absorbed, generalized, and redistributed into `scripts/`, `references/`, and `examples/`. No references to `agile_fc` remain in the skill tree.

## 2026-06-27 -- Design-Rubric Enhancements from Plan 296 / post-UCSS Retros (a prior multi-plan program)

Folded two recurring retro lessons into the design-rubric family. Both stem from the cross-cutting insight that **an auditable verdict can be clean yet blind** (Plan 296: a correct `0/18 new surface` deep-modules verdict missed three seam-fidelity defects an Analyst depth-review then caught; a temporal oracle "passed" on all-NULL data).

### Changed

- **`skills/design-rubrics/SKILL.md`**: Added a **4th shared-output discipline** ("Blind spot named" — what the verdict does NOT establish); a **seam-fidelity routing caveat** (rubric scoring is necessary-not-sufficient for any design touching ≥2 existing seams — pair with a seam-validation pass); and an **Ownership line** in the compact decision template for decisions that split shared work across units/plans.
- **`skills/deep-modules/SKILL.md`**: Added **cross-unit ownership of a shared signal as ILC** (with the no-duplication-test-misses-orphans trap) under guideline 4; **facade-preserving decomposition** as a recognized deep move (internal split behind an ISC-flat facade is deepening, not shallow multiplication — the post-UCSS god-object decompositions) under guideline 1; and a new section **"What a depth verdict does NOT establish"** (seam existence, single ownership, cross-unit sequencing) plus a **depth ≠ size** note.
- **`skills/lean-design/SKILL.md`**: Added **"a large cohesive unit is not a decomposition target"** (RCC/coupling, not line count, is the verdict — the D6 session_db do-not-split case) to "earn a name"; **"a shared definition with two owners is ceremony"** (apply rung 1 to the second owner) to the ladder; and a **discovery → deepening** note to rung 2 (a backlog of N findings is not N features).
- **`skills/deep-modules-orchestration/SKILL.md`**: Extended **Step 5 (Analyst)** with a **seam-validation** pass (mandatory when the recommendation spans ≥2 existing seams — confirm the seam exists in code, each shared signal has a single owner, and cross-unit sequencing holds), distinct from the Step-4 count audit; added a **Hard-Block** row for seam-validation failure and a **Usage Note** that a DM verdict scores surface, not seam-fidelity. This is where the Plan 296 verdict was actually produced, so the F-3 lesson lands at the workflow that emitted it.

## 2026-06-27 -- Mini-Retro Fold-Ins: Source Hygiene, Trigger Variants, Long-Suite Discipline

Three cross-plan-corroborated mini-retro findings promoted into Tier-1 core definitions (evidence: recurring across Plans 189/192/194/207/209/223/231/248/279 and the post-UCSS program (a prior multi-plan program)).

### Changed

- **`skills/mini-retro/` (SKILL.md, references/question-bank.md, references/memory-model.md, assets/mini-retro-template.md)**: Reframed the mini-retro as a **first-hand, orchestrator-authored long-term record** of the orchestrator's own execution experience and the significant challenges it observed its subagents hit -- explicitly **not** a survey of the human user. The skill no longer prompts the user: the former "ask the user a default-able batch of questions" flow is replaced by an orchestrator **self-assessment rubric** answered first-hand from lived experience + chain artifacts. The `Engagement: answered | defaults` field is replaced by `Authorship: first-hand | reconstructed` (first-hand is the ideal; reconstructed = written later from artifacts only, lower fidelity). Rationale: reasoning about agent challenges second-hand or surveying a user who did not run the chain is speculative; capturing it first-hand while fresh is the point.
- **`agents/implementer.agent.md`**: Added a standing **Source Hygiene -- No Planning Labels in Code** critical constraint with a mandatory pre-`COMPLETE` self-check. Forbids planning-label IDs in source/tests/docstrings/agent-visible runtime strings while explicitly preserving label use in planning artifacts (implementation doc, execution-state). Encodes two recorded failure modes: do not trade one forbidden label for another, and anchor cleanup greps so they cannot damage durable register IDs (e.g. a bare `\bFM-` stripping `SYS-FM-NNN`). Addresses an escape recorded in 11 mini-retros where labels reached Code Review instead of being self-caught.
- **`skills/mini-retro/SKILL.md`**: Added **Trigger variants** -- the per-plan pre-DevOps gate is no longer the only trigger. The skill now also fires (a) once at program close for multi-plan orchestrations (keyed to the program id) and (b) at \"implementation complete + about to commit\" for non-DevOps chains, and makes mini-retro artifact existence an explicit handoff precondition at the commit boundary. Addresses the placement-gap finding recorded across 6+ plans and the post-UCSS program (where a 10-step program produced no retro until a user asked).
- **`agents/qa.agent.md`**: Added a **Long-Suite Execution Discipline** section -- targeted suites first with the full suite as the final gate; never claim green without a captured exit code on multi-minute runs; report the exact invocation + canonical summary line and treat `deselected` as scope not loss; reject cherry-picked COMPLETE claims. Addresses QA/subagent stalls and passed/deselected reconciliation wobble recorded across Plans 208/210/235/261/279 and the post-UCSS program.

## 2026-06-25 (Plan 020) — Deep-Modules Skill Enrichment Merge

### Changed

- **`skills/deep-modules/SKILL.md`**: Merged enrichments from a user-supplied revised draft into the repo skill without regressing repo-only structure. Updated frontmatter `description` to name temporal decomposition, overexposure, common-case tax, change amplification, and qualitative tie-breakers. Enriched "Why this skill exists" with Unix file I/O (canonical deep) and pass-through (canonical shallow) examples. Added tie-breaker companion paragraph to "What objective means". Updated the four concept definitions: interface-comment added to ISC explicit part, temporal decomposition named as the structural cause of leakage, one-sentence comment test added to abstraction quality, unknown-unknowns added to cognitive load. Updated counting convention: interface-comment in ISC bucket, temporal-split in ILC bucket, added "Count concepts, not slots" anti-gaming paragraph, added "Two derived counts (CCT, CA)" subsection. Added "Design it Twice" planning section. Retitled guideline 2 to "Favor general-purpose interfaces — and make the common case simple" with overexposure signals and CCT-based rule. Enriched guideline 3 with deferred-delete example and mask/aggregate reductions. Retitled guideline 4 to "Complementary code belongs together (and beware splitting by time)" with temporal decomposition principle, expanded signals, CA in CouplingCount, and a cross-rubric disambiguation line distinguishing deep-modules temporal decomposition (between-units) from `functional-core` TCC (within-a-unit). Added CCT≈0 to the reframe substrate guardrails. Added "Qualitative tie-breakers" section (Hard-to-Describe, Naming precision, Obscurity/unknown-unknowns). Updated workflow three modes to reference Design-it-Twice, temporal decomposition, overexposure, and CCT/CA. Expanded scorecard template with optional CCT/CA rows and tie-breaker block. Expanded anti-pattern table from 12 to 20 rows (adds overexposure, temporal decomposition, conjoined methods, repetition, change amplification, hard-to-describe, vague name, obscurity). Expanded escape hatch with performance-tuning and over-merge caveats. Replaced "Two failure modes" with six canonical failure modes (Mistaking relocation, Over-generalizing, Slot-counting gaming, Depth rewarding obscurity, Baseline gaming, Local optimization in a bad frame) plus the False-precision closing note. Preserved all repo-only assets: `design-rubrics` family banner + lane note, "Scope: any caller-facing surface" non-code section, transition-cost subsection under guideline 1, and the externalized Examples Index with examples 02–06.

### Added

- **`skills/deep-modules/examples/07-temporal-decomposition.md`**: New externalized worked example showing how splitting modules by operation phase (read/modify/write) strands one decision across two modules (ILC, CA > 1). Frames the smell as module-boundary (between-units) with a cross-rubric note distinguishing it from `functional-core` TCC (within-a-unit).
- **`skills/deep-modules/examples/08-overexposure.md`**: New externalized worked example showing the common-case tax (CCT): reaching a commonly-wanted feature (buffered reads) forces the caller to learn rare machinery. Target: zero-config for the common case, rare capability as opt-in.

## 2026-06-24 (Plan 019) -- Design-Rubrics Skill-Family Consolidation

### Added

- **`skills/design-rubrics/SKILL.md`**: New neutral router skill for the three design-quality rubrics. Hosts the routing table (between-units → `deep-modules`; within-unit → `functional-core`; every-scale → `lean-design`), the two overlap rules, the public-function shared-artifact case, the Mermaid routing flowchart, the shared auditable-judgment spine (CONTRACT-002), and the "Framing an impactful decision" compact scorecard template (W-A).
- **`skills/functional-core/examples/`**: Pull-not-push subfolder for worked A-vs-B scoring examples (Example 1: `processOrder` monolith vs core/shell).
- **`skills/functional-core/recipes/`**: Pull-not-push subfolder for FP implementation recipes (R1: immutability patterns + cross-language mapping; R2: FP patterns + refactoring workflow).
- **`skills/lean-design/references/runtime-zone-specifics.md`**: Project-specific runtime zone rules (regulated runtime, DDS QoS, audit ledgers, plan-doc ceremony, hardware calibration) relocated from `SKILL.md` into on-demand reference.

### Changed

- **`skills/function-core/` → `skills/functional-core/`**: Renamed to fix folder↔`name:` mismatch (the `name: functional-core` was already correct). Content merged with `functional-programming`: FP technique (core/shell architecture, effect-isolation, immutability, total functions) added inline (concise); effect taxonomy collapsed to single canonical copy (F4 fix); "Rank 2-3" mislabel fixed to "Rank 3" for pure core / thin shell (F6 fix); undefined `PFR` → `PLR` in verdict rule (F7 fix); earn-a-name rule now cites `lean-design` as canonical owner; D3 back-pointer added; old sibling table removed; frontmatter trimmed to `name` + `description`.
- **`skills/lean-build/` → `skills/lean-design/`**: Renamed and generalized to all scales (function → architecture). `name:` frontmatter changed from `lean-build` to `lean-design`. Project-specific payload relocated to `references/`. Canonical owner of the "earn a name /
  > 100-line decompose-not-atomize" rule (F3 fix). D2b auditable ladder trace (Option C) added. D3 back-pointer added. Frontmatter trimmed (`license`, `argument-hint` dropped).
- **`skills/deep-modules/SKILL.md`**: D3 back-pointer added (only change).
- **`agents/planner.agent.md`**: Added W-B directive: "For impactful decisions, frame options using the deep/lean decision-scorecard in `design-rubrics`."
- **`agents/critic.agent.md`**: Added W-B directive: "For impactful decisions, frame options using the deep/lean decision-scorecard in `design-rubrics`."
- **`agents/implementer.agent.md`**: `functional-programming` → `functional-core` skill reference.
- **`USING-AGENTS.md`**: Added `deep-modules`, `design-rubrics`, `lean-design` rows; replaced `functional-programming` row with `functional-core`; updated skill descriptions.
- **`docs/architecture/system-architecture.md`**: Updated Skills section to reflect new three-rubric family + router.

### Removed

- **`skills/functional-programming/SKILL.md`**: Deleted after merge into `functional-core`. All technique content relocated: concise narrative inline in `functional-core/SKILL.md`; worked examples in `functional-core/examples/`; recipes in `functional-core/recipes/`.

## 2026-06-21 -- no-silent-assumptions major overhaul (v2.0) (originating-repo Plan 337 + Analyst study 343)

### Changed

- **`skills/no-silent-assumptions-software-planning/SKILL.md`** (v2.0): Added Stage-0 routing gate, Stage-1 ask-worthiness threshold (confidence x blast-radius matrix), blast-radius definition anchored to `BOUNDARY-*` (ADR-006), triage lenses L1-L4, enriched OPENQ template, Assumption-Hygiene carve-out, and existing-consumer precedence.

---

## 2026-06-14 (Plan 017) -- Requirements-Enforcement Skill Integration

### Added

- **`skills/requirements-enforcement/SKILL.md`**: New skill providing guarantee ledger + failure-mode registry model. Includes three-level hierarchy (class/mode/instance), maturity ladder, and phase-specific hooks for Planning, TDD, Code review, and QA. Based on ADR-002.
- **`skills/requirements-enforcement/references/enforcement.md`**: FM-enforced testing workflow reference.
- **`skills/requirements-enforcement/references/ledger.md`**: Guarantee ledger discipline reference.

### Changed

- **`skills/structured-labeling/SKILL.md`**: Replaced legacy plan-local FM-NNN subsection with FM Exposure declaration pointing to external registry IDs (per ADR-002). Traceability Map FM column is now optional and unvalidated.
- **`scripts/validate-plan-template.ps1`**: Removed FM-\* referential-integrity check (FM references now point to external registry).
- **`scripts/validate-plan-template.sh`**: Removed FM-\* referential-integrity check (parity with .ps1).
- **`scripts/test-fixtures/valid-plan.md`**: Updated to use FM Exposure model.
- **`scripts/test-fixtures/invalid-plan.md`**: Removed FM-999 reference test (FM refs no longer validated).
- **`scripts/smoke-test-plugin.ps1`**: Replaced magic skill-count check with structural assertion.

### Lost Scope (FM-merge, per CONTRACT-001 / ADR-002 / TASK-013)

The legacy plan-local `FM-NNN` model afforded four capabilities the new registry-based model does not. They are intentionally lost, not parallel:

- (a) **Registry-free in-plan failure notes** -- the legacy model allowed a fully self-contained failure-mode note inside a single plan with no project-level artifact. The new model requires attribution to a (possibly candidate) ledger guarantee.
- (b) **Prose-only failure modes with no test** -- the legacy model permitted unfalsifiable risk prose. The new model requires every mode to be defined by a single detection oracle.
- (c) **Validator referential-integrity check on FM references** -- the `validate-plan-template.ps1`/`.sh` cross-existence check for `FM-*` is **removed, not weakened**. Registry IDs live out-of-plan and cannot be validated from a single plan.
- (d) **Traceability Map "Failure Mode" column fate** -- retained as an _optional, unvalidated_ column referencing registry mode IDs (or `--`). See [skills/structured-labeling/SKILL.md](skills/structured-labeling/SKILL.md) Traceability Map section.

The deferred ledger/registry canonical paths and hook-script integrations are tracked separately under "Deferred" / OPENQ-003.

## 2026-06-04 (Plan 015) -- Deep-Modules Integration and Skill Consolidation

### Added

- **`DECISION-*` label specification** in `skills/structured-labeling/SKILL.md`: format block, authoring rules (Planner-only), triggers, hard rules (skip-if-empty, one-paragraph-max, bidirectional back-reference invariant, promotion path), distinction-from-existing-labels table, §3 "Binding Decisions" placement, and §17 Traceability Map `Decisions` column convention.
- **`DECISION-*` back-reference invariant check** in `skills/code-review/SKILL.md`: Critic fires check when plan contains DECISIONs; REJECTs plans with missing back-references.
- **Code Reviewer `deep-modules` wiring**: Code Reviewer always-loads `deep-modules`; severity rubric now requires interface depth assessment for every review.
- **`skills/deep-modules-orchestration/SKILL.md`**: New skill providing orchestrated multi-agent workflow for interface depth decisions (triggers, inputs, 6-step workflow, artifacts, hard-block rules, stop conditions).
- **ICA invocation contract**: `skills/improve-codebase-architecture/SKILL.md` now documents `plan-ref: <plan-id>` input convention.
- **`docs/architecture/diagram-templates.md`**: Relocated and co-located with `system-architecture.md`.
- **`agents/analyst.references/uncertainty-review-template.md`**: Relocated from analysis-methodology skill.
- **DM SHOULD-references**: Single-line cross-references added to `cross-repo-contract`, `functional-programming`, and `no-silent-assumptions-software-planning` skills.

### Changed

- **`skills/structured-labeling/SKILL.md`**: Absorbed "Required Fields" portion of `executive-summary`; added `DECISION-*` specification.
- **`agents/planner.agent.md`**: Receives executive-summary interview/workflow inline; receives `planner-execution-orchestration` runtime-params template inline; receives `deep-modules` always-load; receives `deep-modules-orchestration` cross-reference.
- **`agents/analyst.agent.md`**: Absorbs confidence-levels table and gap-tracking template from `analysis-methodology`; receives `deep-modules` always-load.
- **`agents/code-reviewer.agent.md`**: Updated with `deep-modules` always-load (was already present).
- **`agents/critic.agent.md`**: Transitioned from `deep-modules` always-load to LOAD-ON-DEMAND; added DM consideration step in Review Method.
- **`agents/security.agent.md`**: Added `Deep Modules (LOAD ON DEMAND)` directive.
- **`agents/qa.agent.md`**: Added shallow-interface-signal Core Responsibility item (LOAD `deep-modules` ON DEMAND).
- **`agents/devops.agent.md`**: Added `release-procedures` skill-load directive.
- **`skills/code-review/SKILL.md`**: Merged from `code-review-checklist` and `code-review-standards`; added interface depth requirement section.
- **`skills/implementation-principles/SKILL.md`**: Added "Primary Lens: Deep Modules" section; added SOLID detection patterns appendix; trimmed Separation-of-Concerns section.
- **`skills/improve-codebase-architecture/LANGUAGE.md`**: Streamlined from ~37 to ~25 lines; removed "Rejected framings" section; added non-redefinition disclaimer.
- **`skills/improve-codebase-architecture/SKILL.md`**: Added Mission section, Alignment with deep-modules section, Glossary cross-reference, Explore-step menu-shaped-API bullet.
- **`skills/improve-codebase-architecture/DEEPENING.md`**: Replaced duplicate seam section with cross-reference.
- **`skills/improve-codebase-architecture/HTML-REPORT.md`**: Replaced vocab block with cross-references.
- **`skills/improve-codebase-architecture/INTERFACE-DESIGN.md`**: Added DM-gate bullet in Step 3.
- **Always-load DM roster**: Now exactly 5 agents (Implementer, Architect, Code Reviewer, Planner, Analyst) per REQ-004.

### Removed

- **`skills/code-review-checklist/`**: Merged into `skills/code-review/`.
- **`skills/code-review-standards/`**: Merged into `skills/code-review/`.
- **`skills/engineering-standards/`**: Absorbed into `implementation-principles` + `deep-modules`.
- **`skills/planner-execution-orchestration/`**: Inlined into `agents/planner.agent.md`.
- **`skills/analysis-methodology/`**: Absorbed into `agents/analyst.agent.md`.
- **`skills/executive-summary/`**: "Required Fields" absorbed into `structured-labeling`; interview/workflow inlined into `agents/planner.agent.md`.

### Renamed

- **`uncertainty-review-template.md`**: From `skills/analysis-methodology/references/` to `agents/analyst.references/`.
- **`diagram-templates.md`**: From prior location to `docs/architecture/`.

## 2026-06-05 (Plan 016) -- Deep-Modules Skill Reorganization

### Added

- **`skills/deep-modules/examples/`**: New directory for extracted and new worked examples.
- **`skills/deep-modules/examples/02-config-parser-gate-fires.md`**: Extracted from SKILL.md; demonstrates gate's capability-equivalence check and unbundling.
- **`skills/deep-modules/examples/03-substrate-reframe.md`**: Extracted from SKILL.md; demonstrates the real win quadrant (substrate beats menu).
- **`skills/deep-modules/examples/04-docs-folder-naming.md`**: New cross-domain example; demonstrates rubric applies beyond code; explicit transition-cost callout.
- **`skills/deep-modules/examples/05-cli-command-grouping.md`**: New CLI menu-vs-substrate example; smallest non-code substrate-reframe case.

### Changed

- **`skills/deep-modules/SKILL.md`**: Added Scope note (rubric applies to any caller-facing surface, not just code); added Transition-cost subsection under guideline 1; added gate clarification (caller need not be a program); added Examples Index section; extracted Worked Examples 2 and 3 to side files. Net line reduction: 430 -> 379 lines (~12%); <=240 target missed due to incorrect baseline estimate in plan (327 vs actual 430).

## 2026-06-01 (Plan 014) -- Non-ASCII Character Cleanup

### Changed

- **Repository hygiene**: Removed 836 occurrences of unwanted Unicode typography characters and replaced with ASCII equivalents across 65 modified content files (69 total Phase-1 staged files including 4 new scripts/fixtures). Substitutions: em-dash -> `--`, en-dash -> `-`, non-breaking hyphen -> `-`, smart quotes -> `"` or `'`, ellipsis -> `...`, arrows -> `->`, `<-`, `<->`, comparison operators -> `<=`, `>=`, `!=`, multiplication sign -> `x`, middle dot -> `*`. Box-drawing characters (2920+) and status emoji (300+) preserved.
- **`docs/knowledge-base/python-best-practices.md`**: Removed 92 ChatGPT Deep-Research citation artifacts (PUA U+E200..U+E202 spans totaling 574 codepoints).

### Added

- **`scripts/cleanup-non-ascii.ps1`**: Idempotent, encoding-preserving substitution script with `-WhatIf` dry-run mode and unknown-character warnings to stderr. Uses numeric escape sequences only (REQ-011 compliant).
- **`scripts/test-fixtures/non-ascii-input.md`** and **`scripts/test-fixtures/non-ascii-expected.md`**: Round-trip verification fixtures for the cleanup script.
- **`scripts/test-fixtures/generate-fixtures.ps1`**: Helper script to regenerate test fixtures with proper non-ASCII characters.

## 2026-05-28 (Plan 009) -- Plan-Alignment + ADR Integration

### Added

- **`skills/adr-authoring/SKILL.md`** -- canonical ADR template, numbering rules (independent `docs/adr/` number space, scan-max+1, 3-digit format), and supersession status convention. Loaded by Planner, Architect, Critic, Implementer, Code Reviewer, and Analyst.
- **`docs/adr/`** -- canonical home for Architecture Decision Records, bootstrapped with **ADR-001** (ADR + `CONTEXT.md` conventions, including a meta-evolution section per Architect RC-003). ADRs are evergreen and never moved to `closed/`.
- **Root `CONTEXT.md`** -- canonical domain glossary, seeded with foundational terms; Architect-owned, evergreen. Scope clarified per Architect RC-002.
- **`docs/architecture/`** -- relocation target for `system-architecture.md`, now containing a Decisions Index that points to `docs/adr/` rather than embedding decisions inline.
- **`Review_State` frontmatter field** on plans (separate from lifecycle `Status:`) per Architect RC-001, enabling Architect/Critic review routing without overloading the status enum. Recognized values: `architect-review`, `critic-review`, `approved`.
- **`ADR-*` and `ADR-PROPOSED-*` label prefixes** registered in `skills/structured-labeling/SKILL.md` with numbering rules and usage guidance.
- **`skills/plan-alignment-session/`** -- interactive planning skill that resolves ambiguity one question at a time and captures decisions into `CONTEXT.md` / ADRs as they crystallize. Integrated into the Planner workflow per decisions D1-D11.

### Changed

- **Loader/approval routing across agents** per decisions D5/D9/D10: Planner, Architect, Critic, Implementer, Code Reviewer, Analyst, and Roadmap agents updated to load `adr-authoring` and follow the documented Architect -> Critic -> User routing for plans that modify architectural conventions.
- **`skills/document-lifecycle/SKILL.md`** -- added evergreen carve-out for ADRs, `docs/architecture/`, and root `CONTEXT.md`; clarified ADR numbering is independent of `.agent-output/.next-id`.
- **`skills/architecture-patterns/SKILL.md`** -- now references `adr-authoring` as the canonical ADR template source rather than duplicating it.
- **`skills/structured-labeling/SKILL.md`** -- registered `ADR-*` / `ADR-PROPOSED-*` labels and `Review_State` field.
- **Validator scripts** (`scripts/validate-plan-template.ps1` and `.sh`) -- accept the `Review_State` frontmatter field and `ADR-*` / `ADR-PROPOSED-*` label references in plans.

### Removed

- **Stale `grill-with-docs` and `CONTEXT-MAP` machinery references** across `agents/**` and `skills/**` (grep verification: zero matches outside historical changelog entries).

### Moved

- `system-architecture.md` -> `docs/architecture/system-architecture.md` (Decisions Index format; decisions now live in `docs/adr/`).

## 2026-05-13 (Plan 007) -- Boundary-Test Discipline

### Added

- **"Mocking Above the Boundary" anti-pattern**: New Anti-Pattern 6 in `skills/testing-patterns/references/testing-anti-patterns.md` documenting the recurring failure mode where unit tests pass while production fails because parsers, serializers, network clients, and trust boundaries are mocked above the unit under test.
- **Boundary-Aware Testing section** in `skills/testing-patterns/SKILL.md` introducing the **Load-Bearing Test Table** authoring requirement -- a thinking tool for identifying which tests carry trust/wire-format weight (with explicit "no boundaries crossed" as an acceptable answer to avoid bureaucratic friction).
- **First-class `BOUNDARY-*` label** registered in `skills/structured-labeling/SKILL.md` canonical label table for tagging boundary-spanning requirements/tests.
- **WIRE-001/002/003 post-implementation gates** in `skills/code-review-standards/SKILL.md` with calibrated severities (P2 for style, P0 reserved for trust/security regressions).
- **Fixture Hygiene subsection** (SEC-001/002/003) in `skills/testing-patterns/SKILL.md` covering credential, PII, and trust-token discipline in test fixtures.
- **Agent pointers (<=5 lines each)** in `agents/implementer.agent.md`, `agents/code-reviewer.agent.md`, `agents/qa.agent.md`, and `agents/critic.agent.md` directing each role to the new boundary/wire/fixture guidance without duplicating rules.
- **QA coverage-matrix refinement (REQ-008)** in `agents/qa.agent.md` requiring boundary-aware coverage analysis when relevant.

### Fixed

- **Plan-template validator false-positive**: `scripts/validate-plan-template.ps1` section-order detection now anchors to heading lines (`^#+\s*(\d+\.)?\s*<Name>`) instead of free-text label matches, eliminating spurious "out of order" warnings when label tokens appear in body prose. Bash counterpart (`scripts/validate-plan-template.sh`) updated with parity comment per `docs/VALIDATOR-PARITY-CHECKLIST.md` (the simpler bash check cannot manifest the false positive).

## 2.0.0 -- 2026-05-04 (Plan 005) -- **BREAKING CHANGE**

### Changed (Breaking)

- **Repository consolidated to single-source plugin layout**: The `vs-code-agents/` directory has been removed. The plugin-discoverable layout at the repository root (`agents/`, `skills/`, `hooks/`) is now the **only** source of truth.
  - **Migration**: If you have scripts, bookmarks, or documentation referencing `vs-code-agents/`-rooted paths, update them to root-level paths (e.g., `vs-code-agents/skills/foo/` -> `skills/foo/`, `vs-code-agents/planner.agent.md` -> `agents/planner.agent.md`).
  - **External forks**: Re-sync with the new layout; the duplicate tree no longer exists.

- **`scripts/sync-plugin.sh` removed**: The sync script existed solely to keep the two trees in lockstep and is no longer needed.

- **Smoke-test scripts simplified**: The `--canonical` / `-Canonical` and `--sync-check` / `-SyncCheck` flags have been removed from `scripts/smoke-test-plugin.sh` and `scripts/smoke-test-plugin.ps1`. Only the default plugin validation mode remains.

- **`plugin.json` `name` field corrected**: Changed from `"Multi-Disciplinary Team Agents Plugin"` (invalid -- contained uppercase and spaces) to `"multi-disciplinary-team-agents"` (valid kebab-case). This fixes a silent plugin load failure per [VS Code plugin docs](https://code.visualstudio.com/docs/copilot/customization/agent-plugins).

### Moved

- **Reference documents relocated to skill-local `references/` folders**:
  - `skills/reference/uncertainty-review-template.md` -> `skills/analysis-methodology/references/uncertainty-review-template.md`
  - `skills/reference/security-language-vuln-reference.md` -> `skills/security-patterns/references/security-language-vuln-reference.md`
- **`skills/reference/` directory removed** (contents moved as above).

### Added

- **Three new authoring skills** (grounded in Anthropic, OpenAI, and Microsoft VS Code official documentation):
  - `skills/agent-authoring/SKILL.md` -- Design requirements, best practices, anti-patterns, and worked examples for custom agent definitions.
  - `skills/skill-authoring/SKILL.md` -- Design requirements, best practices, anti-patterns, and worked examples for skill definitions.
  - `skills/hook-authoring/SKILL.md` -- Design requirements, best practices, anti-patterns, and worked examples for lifecycle hook configurations.
- **Skill count increased from 19 to 22**.

### Updated

- All intra-repo path references updated from `vs-code-agents/...` to root-level paths in:
  - `agents/planner.agent.md`
  - `skills/execution-orchestration/SKILL.md`
  - `skills/execution-orchestration/references/execution-state.schema.md`
  - `skills/structured-labeling/SKILL.md`
  - `skills/plan-status-reporting/SKILL.md`
  - `README.md` (structure tree, smoke-test examples, path references)
  - `USING-AGENTS.md`
  - `AGENTS-DEEP-DIVE.md`

## 2026-03-24 (Plan 003) -- Failure-Mode label and requirement-centric Traceability Map

### Added

- **FM-\* (Failure Mode) label prefix**: New required label for identifying how requirements or components can fail, with impact and mitigating references. FM-\* is a required subsection within the Risks section (or "None identified").
- **Traceability Map -- new requirement-centric format**: Required columns are now `Requirement | Tasks | Tests | Risk | Failure Mode`. Every REQ-\* must appear as a row, and all cross-references must resolve to existing labels in the plan body.
- **Deep cross-reference validation in validators**: Both `validate-plan-template.sh` and `.ps1` now check that all TASK-_/TEST-_/RISK-_/FM-_ references in the Traceability Map exist elsewhere in the plan. Missing references produce errors; missing risk analysis produces warnings.
- **Backwards compatibility for old-format plans**: Plans using the old Phase->Files traceability map format (Plans 001, 002) are automatically detected by column headers and exempted from new validation checks.

### Changed

- **Traceability Map changed from recommended to required**: Section 16 in the plan template is now mandatory (structured-labeling skill updated).
- **`plan-status-reporting` skill**: Removed Phase->File traceability map guidance. File verification now uses the FILE-\* section instead.
- **`planner.agent.md`**: Updated section ordering to show Traceability Map as required, added FM-\* guidance in Risks section documentation, specified required Traceability Map columns.
- **`critic.agent.md`**: Added Traceability Map validation to template checks -- verifies correct columns, all REQs present, cross-references resolve, and FM-\* subsection exists.
- **Validation checklist in structured-labeling skill**: Added four new items for Traceability Map compliance.

### Fixed

- **`validate-plan-template.sh`**: Fixed section extraction regex to match `## Traceability Map` specifically rather than any heading containing "Traceability Map" (prevented false positive matches on plan titles).
- **`validate-plan-template.ps1`**: Same fix applied to PowerShell version.

## 2026-03-24

### Added

- **`scripts/smoke-test-plugin.sh`**: Bash smoke test script validating plugin structure (plugin.json, agent frontmatter, skill frontmatter, hooks.json, no stale references, no duplicate agent names). Supports `--canonical` flag to validate source directory and `--sync-check` flag to detect drift between canonical and plugin copies.
- **`scripts/smoke-test-plugin.ps1`**: PowerShell equivalent with identical checks and output format.
- **`scripts/install-probe.sh`**: Level 2 install probe that creates a temporary VS Code user-data directory with plugin settings for manual verification. Supports `--launch` flag to auto-launch VS Code.
- **`scripts/install-probe.ps1`**: PowerShell equivalent of the install probe.
- **Plugin Testing documentation**: New "Plugin Testing" section in README.md covering smoke tests, install probe, Level 3 gap, and Chat Diagnostics reference.

### Fixed

- **`vs-code-agents/skills/analysis-methodology/SKILL.md`**: Added missing YAML frontmatter (`name`, `description`) -- skill was not discoverable by VS Code.
- **`vs-code-agents/skills/cross-repo-contract/SKILL.md`**: Added missing YAML frontmatter -- skill was not discoverable by VS Code.
- **`vs-code-agents/skills/no-silent-assumptions-software-planning/SKILL.md`**: Changed `name: no-silent-assumptions.software-planning` to `name: no-silent-assumptions-software-planning` (hyphens) to match directory name.
- **`vs-code-agents/skills/executive-summary/SKILL.md`**: Removed code fence wrapping (` ```skill `) so frontmatter is at document boundary where VS Code expects it.
- **`vs-code-agents/skills/structured-labeling/SKILL.md`**: Removed code fence wrapping -- same fix as executive-summary.

## 2026-03-20

### Added

- **Plugin packaging**: Repository restructured as a VS Code Agent Plugin. Install via `Chat: Install Plugin From Source` with the Git URL -- all 13 agents and 19 skills are immediately available.
- **`plugin.json` manifest**: Plugin metadata at repo root (name: "Multi-Disciplinary Team Agents Plugin", version 1.0.0).
- **`agents/` directory**: Plugin-discoverable copies of all 13 `.agent.md` files at repo root.
- **`skills/` directory**: Plugin-discoverable copies of all 19 skill directories and reference docs at repo root.
- **`hooks/hooks.json`**: Plugin hooks for plan validation (PostToolUse) and active orchestration context injection (UserPromptSubmit).
- **`hooks/user-prompt-submit.sh`**: Bash hook that reads `.agent-output/planning/*-execution-state.yaml` and injects `[Active Orchestrations]` context into every agent prompt.
- **`hooks/user-prompt-submit.ps1`**: PowerShell equivalent of the UserPromptSubmit hook with identical output per CONTRACT-003.
- **`scripts/sync-plugin.sh`**: Script to sync plugin directories (`agents/`, `skills/`) from canonical source (`vs-code-agents/`).
- **Migration documentation**: README guidance for detecting and removing workspace-level agent duplicates after plugin installation.
- **Planner as Orchestrator**: README and USING-AGENTS documentation explaining Planner's role as the primary multi-plan orchestrator.

### Changed

- **Renamed `agent-output/` to `.agent-output/`**: All agent, skill, script, and documentation references updated. The dot-prefix aligns with conventions (`.github/`, `.vscode/`) and simplifies `.gitignore` management. Users with existing `agent-output/` directories should rename: `mv agent-output .agent-output`.
- **README header**: Updated from "VS Code Agents" to "Multi-Disciplinary Team Agents Plugin" with new intro paragraph.
- **Repository structure**: Updated to show plugin layout (`plugin.json`, `agents/`, `skills/`, `hooks/`, `scripts/`).

## 2026-02-04

### Added

- **git-commit-message skill**: Craft best-practice git commit messages with subject/body formatting rules, imperative mood, and 50/72 character guidelines. Supports Conventional Commits (with Type selection guidance and breaking change handling) when explicitly requested. DevOps loads this skill when crafting commit messages.

- **plan-status-reporting skill**: Evidence-based plan status reporting in strict plain-text format. Includes output template, evidence hierarchy rules, and worked example. Planner agent loads this skill when asked for current plan status.

## 2026-02-03

### Added

- **functional-programming skill**: Integrated into the skills library with MIT license and metadata. Guides pure functions, immutability, composition, and side-effect isolation; referenced in Implementer agent and Available Skills table.
- **implementation-principles skill**: Tie-breaker guidance for implementers covering DRY (with AHA nuance), YAGNI, Rule of Three, composition over inheritance, separation of concerns, POLA, Boy Scout Rule, defensive programming, and appropriate exception use.

### Changed

- Agent definitions no longer proactively ask for application/release version identifiers, recommend version bumps, or mandate version consistency management.

## 2026-02-01

### Added

- **execution-orchestration skill**: Role-agnostic orchestration contract with strict gating (`COMPLETE` vs `HARD BLOCK`), reject/redirect rules, and execution-state guidance.
- **planner-execution-orchestration skill**: Planner-specific preset/template for using orchestration without assuming skill-to-skill imports.
- **Execution-state schema reference**: YAML-first, JSON-compatible schema doc for the authoritative state file.

### Changed

- **Planner guidance**: Added orchestration-mode guidance (post-Critic approval only) and standardized the authoritative execution-state file location under `.agent-output/planning/`.
- **Docs**: Updated entry points to mention the new skills and the state file convention.

## 2026-01-29

### Removed

- Persistent-memory integration references across agent definitions (tool IDs, instructions, and the dedicated persistence guidance section).
- Persistent-memory skill and the accompanying example reference doc.

## 2026-01-18

### Added

- **Code Reviewer agent**: New quality gate between Implementer and QA. Reviews code for architecture alignment, SOLID/DRY/YAGNI/KISS, TDD compliance, documentation/comments, security, and code smells. Can reject on quality alone.
- **code-review-standards skill**: Extracted review checklist, severity definitions, and document templates for reuse.

### Changed

- **UAT agent simplified**: Now a quick, document-based value validation (read-only tools only). Relies on Implementation, Code Review, and QA docs rather than inspecting code directly.
- **Implementer handoff**: Now goes to Code Reviewer instead of QA directly.
- **Workflow updated**: `Implementer -> Code Reviewer -> QA -> UAT -> DevOps`

## 2026-01-15

### Added

- Uncertainty-aware issue analysis guidance across Analyst, Architect, and QA agents.
- Analyst hard pivot trigger to avoid forced root-cause narratives when evidence is missing.
- Normal vs debug telemetry criteria, plus a minimum viable incident telemetry baseline.
- Reusable uncertainty review template: `vs-code-agents/reference/uncertainty-review-template.md`.

### Changed

- QA guidance now prefers validating telemetry via structured fields/events over brittle log string matching.
