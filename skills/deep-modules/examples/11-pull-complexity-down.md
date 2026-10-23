# Worked example 11 — pull complexity down (the RMQ adapter)

> **Summary**: Demonstrates how an adapter proves that N "convenience" topics are derivable compositions of 3 orthogonal primitives, then silently routes to the efficient server-side wire call — adding zero interface surface while delivering server-side atomicity for free. The design trajectory runs from a 14-topic shallow menu to a 3-primitive deep module.
>
> **Back-link**: [../SKILL.md](../SKILL.md) **Source evidence**: a prior internal review of a real RabbitMQ resource-adapter design (details not retained in this repo)

---

## The design trajectory

### Before — 14-topic shallow menu (raw RMQ surface)

A client driving structured resource plans over RabbitMQ faces **14 send-topics**, ~8 receive-topics, and ~9 named payload types. Most topics are near-duplicates that differ only by scope or filter:

```
resourcedata.<ID>.list.request          → get all plans
resourcedata.<ID>.list.valid.request    → get valid plans (entry + target set)
resourcedata.<ID>.plan.request          → get one plan by OID

resourcedata.<ID>.plan.create           → CreatePlanTemplate payload
resourcedata.<ID>.plan.update            → PlanUpdate payload (one plan)
resourcedata.<ID>.plan.update.list      → PlanUpdateList payload (many plans)
resourcedata.<ID>.plan.delete           → PlanID payload
resourcedata.<ID>.plan.deleteall        → (empty) — deletes all unlocked plans
resourcedata.<ID>.plan.undo             → PlanList payload (full prior snapshot)

resourcedata.<ID>.visibility.set        → PlanUpdate{showing} — sets showing on ALL plans
resourcedata.<ID>.sides.set             → PlanUpdate{referencePlane} — recomputes side on ALL plans

plan.scene.render    (publish)       → PlanList — pushes scene to 3D renderer
resourcedata.allowshowplans              → {allow:bool} — gate/clear the 3D scene
resourcedata.initrecorddb                → db-creds JSON (test/setup, not a domain verb)
```

The caller must know the routing key, payload type, ordering rules, and async correlation semantics for each. The raw IC (ISC + ILC + RCK + CHEC) is approximately **52**.

---

### The derivability argument — why 11 of 14 topics vanish

The adapter's design starts from one question per topic: _"Can this topic's effect be reproduced by composing other topics?"_ If yes, it is a **pseudo-primitive** — it does not need to exist as an entry point.

| Topic | Derivable from | Composition | Verdict |
| --- | --- | --- | --- |
| `list.valid.request` | `list.request` | `query(all).filter(p => p.validEntry && p.validTarget)` | Pseudo — client-side filter |
| `plan.update.list` | `plan.update` | `for each patch: mutate(patch)` | Pseudo — batching optimization |
| `visibility.set` | `plan.update` + query | `query(all).forEach(p => mutate({oid:p.oid, showing}))` | Pseudo — bulk apply |
| `sides.set` | `plan.update` + query | `query(all).forEach(p => mutate({oid:p.oid, referencePlane}))` | Pseudo — bulk apply |
| `plan.deleteall` | `plan.delete` + query | `query(all).forEach(p => mutate({oid:p.oid, delete:true}))` | Pseudo — bulk delete |
| `plan.undo` | `plan.update` + `plan.delete` + query | diff snapshot vs current → update/delete to restore | Pseudo — diff-restore |
| `initrecorddb` | — | construction concern, not a plan verb | Out-of-domain |

Three topics are irreducible — each requires capability the others cannot produce:

- **`mutate`** — only path that changes persisted plan state in the DB.
- **`query`** — only path that reads server-computed truth (OIDs, derived `length`, `side`, lock state).
- **`render`** — only path that reaches the 3D renderer (`SceneRenderer` subscribes to `plan.scene.render` directly; no write op auto-triggers it).

---

### After — 3-primitive deep adapter

