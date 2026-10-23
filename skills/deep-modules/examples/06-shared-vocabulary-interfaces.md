# Worked example 6 — shared-vocabulary interfaces (catalog)

> **Summary**: A catalog of well-known interface vocabularies — orthogonal to the `SQL / regex / JSON / paths` set named inline in the **shared-vocabulary reducer** of `SKILL.md` — that a module can borrow to drive **RCK toward zero**. Each entry names the borrowed subset, the orthogonal capability axis it covers, the RCK win, a realistic module that should borrow it, and a concrete bespoke-vs-borrowed snippet. Ends with a full scorecard for the motivating case: a subset of the `git` CLI used as a language for managing file-like content over time.
>
> **Role**: This is a *reference appendix*, not a tight A-vs-B worked example in the mold of Examples 1–3. The bulk is a catalog; one full scorecard at the end earns the worked-example treatment for the motivating case.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

## Why this catalog exists

The `RCK` reducer **shared vocabulary** says: *an interface expressed in a language the caller already commands adds capability at ~0 RCK.* `SKILL.md` names four such languages **inline in that reducer** — `SQL`, `regex`, `JSON`, `paths`. That list is illustrative, not exhaustive. This file extends it with vocabularies that cover **different capability axes**, so a designer reaching for "what known interface can I borrow here?" has realistic, orthogonal options to choose from.

**The orthogonality test.** Two vocabularies are orthogonal when they answer different questions:

| Vocabulary (axis) | The question it answers | In the inline reducer four? |
|---|---|---|
| `SQL` | "which rows of a *table*, aggregated how?" | yes |
| `regex` | "does this *flat text* match this pattern?" | yes |
| `JSON` | "how is this *structured value* serialized?" | yes |
| `paths` | "how do I *name/address* a node in a hierarchy?" | yes |
| **git (subset)** | "what did this content look like *over time*, and along which *branch*?" | no — and not in the gate baseline either (**genuinely new**) |
| **HTTP verbs + status + conditional headers** | "how do I *transfer resource state* idempotently, with concurrency/caching semantics?" | no — but `HTTP` is **already named in the gate baseline** |
| **Unix pipes / filters** | "how do I *compose streaming transforms* end to end?" | no — but `shell` is **already named in the gate baseline** |
| **cron expressions** | "*when*, recurring, does this happen?" | no — **genuinely new** |
| **Make / dependency targets** | "what must be rebuilt, *given what changed*?" | no — **genuinely new** |
| **CSS selectors / XPath** | "which nodes of a *tree/document* do I select?" | no — **genuinely new** |
| **semver + ranges** | "which *versions* are compatible with this constraint?" | no — **genuinely new** |

> **Note on "already in `SKILL.md`."** The gate's baseline for agent consumers already lists *"SQL, regex, JSON, HTTP, file paths, shell, common formats and idioms."* So `HTTP` (entry 2) and shell-`pipes` (entry 3) are **not new to the skill** — they are already declared free. That *strengthens* the case for borrowing them: they cost ~0 RCK without any argument, because the gate already counts them as baseline. What is new in this catalog is only their addition to the shared-vocabulary reducer's *illustrative* list; `git`, `cron`, `Make`, `CSS/XPath`, and `semver` are the entries new to the skill entirely.

The rule for inclusion: the caller (human or frontier-model agent) **already commands** the vocabulary, so borrowing it is baseline — free, never counted as RCK — and the module gains capability the designer never has to teach.

**The baseline caveat (from the gate).** Only *broadly-known* standards count as baseline. Borrow the **subset** the caller actually holds, not the whole tool. Each entry below flags the part that, if exposed, re-raises RCK instead of lowering it.

---

## Primary catalog

### 1. git (subset) — versioned content over time

