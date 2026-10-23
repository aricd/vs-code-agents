# Backlog grooming -- mandatory checks

Run every check on every plan in scope. Each check gives:
- **Question:** what the check establishes;
- **How:** the procedure, with the evidence to cite;
- **Failure signatures:** patterns that indicate a defect;
- **Severity:** default grading.

Cite file:line for every finding, against the project's pinned source of truth.

---

## C1 -- Code trace

**Question:** Does the mechanism the plan relies on actually behave as the plan claims when a
real request or message flows through it?

**How:**
1. Pick one concrete input the plan's main path handles: a request, message, poll or push.
2. Follow it through the real code from its entry point to its final effect: state written,
   reply sent, notification fired.
3. At each hop, note what is passed, what is dropped, and what locks are held.
4. Repeat for the failure path: timeout, error response, exception after the call.
5. Repeat for the retry path: what gets re-executed?

**Failure signatures:**
- A parameter the plan depends on is never passed at that hop (e.g. a payload argument that
  exists on a function but every caller omits it).
- A retry wrapper that re-runs the whole handler, repeating side effects already performed.
- Blocking I/O performed while holding a lock that other paths (reads, other ingress) also need.
- A failure collapsed to a sentinel (`None`, empty) that the caller drops without any signal.
- A state update with no change notification, so subscribers never hear about it.
- A lookup that falls through silently when nothing matches.
- A sink or target declared only inside a construct with different semantics (e.g. a "request"
  rule that is never requested), making the design depend on an undeclared overload.

**Severity:** **Blocking** if the traced path contradicts a plan claim or a requirement.
**High** for silent failure, lock hazards, or replayed side effects the plan does not disclose.

---

## C2 -- ADR overlap

**Question:** Has the plan reconciled every existing architectural decision in its problem
space?

**How:**
1. Grep `docs/adr/` for the plan's core nouns: the mechanism, the protocol, the seam, the
   capability.
2. For each hit, read its Decision and its Considered Options.
3. Confirm the plan cites the ADR and either conforms to it or proposes an explicit amendment.

**Failure signatures:**
- A plan that designs its own version of something an ADR already owns (a registry, an outcome
  model, a failure taxonomy).
- A plan that re-introduces an option an ADR evaluated and **rejected**, without citing the
  rejection.
- A companion ADR whose "Related ADRs" section omits the overlapping ADR.

**Severity:** **Blocking** for re-introducing a rejected option. **High** for an uncited
parallel design.

---

## C3 -- Demonstration feasibility

**Question:** Can each `[Demonstrated]` or live E2E acceptance criterion pass as written, and
would passing prove the claim?

**How:**
1. For each criterion, name the observable it reads.
2. Confirm from the target's real code or config that the observable carries the data the
   criterion expects.
3. Name what triggers the flow in production, and confirm some plan builds that trigger.
4. Confirm the demonstration does not require a capability another plan has moved out of scope.

**Failure signatures:**
- Success read from a response that is an empty acknowledgement (e.g. `202 {}`), where the real
  data arrives elsewhere.
- A demonstration whose triggering caller no plan builds.
- A demonstration that mutates real state, where a non-mutating probe would prove the same
  thing.
- An endpoint that is a stub in the target, so it succeeds no matter what.

**Severity:** **Blocking** if the criterion cannot pass. **High** if it can pass without proving
the claim.

---

## C4 -- Necessity (supply and demand)

**Question:** Is every new primitive, mechanism or ingress justified by evidence on **both**
sides?

**How:**
- **Supply:** show that the capability cannot be expressed with existing primitives, or that the
  data is available only through the proposed channel. Cite a composition attempt or the
  source.
- **Demand:** name the consumer: a specific component, data item, requirement or recorded user
  goal that needs it.
- Check the item's placement. A candidate primitive lacking either side belongs on the user
  decision list, not in task scope.

**Failure signatures:**
- A necessity gate that checks only supply ("the data is only published here").
- A build phase that proceeds automatically once a gate passes, without a user decision point.
- "Needs a new primitive" asserted without a composition attempt.

**Severity:** **Blocking** if an unjustified mechanism is in task scope. **High** if the gate
exists but auto-proceeds.

---

## C5 -- Side effects

**Question:** Can any call the plan introduces change external state, and if so, is that
declared, gated, idempotent under retry, and visible on failure?

**How:**
1. Enumerate every outbound call the plan introduces or re-routes.
2. For each, find its declared effect, if the project has an effect vocabulary. Do not infer
   the effect from the HTTP method or the call's name.
3. Confirm mutations go only through the project's gated write path.
4. Check retry and restart behaviour for replay (see C1).
5. Check that failures produce a classified, visible outcome rather than a silent sentinel.

**Failure signatures:**
- A background or trigger-driven path that can reach a mutating endpoint, bypassing gating.
- "Read-only" asserted by convention rather than enforced at the call boundary.
- Retries or install-time replays of calls that may mutate.
- All failures collapsed into one silent value.

**Severity:** **Blocking** for an ungated mutation path. **High** for replay or silent failure.

---

## C6 -- Internal consistency

**Question:** After its latest revision, does the plan say one thing?

**How:** compare these sections for agreement on scope, mechanism and touched files:
- Value Statement and Objective;
- Context;
- `REQ-*` and `CON-*`;
- Contracts;
- Deferred Items;
- Files;
- diagrams;
- the Traceability Map.

**Failure signatures:**
- An Objective still claiming "unchanged" or "zero touches" after a revision changed that.
- A deferral saying X is out of scope while a contract implements X.
- Diagrams or demonstration targets that name removed components.
- Duplicate changelog entries; separator rows that don't match their headers.

**Severity:** **High** when it concerns scope or mechanism. **Medium** otherwise. Purely
mechanical defects are fixed in Stage 6.

---

## C7 -- Approval-state consistency

**Question:** Do the recorded approvals still cover the plan as it now stands?

**How:** compare the approval dates and changelog against later material changes and later
recorded user decisions. Compare the frontmatter against the approval table.

**Failure signatures:**
- Approvals granted before a scope-changing revision or user decision.
- Frontmatter says approved while the table says pending, or the reverse.

**Severity:** **High**. A plan with stale approvals cannot be **Ready**.

---

## C8 -- Recorded-decision conformance

**Question:** Does the plan honour every recorded user decision and ruling that applies to it?

**How:** check the plan against the decision sources gathered in Stage 0. For each applicable
decision, confirm the plan conforms, or explicitly raises the conflict as a U item.

**Failure signatures:**
- Scope expanded into an area a ruling placed out of scope, with no mention of the ruling.
- A design choice a ruling reserved for the user, made inside the plan.
- A conflict resolved silently in either direction.

**Severity:** **Blocking** until raised to the user.