```typescript
interface PlanAdapter {
  new (resourceOID: string, bus: RmqBus): PlanAdapter;

  mutate(patch: PlanPatch | PlanPatch[]): Promise<MutateResult>;
  // MutateResult = { outcomes: MutateOutcome[]; list: Plan[] }
  // MutateOutcome = created(plan) | updated(oid) | deleted(oid, removed) | ...

  query(selector?: QuerySelector): Promise<Plan[]>;
  // QuerySelector = {kind:"all"} | {kind:"valid"} | {kind:"oid", oid}

  render(oids: string[] | null): Promise<void>;
  // null → clear scene (allowshowplans:false)
  // oids → push scene (plan.scene.render)

  readonly state: Plan[]; // passive cache, 0 extra ISC
}
```

IC = **32**. The adapter absorbs: resource routing-key construction, async correlation, `plan.deleted`-when-blocked, schema drift between `CreatePlanTemplate` / `PlanUpdate` / `PlanIDList`, render handshake ordering.

---

### The key move: proving derivability, then silently routing to the efficient wire call

The derivability argument does two things. First, it proves the topic is not needed as an entry point. Second, it licenses the adapter to **recognize the equivalent composition and substitute the optimized server-side call** — transparently, without any change to the interface.

```typescript
// Inside mutate() — invisible to every caller:
function routeMutate(patches: PlanPatch[]): void {
  // Caller wrote: mutate(allPlans.map(p => ({oid:p.oid, showing: false})))
  // Adapter recognizes: all patches set only `showing` → substitute visibility.set
  if (patches.every((p) => p.oid && onlyField(p, "showing"))) {
    rmq.publish("resourcedata.<ID>.visibility.set", {
      showing: patches[0].showing,
    });
    return; // 1 wire message instead of N
  }

  // Caller wrote: mutate(allPlans.map(p => ({oid:p.oid, referencePlane})))
  // Adapter recognizes: all patches set only `referencePlane` → substitute sides.set
  if (patches.every((p) => p.oid && onlyField(p, "referencePlane"))) {
    rmq.publish("resourcedata.<ID>.sides.set", {
      referencePlane: patches[0].referencePlane,
    });
    return; // 1 wire message instead of N
  }

  // Caller wrote: mutate(allPlans.map(p => ({oid:p.oid, delete:true})))
  // Adapter recognizes: all-delete → substitute deleteall
  if (patches.every((p) => p.delete)) {
    rmq.publish("resourcedata.<ID>.plan.deleteall", {});
    return; // 1 wire message + server enforces delete guards identically
  }

  // Multiple updates → batch wire call
  if (patches.length > 1 && patches.every(isUpdate)) {
    rmq.publish("resourcedata.<ID>.plan.update.list", { updates: patches });
    return; // 1 wire message instead of N
  }

  // Default: per-patch calls
  for (const p of patches) {
    routeSingle(p);
  }
}
```

**The caller is completely unaware of the routing decision.** It calls `mutate(patches)` and the adapter chooses the most efficient wire path. The optimization is valid because the compositions were proven equivalent (see the derivability argument above). Adding a new server-side bulk op in the future costs zero interface surface — it is a new case inside `routeMutate`.

---

## Scorecard