- **Borrowed subset**: `commit`, `log`, `diff`, `checkout`, `branch`, `merge`, `revert`, `tag`. The mental model: an append-only graph of immutable snapshots, with movable named refs (`branch`, `tag`) and a current pointer (`HEAD`).
- **Capability axis**: state *over time* + alternate histories + audit trail. Orthogonal to `paths` (which addresses one node *now*, not its history).
- **RCK win**: A bespoke versioning API forces the caller to learn *this library's* version-id scheme, what "restore" does to the current pointer, how a variant differs from a tag, and how conflicts are represented. Borrowing the git model means the caller carries **none** of that — they already know that `commit` snapshots, `checkout` moves `HEAD`, `branch` forks history, and `merge` can conflict.
- **Realistic application**: a document/config "history" feature; an agent memory store with branchable timelines; an undo-with-alternatives system. Expose `commit / log / diff / checkout / branch / merge`, **not** a hand-rolled `saveVersion / listVersions / restoreVersion / createVariant`.
- **Illustrative snippet**:
  ```js
  // A (bespoke): caller learns a private version-id scheme AND tracks "which is current"
  const id = store.saveVersion(content);   // -> opaque "v_8f3a"; what format? who knows
  store.createVariant("draft");            // how does a variant differ from a tag?
  store.restoreVersion(id);                // what does this do to "current"? must read docs

  // B (git subset): caller reuses the model already in their head
  store.commit(content);                   // snapshot; HEAD advances
  store.branch("draft");                   // fork history — same idea as a tag's ref family
  store.checkout(id);                      // HEAD now points at id — no new concept to learn
  ```
- **RCK trap to avoid**: do **not** borrow the *staging area* (`add`/index two-phase commit), `rebase`, `reflog`, `cherry-pick`, or submodules. Those are the parts of git callers most often get wrong — exposing them relocates complexity into the caller's head. Full scorecard below.

### 2. HTTP verbs + status codes + conditional headers — resource state transfer