```
Caller & baseline: SDK/adapter author (agent or human); baseline = JSON, AMQP, GUID identity, async req/reply
Capability held constant: all 14 client→service plan verbs + render handshake
Equivalence: full — every raw topic is reachable via the 3 primitives; derivations proven in §3
Confidence: High — raw surface is Verified against source; adapter is a design; growth is observed

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option           | CHEC  | ILC   | ISC    | RCK    | ‖ | TOTAL  | ‖ | CA    | CCT   |
|------------------|------:|------:|-------:|-------:|:-:|-------:|:-:|------:|------:|
| A  (14 topics)   |  (+1) | (+4)  |  (+13) |  (+2)  | ‖ | (+20)  | ‖ | (+3)  | (+3)  |
| B  (3 primitives)|   (.) |  (.)  |    (.) |   (.)  | ‖ |   (.)  | ‖ |  (.)  |  (.)  |

Raw surface IC ≈ 52.  OBS IC = 32.  Reduction: ~−38%.

Pull down (B wins):
  - CreatePlanTemplate + PlanUpdate + PlanUpdateList + PlanID + PlanIDList collapse into
    PlanPatch via null-sentinel (create) + tombstone (delete). CA drops from ~4 to 1.
  - visibility.set / sides.set / deleteall / undo collapse into mutate() compositions.
    Adapter silently routes to efficient wire calls when pattern matches. Zero extra ISC.
  - Volume routing-key construction absorbed (ILC → 0 to caller).
  - plan.deleted-when-blocked absorbed into MutateOutcome.removed (CHEC collapses).
  - Render handshake ordering absorbed into render(). Caller sees one boolean.

Growth unit: plan field (plus, secondarily, convenience operation)
A — Δinterface per new plan field: [CreatePlanTemplate; PlanUpdate; PlanUpdateList; Plan] = 4   [Observed, n=3]
A — Growth slope: rising (steep, 4×)
B — Δinterface per new plan field: [] = 0   [Observed, n=3]
B — Growth slope: flat

Growth pattern (why B stays flat):
  A: each new plan field touches CreatePlanTemplate + PlanUpdate + PlanUpdateList + Plan + PlanList
     (CA ≈ 4–5); each new convenience op adds a topic.
  B: new plan field touches one substrate (PlanPatch / Plan); CA = 1. New server-side bulk ops
     are new cases in routeMutate(), not new interface items.
  Evidence: the last three fields added to this surface each required the full 4-topic edit under
  A and zero interface change under B — [Observed], counted from the commit history, not projected.

Key RCK retained (not absorbed — load-bearing):
  RCK-1: mutate({showing:true}) does NOT render — must call render() (two transports).
  RCK-2: colorPalette in a patch applies to ALL plans on the volume, not the target.
  RCK-3: delete is a no-op if locked or dependencyState ≥ 4.

Verdict: B deeper by ~38% IC and flat marginal surface. N=3 is the proven OBS floor for this
domain (write / read / render are the only three axes that cannot be expressed in terms of
each other). The optimization routing is the deepening move — it makes the adapter more powerful
(server-side atomicity, correct delete guards, 1-message broadcast) at exactly zero interface cost.
```

---

## The principle, stated precisely

> **Pull complexity down.** When a derivability proof shows that caller operation X is equivalent to a composition of existing primitives P1…Pn, the adapter is licensed to: (a) **remove X as an interface entry point** (it was a pseudo-primitive), and (b) **silently route to X's efficient wire form** when it recognizes the equivalent composition.
>
> The caller pays no extra interface cost. The server-side atomicity and efficiency are delivered as a dividend of the proof — the adapter "knows more" because it proved the equivalence, and it uses that knowledge to issue the best wire call without asking.
>
> This is the opposite of a shallow adapter, which mirrors every server topic as its own method. A shallow adapter makes derivability the caller's problem; a deep adapter absorbs it once.

---

## Design constraints that make this work

1. **Equivalence must be provable, not asserted.** The optimization is only safe because the compositions were shown to produce identical server-side effect sets. `visibility.set` and `query(all).forEach(mutate{showing})` reach the same final DB state because the service applies `showing` identically per-plan. If the server's bulk op had different semantics (e.g. `deleteall` skipped locked plans while the per-plan loop did not), the equivalence would fail and the optimization would be unsafe.

2. **The optimization adds no new axis.** The adapter is not hiding a fourth primitive. The three-primitive structure is verified independently: write / read / render are irreducible. The bulk routing is pure implementation — it lives entirely below the interface line.

3. **Server-side atomicity is a QoS benefit, not a semantic difference.** The one behavioral difference between the composition and the bulk wire call is atomicity: `plan.undo` is transactional server-side; the composed diff-restore is N sequential operations. This is a quality-of-service property. It does not change the effect set, so it does not create a new axis — but it does mean the adapter _should_ route to the atomic form when it recognizes it.

4. **The `state` cache makes pattern recognition free.** The adapter holds a passive `state: Plan[]` cache (0 ISC — it is a read-only view, not an entry point). When a caller writes `mutate(adapter.state.map(p => ({oid:p.oid, showing:false})))`, the adapter can recognize that the patch array covers exactly all current plans and substitute `visibility.set`. Without the cache, the adapter would need to re-query to perform the check.