- **Borrowed subset**: `GET / PUT / POST / DELETE / PATCH`; idempotency semantics (PUT/DELETE are idempotent, POST is not); status families (`2xx / 4xx / 5xx`, plus `404`, `409 Conflict`, `412 Precondition Failed`); `ETag` + `If-Match` for optimistic concurrency.
- **Capability axis**: networked resource lifecycle + concurrency + caching. Orthogonal to `SQL` (HTTP transfers *one resource's state*; SQL queries *sets*).
- **RCK win**: a custom `updateThing(id, data, expectedRevision)` API makes the caller learn a private revision/conflict protocol. `PUT` + `If-Match: <etag>` → `412` is the *same* optimistic-concurrency contract every web developer already holds. "Retry on 409, give up on 4xx, back off on 5xx" is borrowed reflex, not taught knowledge. (And per the gate, `HTTP` is already baseline — so this RCK is free without further argument.)
- **Realistic application**: any service/SDK boundary, a plugin host's resource API, a sync engine. Map operations onto the verbs and lean on the status taxonomy instead of inventing a parallel error enum.
- **Illustrative snippet**:
  ```http
  # A (bespoke optimistic concurrency): a private revision + conflict protocol to learn
  api.updateThing(id, data, expectedRevision=7)   # what's a "revision"? how is a clash signalled?

  # B (borrowed): the contract every caller already holds
  PUT /things/42      If-Match: "a1b2c3"     -> 200 OK            (applied)
  PUT /things/42      If-Match: "a1b2c3"     -> 412 Precondition Failed   (someone else won)
  # no parallel error enum: 2xx/4xx/5xx families ARE the taxonomy
  ```
- **RCK trap to avoid**: don't borrow the *long tail* of status codes (`418`, `226`, `451`) or exotic headers — the baseline is the common verbs + the `2xx/4xx/5xx` families + conditional requests. The tail is RCK, not baseline.

### 3. Unix pipes / filters — streaming transform composition

- **Borrowed subset**: `stdin → stdout` streams, composition with `|`, exit codes (`0` = success), and the filter convention (read a stream, emit a stream, do one thing). The known filter verbs themselves — `grep`, `sort`, `uniq`, `cut`, `wc` — are a bonus vocabulary.
- **Capability axis**: linear composition of transforms. Orthogonal to `JSON` (which is the *shape* flowing through; pipes are the *composition*).
- **RCK win**: a framework with a bespoke `Stage`/`Processor`/`Pipeline.addStep(cfg)` builder makes the caller learn a private wiring model. Stream-in/stream-out + `|` means the caller already knows how to compose, split, and tee — the model is muscle memory. (`shell` is already baseline per the gate.)
- **Realistic application**: a data-transformation library, an agent tool-chaining surface, an ETL step API, a log-processing DSL. Let stages be filters the caller pipes together rather than objects they register and order.
- **Illustrative snippet**:
  ```bash
  // A (bespoke pipeline builder): a private wiring/ordering model to learn
  new Pipeline()
    .addStage(parse,  { cfg })
    .addStage(filter, { level: "ERROR" })
    .addStage(count)
    .run();                       // ordering, shared context, lifecycle — all module-specific

  # B (borrowed): compose / split / tee are already reflex
  cat app.log | grep ERROR | cut -f3 | sort | uniq -c
  ```
- **RCK trap to avoid**: don't reintroduce hidden ordering or shared mutable context between stages — that breaks the "each filter is independent" contract the caller is relying on, re-raising RCK as required-ordering knowledge.

### 4. cron expressions — recurring schedules

- **Borrowed subset**: the five-field `m h dom mon dow` expression, plus `*`, ranges (`1-5`), steps (`*/15`), and lists (`1,15`).
- **Capability axis**: recurring temporal scheduling. Orthogonal to everything in the inline list — none of `SQL / regex / JSON / paths` expresses *when, repeatedly*.
- **RCK win**: a custom `Schedule { everyN, unit, onDays[], startAt }` config is a private mini-language the caller must learn and the designer must document. `"*/15 9-17 * * 1-5"` is a single string a huge fraction of developers (and frontier models) read fluently — capability at ~0 RCK and ~1 ISC (one string field).
- **Realistic application**: any "run this periodically" surface — a job runner, a polling config, a reminder/notification feature.
- **Illustrative snippet**:
  ```js
  // A (bespoke schedule object): a private config mini-language (≥4 ISC, must be documented)
  schedule({ everyN: 15, unit: "minutes", onDays: [1,2,3,4,5], fromHour: 9, toHour: 17 });

  // B (borrowed): one string the caller already reads (~1 ISC, ~0 RCK)
  schedule("*/15 9-17 * * 1-5");   // every 15 min, 9am–5pm, Mon–Fri
  ```
- **RCK trap to avoid**: cron can't express "every 90 minutes" or one-shot future times cleanly. When the need is *durations* or *instants*, borrow **ISO-8601** (durations `PT90M`, timestamps) instead — don't bend cron past its baseline.

### 5. Make / dependency targets — incremental, dependency-driven orchestration

- **Borrowed subset**: `target: prerequisites` + a recipe, with "rebuild a target only if a prerequisite is newer." The DAG-with-staleness model.
- **Capability axis**: dependency-graph-driven incremental work. Orthogonal to pipes (linear) — Make expresses a *graph* with up-to-date checks.
- **RCK win**: a bespoke task engine with `task.dependsOn(...)`, manual invalidation, and a private "did this need to run?" rule forces the caller to learn that engine. The Make model — declare what depends on what, the tool figures out the minimal rebuild — is already understood; the caller declares edges and stops thinking about scheduling.
- **Realistic application**: a build/codegen pipeline, an asset processor, a memoized computation graph, an agent task planner with prerequisites.
- **Illustrative snippet**:
  ```make
  // A (bespoke task engine): caller declares edges AND owns invalidation + run-decisions
  g.task("bundle", { deps: ["a.js", "b.js"], run: build });
  g.invalidate("a.js");        // manual; what's the staleness rule? module-specific
  g.runIfNeeded("bundle");     // a private "did this need to run?" predicate to learn

  # B (borrowed model): declare what depends on what; the tool computes the minimal rebuild
  bundle.js: a.js b.js
  	cat a.js b.js > bundle.js   # only rebuilds when a prerequisite is newer
  ```
- **RCK trap to avoid**: Make's *syntax* (tab-significant recipes, implicit rules, pattern rules `%.o: %.c`) is the RCK-heavy part. Borrow the **model** (targets, prereqs, staleness), not the literal Makefile grammar.

### 6. CSS selectors / XPath — declarative selection over a tree

- **Borrowed subset (CSS)**: `tag`, `.class`, `#id`, descendant (space), child (`>`), attribute (`[attr=value]`). Or **XPath**: `//node`, `/child`, `[predicate]`.
- **Capability axis**: selecting nodes from a *tree/document*. Orthogonal to `SQL` (tabular sets) and `regex` (flat text) — selection over hierarchy is a distinct axis.
- **RCK win**: a bespoke tree-walk API (`findChildrenWhere`, `firstDescendantByType`, `matchAttribute`) is a menu of special-purpose finders the caller must learn one by one. One selector string the caller already writes for the DOM collapses that menu to a single entry point over a discoverable node vocabulary.
- **Realistic application**: querying any tree — an AST, a scene graph, a config tree, a rendered-document model, an org chart.
- **Illustrative snippet**:
  ```js
  // A (menu of finders): every new query shape is a new method to learn (rising ISC)
  tree.findChildrenWhere(n => n.type === "item");
  tree.firstDescendantByType("section");
  tree.matchAttribute("active", true);

  // B (one borrowed selector): one entry point over a discoverable node vocabulary
  tree.select("section > .item[active]");
  ```
- **RCK trap to avoid**: XPath's full axis set (`ancestor::`, `following-sibling::`, functions) is power most callers don't hold as baseline — the *common* CSS subset is the cheap one; the exotic axes are RCK.

### 7. semver + ranges — version-compatibility constraints

- **Borrowed subset**: `MAJOR.MINOR.PATCH`, the breaking/feature/fix contract, pre-release tags, and ranges `^1.2.3`, `~1.2.3`, `>=1.2 <2`.
- **Capability axis**: expressing *which versions satisfy a constraint*. Orthogonal — none of the inline four expresses compatibility intent.
- **RCK win**: a custom `minVersion / maxVersion / allowBreaking` config encodes a private compatibility policy. `"^1.4.0"` carries the entire "compatible-up-to-next-major" policy in three characters the ecosystem already reads.
- **Realistic application**: a plugin/extension compatibility gate, a feature-flag rollout keyed to version, a migration guard.
- **Illustrative snippet**:
  ```js
  // A (bespoke policy object): a private compatibility policy to learn and document
  requires({ minVersion: "1.4.0", maxVersion: "2.0.0", allowBreaking: false });

  // B (borrowed): the same policy in a string the ecosystem already reads
  requires("^1.4.0");   // >=1.4.0 and <2.0.0 — compatible up to the next major
  ```
- **RCK trap to avoid**: build-metadata and pre-release ordering edge cases are the niche part. The common `MAJOR.MINOR.PATCH` + `^`/`~`/comparator ranges are baseline; the corner cases are RCK.

---

## Further candidates (orthogonal, brief)

These cover additional axes and are worth borrowing when they fit; each is named with its axis, a one-line example, and its RCK trap.

| Vocabulary | Capability axis | Borrow this (example) | RCK trap (don't borrow) |
|---|---|---|---|
| **unified diff / patch** | representing & transporting a *change between two states* | `apply(patch)` over hunks, `+`/`-` lines | 3-way/merge-conflict markers as a public format |
| **ISO-8601 (instants & durations)** | points in time and durations | `"2026-06-14T12:00:00Z"`, `"PT15M"`, `"P1D"` | full interval/recurrence grammar (`R/PnY...`) |
| **spreadsheet formula + A1 refs** | reactive cellular dataflow | `"=SUM(A1:A10)"`, relative vs `$A$1` absolute | the long tail of 400+ functions |
| **glob patterns** | wildcard *naming* over paths | `"**/*.js"`, `?`, `[a-z]`, `{a,b}` | regex-grade backtracking semantics (use `regex` instead) |
| **Markdown** | lightweight document markup | headings, lists, links, code fences, tables | full CommonMark/GFM extension surface |
| **printf format strings** | value-to-text formatting | `"%d"`, `"%s"`, `"%.2f"`, width/precision | locale and positional-argument exotica |
| **set algebra** | combining collections | `union / intersection / difference / member?` | (rarely a trap — but confirm the caller thinks in sets, not rows) |

Note the deliberately *adjacent-but-excluded* cases: `glob` borders `paths`+`regex`, and `set algebra` borders `SQL`. Listed here with their boundaries called out so a designer doesn't reach for them when a sharper inline vocabulary already fits.

---

## Worked scorecard — the motivating case (git subset for file-like content over time)

**Capability**: let a caller manage file-like content over time — snapshot it, see its history, view what changed, return to an earlier state, fork alternative versions, and reconcile them.

- **A (bespoke versioning API)**: `saveVersion(content) -> versionId`, `listVersions()`, `getVersion(id)`, `restoreVersion(id)`, `createVariant(name)`, `mergeVariant(a, b)`, `diffVersions(a, b)`, `tagVersion(id, label)` — plus a private `versionId` scheme, a caller-tracked "which version is current" pointer, and bespoke conflict/not-found/stale-pointer errors.
- **B (git-subset interface)**: `commit`, `log`, `diff`, `checkout`, `branch`, `merge`, `revert`, `tag` — the caller reuses the git model they already hold (immutable commits, movable refs, a `HEAD` pointer, conflicts on `merge`).

```
## Deep Module Comparison: manage file-like content over time

Caller & baseline: application code / frontier-model agent; baseline includes the common git porcelain model
Capability held constant: snapshot, history, diff, restore, fork, reconcile file-like content over time
Growth unit: none — the eight verbs are a closed set fixed by the borrowed model, not a family that
  grows with requirements (see the Growth note under Per-guideline judgment)
Equivalence: Yes      Confidence: High — caller and baseline explicit; both designs are concrete

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option         | CHEC | ILC  | ISC  | RCK  | ‖ | TOTAL | Attention                                          |
|----------------|-----:|-----:|-----:|-----:|:-:|------:|:---------------------------------------------------|
| A (bespoke)    | (+2) | (+1) | (+2) | (+4) | ‖ |  (+9) | ! dominant: RCK(+4) + CHEC(+2); bespoke model     |
| B (git subset) |  (.) |  (.) |  (.) |  (.) | ‖ |   (.) | --                                                 |
```

**Proxy reasoning (auditable items behind each count)**:

- **CHEC** — A: bespoke `MergeConflict`, `VersionNotFound`, `StalePointer` (3). B: the familiar `merge` conflict (1); "not found" is defined away (`checkout` of a missing ref is a normal "unknown ref" the caller already expects), and there is no caller-tracked pointer to go stale because `HEAD` is internal state.
- **ILC** — A: the private `versionId` format leaks the storage scheme into signatures (1). B: commit SHAs are a *deliberate, stable, discoverable* contract — ISC, not a leak (0).
- **ISC** — A: 8 entry points + the `versionId` concept + the caller-tracked current-pointer concept = **10**. B: **8 entry points** (`commit / log / diff / checkout / branch / merge / revert / tag`). *Counting note:* the conceptual unification — branch, tag, and `HEAD` are one ref-and-commit family — does **not** discount ISC, because the eight verbs are still eight distinct entry points. That unification is real, but under the counting convention it shows up as the **RCK collapse below**, not as a smaller ISC. Counting it twice (once in ISC, once in RCK) would double-discount the same win. So ISC is 10 vs 8 — a modest narrowing — and the decisive gap lives in RCK and CHEC.
- **RCK** — A: the caller must learn this library's id scheme, what `restoreVersion` does to "current", how a variant differs from a tag, the conflict representation, and the ordering rules (5). B: ~1 — "it's a git-like model," which for the declared baseline is essentially free. *This is where the branch/tag/HEAD unification pays off:* one ref-and-commit family means there is nothing module-specific to carry.

**Per-guideline judgment**:

- **Pull complexity down**: B — snapshot/merge/diff mechanics are absorbed behind verbs the caller already commands; nothing re-surfaces, so it is encapsulated, not relocated.
- **General-purpose interface**: B — `branch`/`tag`/`HEAD` are one ref family, not three special-purpose "variant"/"label"/"current" methods.
- **Errors defined out**: B — CHEC 3→1; the stale-pointer error disappears because `HEAD` is internal, not caller-managed (a fault is not masked — there is simply no caller-held pointer to corrupt).
- **Complementary code together**: B — one commit-graph model unifies history, diff, and merge; A scatters the shared snapshot decision across eight bespoke methods (change amplification when the version model evolves).
- **Growth**: `Growth unit: none`, declared explicitly rather than left blank. This is a like-for-like A-vs-B over a closed verb set, not a menu-vs-substrate trajectory case — the version-control model the caller already commands *defines* the eight verbs, so neither design accretes entry points as requirements arrive. This is the legitimate no-trajectory outcome: state it, and do not manufacture a unit to fill the row. (Note the borrowed model is doing double duty — it collapses RCK today *and* caps growth tomorrow, which is why shared vocabulary is such a strong move.)

**Depth verdict**: **B (git subset) is deeper** (10 vs 19). Dominant driver: **RCK 5→1 and CHEC 3→1** — the borrowed model is the whole win. ISC narrows only 10→8; the carried-knowledge collapse, not the entry-point count, is what makes B cheap for every caller, forever.

**Where A is actually better**: if the content model is *not* snapshot-like (e.g., a single mutable record with no meaningful "history" or "branches"), git's model is over-built — borrowing it would be borrowed RCK for capability nobody asked for. Re-run the gate before borrowing.

### Substrate-guardrail check on the borrowed subset

| Guardrail | Holds? | Evidence |
|---|---|---|
| Caller commands the vocabulary | ✅ | git porcelain is baseline for the declared callers. |
| Common needs stay one-liners | ✅ | `commit` / `checkout <ref>` is no harder than `saveVersion` / `restoreVersion`. |
| Exposed model is a deliberate, stable, discoverable contract | ✅ | Commit SHAs + refs are documented public identifiers, not storage internals. |
| No unbounded failure modes pushed to the caller | ⚠️ | Holds **only if** the staging area / `rebase` / `reflog` stay unexposed; exposing them re-raises CHEC + RCK. |

The fourth guardrail is conditional — which is exactly the "borrow the subset, not the whole tool" rule in action.

---

**Lesson**: The inline `SQL / regex / JSON / paths` reducer list is a starting set, not the boundary. Whenever a module's job lines up with an axis a well-known interface already owns — *time* (git), *resource transfer* (HTTP), *composition* (pipes), *scheduling* (cron), *dependency* (Make), *tree selection* (CSS/XPath), *version constraints* (semver) — borrowing that interface's **subset the caller already holds** converts what would have been taught RCK into free baseline. The depth win shows up primarily as collapsed RCK and CHEC — not as a much smaller ISC, since the entry-point count usually changes only modestly. The discipline is always the same: borrow the part of the vocabulary the caller commands, and leave the RCK-heavy tail behind.
