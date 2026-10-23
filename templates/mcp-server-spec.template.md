# MCP Server Specification: {{SERVER_NAME}}

> Template purpose: convert an approved Orthogonal Basis Set (OBS) into an implementation-ready MCP server contract. This document starts after the OBS has been selected and refined. It does not repeat the OBS discovery method, tournament, or scorecard.

## Template conventions

- Replace every `{{PLACEHOLDER}}`.
- Delete instructional blockquotes after completing the specification.
- Use `MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` as normative terms.
- Give every unresolved item an `OPEN-*` identifier, owner, safe default, and closure evidence.
- Give every decision a `DEC-*` identifier and every guarantee a `G-*` identifier.
- A guarantee is one falsifiable clause. Rationale belongs in the decision ledger; verification belongs in the guarantee and test matrices.
- Cite the exact MCP protocol revision and extension versions used. Do not write “latest” as a version.

---

## 1. Document control

| Field | Value |
| --- | --- |
| Status | `Draft / Review / Approved / Superseded` |
| Server | `{{SERVER_NAME}}` |
| Specification owner | `{{OWNER}}` |
| Reviewers | `{{REVIEWERS}}` |
| Last updated | `{{YYYY-MM-DD}}` |
| Target MCP revision | `{{PROTOCOL_REVISION}}` |
| Supported compatibility revisions | `{{REVISIONS_OR_NONE}}` |
| Deployment pattern | `local_stdio / remote_streamable_http / mixed` |
| Security classification | `{{DATA_AND_ACTION_CLASSIFICATION}}` |
| Source OBS | `{{PATH_OR_URL_TO_APPROVED_OBS}}` |
| OBS approval evidence | `{{APPROVAL_REFERENCE}}` |
| Supersedes | `{{SPEC_ID_OR_NONE}}` |

### 1.1 Source authority

Order conflicting inputs from highest to lowest authority:

1. `{{USER_OR_PRODUCT_BOUNDARY_DECISIONS}}`
2. `{{APPROVED_OBS}}`
3. This specification's ratified decision ledger
4. Current official MCP specification and adopted extensions
5. Implementation details

Implementation details MUST NOT silently redefine a higher-authority contract.

### 1.2 Inputs and evidence

| Input | Location | Version/date | What this specification relies on |
| --- | --- | --- | --- |
| Approved OBS | `{{...}}` | `{{...}}` | Nouns, primitives, adjectives, derivations, boundary |
| Domain/runtime documentation | `{{...}}` | `{{...}}` | Existing seams and execution constraints |
| MCP specification | `{{...}}` | `{{...}}` | Protocol behavior |
| MCP extension specification(s) | `{{...}}` | `{{...}}` | Optional negotiated behavior |
| Security requirements | `{{...}}` | `{{...}}` | Trust-boundary controls |
| Compatibility/client evidence | `{{...}}` | `{{...}}` | Host feature support |

---

## 2. Specification contract

### 2.1 Value statement

As `{{CALLER_CLASS}}`, I want `{{CAPABILITY_EXPOSED_BY_THE_OBS}}` through MCP so that `{{USER_OR_SYSTEM_VALUE}}` without requiring knowledge of `{{HIDDEN_IMPLEMENTATION_FACTS}}`.

### 2.2 One-sentence server contract

`{{ONE_SHORT_SENTENCE_DESCRIBING_THE_COMPLETE_PUBLIC_CONTRACT}}`

### 2.3 Boundary

The MCP server is `{{SUBSTRATE_DESCRIPTION}}`, not `{{APPLICATION_HOST_DESCRIPTION}}`.

The server owns:

- `{{PROTOCOL_ADAPTATION_RESPONSIBILITIES}}`
- `{{RESOURCE_AND_OPERATION_CONTRACTS}}`
- `{{EXECUTION_OR_ROUTING_RESPONSIBILITIES}}`
- `{{VALIDATION_SECURITY_AND_OBSERVABILITY_RESPONSIBILITIES}}`

The server does not own:

- `{{APPLICATION_WORKFLOWS}}`
- `{{USER_EXPERIENCE_OR_RENDERING}}`
- `{{DOMAIN_SPECIFIC_SESSION_OR_GAME_STATE}}`
- `{{MODEL_REASONING_OR_AESTHETIC_JUDGMENT}}`

### 2.4 Non-goals

| ID     | Non-goal  | Correct owner | Why exclusion is load-bearing |
| ------ | --------- | ------------- | ----------------------------- |
| NG-001 | `{{...}}` | `{{...}}`     | `{{...}}`                     |

### 2.5 Boundary acceptance tests

- A new application workflow expressible by composition MUST NOT require a new use-case-named MCP operation.
- An implementation restart MUST NOT require the caller to know internal runtime IDs.
- Application state MUST NOT appear in MCP state merely because one current consumer needs it.
- High-rate domain data MUST follow the declared data-plane policy rather than being smuggled through control-plane tool results.

---

## 3. Approved OBS handoff

> Copy the approved result, not the upstream analysis. If this section cannot be filled from an approved OBS, stop: the precondition for this template has not been met.

### 3.1 Locked interface definition

| Kind | Approved definition | Stable name | Notes |
| --- | --- | --- | --- |
| Public noun(s) | `{{...}}` | `{{...}}` | `{{...}}` |
| Primitive operation(s) | `{{...}}` | `{{...}}` | `{{...}}` |
| Public adjectives/qualifiers | `{{...}}` | `{{...}}` | `{{...}}` |
| Derived operations | `{{...}}` | n/a | Composition only; not new MCP tools |
| Explicitly excluded concepts | `{{...}}` | n/a | Remain outside the server |

### 3.2 Primitive-to-MCP mapping

> Do not assume every OBS primitive becomes a custom tool. Prefer standard MCP facilities when they already carry the primitive: resources for observable state, tools for model-controlled effects, protocol discovery for capabilities, and an extension only when negotiated behavior is actually required.

| OBS primitive | MCP facility | Public name/URI shape | Why this is the faithful mapping | What is deliberately not added |
| --- | --- | --- | --- | --- |
| `{{PRIMITIVE}}` | `tool / resource / resource template / protocol operation / extension` | `{{...}}` | `{{...}}` | `{{...}}` |

### 3.3 Derived-operation proof table

| Domain operation | Derivation from public MCP surface | Observable result | No new primitive because... |
| --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

Coverage MUST be 100% for the approved in-scope operations. Historical OBS scores are out of scope unless they are required to resolve a new implementation decision.

---

## 4. MCP protocol profile

### 4.1 Version and capability profile

| Item | Contract |
| --- | --- |
| Target protocol revision | `{{EXACT_DATE_VERSION}}` |
| Version discovery/negotiation | `{{SERVER_DISCOVER_AND_FALLBACK_BEHAVIOR}}` |
| Tools capability | `{{SUPPORTED_OPTIONS}}` |
| Resources capability | `{{SUPPORTED_OPTIONS}}` |
| Prompts capability | `unsupported / supported: {{WHY}}` |
| Extensions | `{{EXACT_EXTENSION_IDS_AND_VERSIONS_OR_NONE}}` |
| Deprecated features | `{{REJECTED_OR_COMPATIBILITY_ONLY}}` |
| Unknown optional capabilities | `{{IGNORE_OR_ERROR_POLICY}}` |

The server MUST advertise only behavior it implements and MUST make capability results deterministic for the same authorization and underlying registry state.

### 4.2 Transport profile

| Concern | Local STDIO | Streamable HTTP | Selected behavior |
| --- | --- | --- | --- |
| Process ownership | `{{...}}` | `{{...}}` | `{{...}}` |
| Authentication | `{{...}}` | `{{...}}` | `{{...}}` |
| Request metadata/version | `{{...}}` | `{{...}}` | `{{...}}` |
| Cancellation | `{{...}}` | `{{...}}` | `{{...}}` |
| Reconnect/retry | `{{...}}` | `{{...}}` | `{{...}}` |
| Notification subscription | `{{...}}` | `{{...}}` | `{{...}}` |
| Shutdown | `{{...}}` | `{{...}}` | `{{...}}` |

### 4.3 Stateless request semantics

For MCP revision `2026-07-28`, protocol-level sessions and `Mcp-Session-Id` are not part of the wire contract. Each request MUST be independently authorizable and routable. Cross-request domain state MAY exist, but it MUST be addressed through an explicit, documented public identifier or resource URI rather than hidden connection memory.

Specify:

- Per-request identity and authorization inputs: `{{...}}`
- Explicit cross-request identifiers: `{{...}}`
- Persistence/retention of each identifier: `{{...}}`
- Behavior after server restart or routing to another instance: `{{...}}`
- Behavior for unknown, expired, stale, or unauthorized identifiers: `{{...}}`
- Legacy-session compatibility, if any: `{{...}}`

> Official basis: MCP 2026-07-28 removed the initialization/session handshake and recommends explicit state handles when an application needs cross-call state. See [The 2026-07-28 Specification](https://blog.modelcontextprotocol.io/posts/2026-07-28/) and [MCP Tools: Stateful Tools](https://modelcontextprotocol.io/specification/draft/server/tools#stateful-tools).

### 4.4 Capability discovery and caching

- `server/discover`: `{{IMPLEMENTATION_AND_CACHE_POLICY}}`
- `tools/list`: `{{ORDERING_PAGINATION_TTL_CACHE_SCOPE}}`
- `resources/list`: `{{PAGINATION_TTL_CACHE_SCOPE}}`
- `resources/read`: `{{TTL_CACHE_SCOPE}}`
- List-change publication: `{{WHEN_AND_HOW}}`
- Authorization-sensitive results: `{{CACHE_PARTITIONING_POLICY}}`

For the same authorization and unchanged registry, tool/resource lists MUST NOT vary by connection or as an incidental side effect of a preceding request.

---

## 5. Public interface contract

### 5.1 Tool catalog

> Repeat this subsection for each custom tool. If the approved mapping needs no custom tools, state that explicitly.

#### Tool: `{{TOOL_NAME}}`

Purpose: `{{ONE_SENTENCE_WITHOUT_USE_CASE_OR_IMPLEMENTATION_VOCABULARY}}`

| Property                     | Contract                     |
| ---------------------------- | ---------------------------- |
| Corresponding OBS primitive  | `{{...}}`                    |
| Side effects                 | `{{...}}`                    |
| Idempotency                  | `{{IDEMPOTENT_OR_KEY_RULE}}` |
| Destructive potential        | `{{...}}`                    |
| Authorization scope          | `{{...}}`                    |
| Human approval policy        | `{{...}}`                    |
| Synchronous/task eligibility | `{{...}}`                    |
| Timeout/deadline behavior    | `{{...}}`                    |

Input schema:

```json
{{VALID_JSON_SCHEMA_2020_12}}
```

Output schema:

```json
{{VALID_JSON_SCHEMA_2020_12}}
```

Success semantics:

`{{POSTCONDITION_VISIBLE_TO_CALLER}}`

Failure semantics:

| Condition | Protocol error or tool execution error | Stable code/data | Caller recovery |
| --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

Tool results SHOULD include schema-conforming `structuredContent`; compatibility text content SHOULD be included when required by supported clients. Tool annotations are hints, not authorization controls.

### 5.2 Resource model

#### URI grammar

```text
{{URI_SCHEME}}://{{AUTHORITY_OR_NAMESPACE}}/{{PATH_GRAMMAR}}
```

| URI class/template | Meaning | Created by | Stability | Authorization | Retention |
| --- | --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `caller / server / external system` | `{{...}}` | `{{...}}` | `{{...}}` |

#### Resource descriptor

```ts
interface {{RESOURCE_DESCRIPTOR_NAME}} {
  uri: string;
  name: string;
  description?: string;
  mimeType: string;
  {{APPROVED_PUBLIC_ADJECTIVES}}
  schema?: Record<string, unknown>;
  revision?: string;
  provenance?: {{PROVENANCE_TYPE}};
}
```

For every public field, specify:

| Field | Type | Required | Units/range/shape | Mutable by | Stability/versioning |
| --- | --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

#### List/read/subscription behavior

- List visibility: `{{...}}`
- Read consistency: `{{STRONG_EVENTUAL_SNAPSHOT_ETC}}`
- Pagination and ordering: `{{...}}`
- Cache hints: `{{...}}`
- Content types and maximum sizes: `{{...}}`
- Change notification trigger: `{{...}}`
- Subscription support and resubscription behavior: `{{...}}`
- Deleted/tombstoned resource behavior: `{{...}}`

Resources are application-driven context. The server MUST NOT dictate a UI or user interaction model for them.

### 5.3 Prompts

`Unsupported`, unless the OBS or a separately ratified product requirement establishes a server-owned reusable prompt contract. If supported, specify why prompts are server-owned rather than application/agent policy, their arguments, versioning, and injection controls.

### 5.4 Custom extensions

| Extension ID | Status/source | Required by which capability | Client fallback | Security implications |
| --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

Do not create a custom extension when a core facility or adopted extension already carries the behavior.

---

## 6. Operation semantics

### 6.1 Identity and ownership

- Public identities are: `{{CALLER_OR_SERVER_OWNED_URIS_AND_HANDLES}}`.
- Internal runtime identities are: `{{PROCESS_NODE_BUS_BUFFER_JOB_IDS}}`.
- Internal identities MUST NOT be returned as stable public identities.
- Every mutable public object has exactly one authoritative owner: `{{OWNERSHIP_RULE}}`.
- A public identifier is a name, not proof of authorization. Authorization MUST be checked on every request that uses it.

### 6.2 Create, replace, patch, and delete

| Semantic operation | Representation | Preconditions | Atomicity | Idempotency | Observable result |
| --- | --- | --- | --- | --- | --- |
| Create | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Replace/update | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Partial patch, if supported | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Delete/tombstone | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

If absent-delete is defined as success/no-op, say so. If partial patch is not required, omit it instead of inventing a second mutation grammar.

### 6.3 Revision and concurrency

- Revision type and scope: `{{...}}`
- Compare-and-swap/precondition field: `{{...}}`
- Concurrent write rule: `{{...}}`
- Stale write result and recovery: `{{...}}`
- Duplicate/replayed call behavior: `{{...}}`
- Crash between internal effect and public publication: `{{...}}`
- Multi-resource transaction support: `unsupported / {{CONTRACT}}`

### 6.4 Effects and diagnostics

Every mutating operation returns enough information to locate its public consequences without exposing runtime internals.

```ts
interface {{OPERATION_RESULT}} {
  target: string;
  revision: string | null;
  effects: string[];       // public resource URIs only
  diagnostics: Diagnostic[];
}
```

Specify atomic publication, ordering, deduplication, and partial-failure rules: `{{...}}`.

### 6.5 Real-time and bulk data boundary

| Data class | Cadence/volume | MCP control-plane representation | Direct data plane | Backpressure/drop policy |
| --- | --- | --- | --- | --- |
| Scalar state | `{{...}}` | `{{...}}` | n/a | `{{...}}` |
| Events | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| High-rate stream | `{{...}}` | Transport descriptor resource | `{{OSC/WebSocket/shared-memory/etc.}}` | `{{...}}` |
| Large artifact | `{{...}}` | Resource link/metadata | `{{file/HTTP/object store}}` | `{{...}}` |

MCP is the discovery/control/artifact plane unless measurements prove it is appropriate for the required stream. Do not place audio frames, spectra, animation frames, or similar high-rate payloads in repeated tool calls by default.

---

## 7. Long-running work

### 7.1 Classification policy

| Work class | Completion target | Execution mode | Reason |
| --- | --- | --- | --- |
| Fast deterministic mutation/read | `{{...}}` | Immediate result | `{{...}}` |
| Long-running/reconnectable operation | `{{...}}` | MCP Tasks extension | `{{...}}` |
| Continuous runtime | Until explicit stop/replacement | Public resource plus direct runtime/data plane | Not a finite task |

Do not model a continuously running instrument, microphone analyzer, renderer, or external application as an endlessly “working” MCP task. Tasks represent finite deferred results; live runtime state is modeled through public resources and explicit effects.

### 7.2 MCP Tasks extension profile

| Concern | Contract |
| --- | --- |
| Extension ID | `io.modelcontextprotocol/tasks` |
| Eligible tool calls | `{{...}}` |
| Client opt-in/capability check | `{{...}}` |
| Task creation durability | Findable by `tasks/get` before acknowledgement |
| Task ID | Opaque, unguessable, authorization-bound |
| Statuses | `working / input_required / completed / cancelled / failed` |
| Poll interval | `{{DEFAULT_AND_RATE_LIMIT}}` |
| TTL/retention | `{{...}}` |
| Client recovery | Client persists task IDs so polling can resume after restart/reconnect |
| Input during work | `tasks/get` exposes requests; ack-only `tasks/update` supplies responses |
| Cancellation | Cooperative, ack-only; status observed via `tasks/get` |
| Notifications | `{{OPTIONAL_TASK_NOTIFICATIONS_POLICY}}`; polling remains sufficient |
| Result | Same result shape the original tool call would have returned |
| Restart/reconnect | `{{DURABLE_STORE_AND_RECOVERY}}` |
| Client lacks extension | `{{SYNCHRONOUS_FALLBACK_OR_STABLE_ERROR}}` |

The server MUST NOT return a task result to a request that did not declare task-extension support. A returned task MUST already be durably retrievable. Each task-related request MUST repeat authentication and authorization. There is no general `tasks/list` in the current extension.

> Official basis: [SEP-2663: Tasks Extension](https://modelcontextprotocol.io/seps/2663-tasks-extension) defines durable, pollable tasks and the `tasks/get`, `tasks/update`, and `tasks/cancel` lifecycle. It also requires durable creation before acknowledgement and per-request authorization. The extension is not wire-compatible with the experimental tasks surface from MCP `2025-11-25`.

### 7.3 Progress, input, cancellation, and deadlines

- Progress observable to caller: `{{TASK_STATUS_MESSAGE_OR_PUBLIC_RESOURCE}}`
- User input needed before task creation: `{{MRTR_POLICY}}`
- User input needed during task execution: `{{TASK_UPDATE_POLICY}}`
- Deadline propagation: `{{...}}`
- Cancellation race semantics: `{{...}}`
- Worker crash semantics: `{{...}}`
- Orphan detection/recovery: `{{...}}`

---

## 8. State model

### 8.1 State classification

| State item | Public, internal, or application | Authoritative owner | Addressed by | Persistence | Visible to agent | Mutation path |
| --- | --- | --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{URI/HANDLE/INTERNAL_ID}}` | `{{...}}` | `{{...}}` | `{{...}}` |

### 8.2 Public state

Public state is part of the MCP contract and MAY include stable resource URIs, representations, revisions, declared live values, artifacts, diagnostics, direct-stream descriptors, and task handles. List every public state family and its schema owner:

`{{...}}`

### 8.3 Internal state

Internal state is implementation detail and MUST remain substitutable. Examples include process handles, engine node/group IDs, buses, buffers, temporary paths, sockets, caches, device handles, worker placement, and reconnect bookkeeping.

`{{PROJECT_SPECIFIC_INTERNAL_STATE}}`

### 8.4 Application state

Application state is owned by an MCP client or a system above the server. It MUST NOT be added to the server merely for workflow convenience.

`{{PROJECT_SPECIFIC_APPLICATION_STATE}}`

### 8.5 State transition table

| From | Trigger | Preconditions | To | Public event/result | Recovery on failure |
| --- | --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

---

## 9. Guarantees

> One falsifiable clause per row. Keep statement text here; other sections reference the ID. `candidate` guarantees require human ratification before becoming load-bearing.

| ID | Normative statement | Maturity | Scope | Observable oracle/test | Evidence owner |
| --- | --- | --- | --- | --- | --- |
| G-001 | `{{ONE_FALSIFIABLE_CLAUSE}}` | `candidate / plan-local / adopted / formal` | `{{...}}` | `{{...}}` | `{{...}}` |

At minimum, address whether the server guarantees:

- stable public identity independent of runtime identity;
- per-request authorization and isolation;
- input and output schema conformance;
- mutation atomicity and revision behavior;
- idempotency/replay behavior;
- no partial publication after failed evaluation;
- task durability before acknowledgement;
- task/result authorization and retention;
- bounded resource sizes, timeouts, and rate limits;
- explicit units, cadence, and timestamps for live data;
- deterministic discovery/listing under equivalent authorization;
- path confinement and code-execution policy;
- observability sufficient to reconstruct effects without logging sensitive payloads;
- graceful shutdown, cancellation, and recovery behavior.

---

## 10. Deliberate falsification

### 10.1 Falsification rule

For every proposed tool, resource class, handle, state transition, and guarantee, state the smallest counterexample that would prove the design incomplete. The specification is not ready when a failure can only be described as “the implementation should handle it.”

### 10.2 Naive definition versus falsified contract

| Naive interface definition | Counterexample used to falsify it | Deliberate specification response |
| --- | --- | --- |
| Add `create_game_session`, `start_song`, and `score_pitch` tools because the first consumer is a game. | A synthesizer editor needs the same audio/control substrate but none of the game lifecycle; every new application adds more tools. | Keep application nouns outside MCP. Expose only the approved substrate primitive(s) and observable resources; the game composes them. |
| Store “current project” or “current instrument” in hidden connection state. | A retry lands on another server instance or the client reconnects; the next call mutates the wrong or nonexistent object. | Require an explicit stable URI/handle in each request and authorize it independently. |
| Return success as soon as background work is queued. | The process crashes after acknowledgement but before the job is durably recorded; the caller receives an ID that can never be read. | Acknowledge a task only after `tasks/get` can resolve it; test crash-at-each-boundary recovery. |
| Keep a long `tools/call` request open for offline rendering or analysis. | A proxy deadline or client restart loses the result even though the computation continues. | Use the negotiated Tasks extension for finite deferred work, with durable IDs, polling, TTL, cancellation, and fallback. |
| Stream microphone FFT bins or audio blocks through repeated tool calls. | Tool latency, JSON/base64 overhead, and model context pressure cause drops and unbounded cost. | Return a typed direct-stream descriptor as a resource; keep MCP as control/discovery/artifact plane. |
| Return internal engine node/bus IDs so the caller can update sound state. | A server reboot reallocates IDs and the client mutates the wrong runtime object. | Keep engine IDs internal; map stable public resource URIs to current runtime objects. |
| Treat a tool annotation or opaque ID as authorization. | An untrusted client copies an ID or lies about annotations and accesses another caller’s state. | Enforce authorization on every request; annotations are descriptive hints and handles are names, not permissions. |
| Publish a new resource revision before all declared effects are installed. | The caller observes a revision whose audio/control outputs are only partially active. | Define the commit/publication boundary and test failure injection before and after it. |

### 10.3 Required adversarial scenarios

| ID | Scenario | Expected invariant | Test/evidence | Status |
| --- | --- | --- | --- | --- |
| F-001 | Duplicate/replayed mutation | `{{...}}` | `{{...}}` | `open / pass / fail` |
| F-002 | Concurrent stale revisions | `{{...}}` | `{{...}}` | `{{...}}` |
| F-003 | Crash before/after effect publication | `{{...}}` | `{{...}}` | `{{...}}` |
| F-004 | Reconnect to a different instance | `{{...}}` | `{{...}}` | `{{...}}` |
| F-005 | Unknown/expired/unauthorized URI or handle | `{{...}}` | `{{...}}` | `{{...}}` |
| F-006 | Malformed or oversized schema-valid input | `{{...}}` | `{{...}}` | `{{...}}` |
| F-007 | Task worker dies after task acknowledgement | `{{...}}` | `{{...}}` | `{{...}}` |
| F-008 | Task cancellation races with completion | `{{...}}` | `{{...}}` | `{{...}}` |
| F-009 | Client lacks an optional extension | `{{...}}` | `{{...}}` | `{{...}}` |
| F-010 | Direct stream producer/consumer is slower or unavailable | `{{...}}` | `{{...}}` | `{{...}}` |
| F-011 | Runtime engine restarts while public resources remain | `{{...}}` | `{{...}}` | `{{...}}` |
| F-012 | Prompt-injected or malicious executable artifact | `{{...}}` | `{{...}}` | `{{...}}` |

---

## 11. Decision ledger

> Record current implementation-shaping decisions. Do not copy the OBS tournament or scoring history. Reference the approved OBS for upstream interface decisions.

| ID | Status | Decision | Rationale/evidence | Rejected alternative | Consequences | Revisit trigger | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DEC-001 | `proposed / accepted / superseded` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

Minimum decisions to make explicit:

- protocol revision and compatibility window;
- mapping of each OBS primitive to tools/resources/extensions;
- URI/handle ownership and grammar;
- transport and deployment topology;
- synchronous versus task execution threshold;
- state persistence and restart behavior;
- mutation atomicity, revisions, and idempotency;
- direct data-plane choice for high-rate/large data;
- authorization model and human approval points;
- executable-content, filesystem, device, and network policy;
- retention, telemetry, and sensitive-data policy.

---

## 12. Security, privacy, and trust boundaries

### 12.1 Classification

| Dimension | Classification |
| --- | --- |
| Server relationship | `internal_proxy_built / internal_proxy_consumes_third_party / third_party_consumed` |
| Deployment | `local_stdio / remote_streamable_http / mixed` |
| Data | `public / internal / non-public / regulated / sensitive` |
| Effects | `read / write / delete / code execution / filesystem / device / network` |
| Identity | `system / user-delegated / mixed` |
| Runtime scope | `{{...}}` |

### 12.2 Trust-boundary map

| Boundary | Untrusted input | Validation | Authorization | Isolation | Output sanitization/logging |
| --- | --- | --- | --- | --- | --- |
| MCP client → server | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Server → domain runtime | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Runtime/data plane → client | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Third-party package/API | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

### 12.3 Required controls

- Validate every tool input and schema-constrained representation.
- Authorize every operation and every URI/task/handle access; never infer authority from possession alone when authenticated identities exist.
- Confine filesystem paths to declared roots and reject traversal after canonicalization.
- Define whether arbitrary executable artifacts are prohibited, sandboxed, or require approval; specify CPU, memory, duration, device, filesystem, and network limits.
- Rate-limit effects and polling independently.
- Treat tool descriptions, resource contents, third-party results, and generated code as untrusted content.
- Keep secrets and sensitive payloads out of tool descriptions, headers, resource URIs, logs, and diagnostics.
- Require human approval for `{{HIGH_IMPACT_ACTIONS}}`.
- Define kill switch, rollback, and credential revocation procedures.
- Pin and verify third-party dependencies and detect manifest/tool drift.

### 12.4 Requirement/control traceability

| Control/requirement ID | Applicability | Specification section | Evidence | Gap/owner |
| --- | --- | --- | --- | --- |
| `{{REQ_ID}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

---

## 13. Implementation architecture

### 13.1 Components and ownership

| Component | Owns | Does not own | Interface to next component | Failure containment |
| --- | --- | --- | --- | --- |
| MCP adapter | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Public resource registry | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Domain runtime adapter | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Task executor/store | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Direct data-plane adapter | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

### 13.2 Public-to-internal adapter map

| Public operation/resource | Existing seam invoked | Awaited acknowledgement | Internal IDs created | Public effect published | Compensation/recovery |
| --- | --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{HIDDEN}}` | `{{...}}` | `{{...}}` |

### 13.3 Dependency and lifecycle order

1. `{{STARTUP_STEP}}`
2. `{{...}}`
3. `{{READY_CONDITION}}`

Shutdown order:

1. `{{STOP_ACCEPTING_NEW_WORK}}`
2. `{{DRAIN_OR_CANCEL}}`
3. `{{PERSIST_OR_TOMBSTONE}}`
4. `{{RELEASE_RUNTIME_RESOURCES}}`

### 13.4 Configuration

| Setting | Default | Required? | Security sensitivity | Reload behavior | Why it must be configurable |
| --- | --- | --- | --- | --- | --- |
| `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

Do not expose implementation tuning as public MCP surface unless callers legitimately need to control it and no safe default exists.

---

## 14. Observability and operations

### 14.1 Structured event model

| Event | Required fields | Sensitive fields excluded/redacted | Retention | Alert condition |
| --- | --- | --- | --- | --- |
| Request received | `request/trace ID, method/name, caller, protocol version` | `{{...}}` | `{{...}}` | `{{...}}` |
| Effect committed | `target URI, prior/new revision, effect URIs, duration` | `{{...}}` | `{{...}}` | `{{...}}` |
| Task transition | `task ID hash/ref, prior/new status, worker, duration` | `{{...}}` | `{{...}}` | `{{...}}` |
| Runtime restart/rebind | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |
| Security denial | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

### 14.2 Service-level objectives and limits

| Signal | Target/limit | Measurement point | Failure action |
| --- | --- | --- | --- |
| Immediate tool latency | `{{...}}` | `{{...}}` | `{{...}}` |
| Resource read latency | `{{...}}` | `{{...}}` | `{{...}}` |
| Task acknowledgement latency | `{{...}}` | `{{...}}` | `{{...}}` |
| Task queue depth/age | `{{...}}` | `{{...}}` | `{{...}}` |
| Resource size/count | `{{...}}` | `{{...}}` | `{{...}}` |
| Direct stream jitter/drop | `{{...}}` | `{{...}}` | `{{...}}` |

### 14.3 Operational procedures

- Health/readiness definition: `{{...}}`
- Backup/restore of public and task state: `{{...}}`
- Runtime engine recovery/rebinding: `{{...}}`
- Schema/protocol upgrade: `{{...}}`
- Rollback: `{{...}}`
- Kill switch: `{{...}}`
- Incident owner: `{{...}}`
- Dependency/manifest drift response: `{{...}}`

---

## 15. Verification plan

### 15.1 Contract test matrix

| Test ID | Requirement/guarantee | Layer | Setup | Oracle | Required result |
| --- | --- | --- | --- | --- | --- |
| T-001 | `G-...` | `schema / adapter / integration / system / security / recovery` | `{{...}}` | `{{...}}` | `{{...}}` |

### 15.2 Minimum verification set

- Schema validation for every tool request/result and resource representation.
- Protocol conformance for the pinned MCP revision.
- Discovery/list determinism and authorization partitioning.
- Primitive-to-domain derivation coverage for every approved operation.
- Replay, concurrency, stale revision, and atomic publication tests.
- Restart/reconnect tests proving public identity is independent of runtime identity.
- Task durability, polling, input, cancellation race, expiry, and authorization tests.
- Security tests for path traversal, injection, arbitrary code, secret leakage, oversized payloads, rate limits, and cross-caller access.
- Direct data-plane timing/backpressure tests where applicable.
- Graceful shutdown and kill-switch tests.
- Compatibility tests for each claimed client/protocol revision.

### 15.3 Acceptance gate

The specification is implementation-ready only when:

- every OBS primitive has exactly one public MCP mapping;
- every approved domain operation has a derivation;
- every public schema is complete and versioned;
- state is classified as public, internal, or application with one owner;
- synchronous, task, and continuous-runtime work are distinguished;
- all guarantees have an observable oracle or an explicitly owned evidence gap;
- all high-risk falsification scenarios have expected behavior;
- security, privacy, operations, and rollback owners are named;
- remaining blockers require user/domain judgment rather than discoverable technical facts.

---

## 16. Implementation planning handoff

### 16.1 Planned vertical slices

| Slice | End-to-end capability | Public contract exercised | Internal seams | Verification | Depends on |
| --- | --- | --- | --- | --- | --- |
| VS-001 | `{{SMALLEST_END_TO_END_SLICE}}` | `{{...}}` | `{{...}}` | `{{...}}` | `{{...}}` |

The first slice SHOULD prove one approved primitive end-to-end through the real domain runtime and back to an observable result. Avoid building all schemas, all adapters, or all use-case assets before one real path works.

### 16.2 Open questions

| ID | Blocking? | Question | Resolution owner | Safe default | Evidence/action needed | Due gate |
| --- | --- | --- | --- | --- | --- | --- |
| OPEN-001 | `yes / no` | `{{...}}` | `agent/self / user / domain owner / security` | `{{...}}` | `{{...}}` | `{{...}}` |

### 16.3 Deferred capabilities

| ID | Deliberate cut | Current ceiling | Upgrade trigger | Upgrade path |
| --- | --- | --- | --- | --- |
| DEFER-001 | `{{...}}` | `{{...}}` | `{{MEASURABLE_TRIGGER}}` | `{{...}}` |

---

## 17. Official MCP references

Verify these references at specification time and pin the exact revision used:

- [MCP 2026-07-28 release](https://blog.modelcontextprotocol.io/posts/2026-07-28/) — stateless protocol, explicit cross-call handles, discovery/caching changes, and Tasks extension placement.
- [Discovery](https://modelcontextprotocol.io/specification/draft/server/discover) — `server/discover`, supported versions, capabilities, and cache hints.
- [Tools](https://modelcontextprotocol.io/specification/draft/server/tools) — tool schemas, structured results, errors, state handles, validation, access controls, rate limits, and human-in-the-loop guidance.
- [Resources](https://modelcontextprotocol.io/specification/draft/server/resources) — URI identity, list/read behavior, caching, and notification subscriptions.
- [SEP-2663: Tasks Extension](https://modelcontextprotocol.io/seps/2663-tasks-extension) — durable long-running work, polling, input, cancellation, and task security.

---

## Appendix A. Non-normative SuperCollider substrate example

> Delete this appendix for unrelated servers. It demonstrates how to fill the template; it is not an additional interface decision.

Boundary: the MCP server is a SuperCollider substrate, not a game, DAW, visualizer, song player, or instrument-editing application.

Approved public model:

- Noun: `Resource`
- Custom effect primitive: `apply`
- Observation: standard MCP `resources/list`, `resources/read`, and negotiated change subscriptions
- Derived operations: create, update, delete/tombstone, evaluate source, set control, send event, start/replace finite runtime definitions, and request offline artifacts
- High-rate data: direct loopback transport described by a resource, not tool-call frames

Example public state:

- stable caller-owned `sc://...` resource URIs;
- descriptors and representations;
- revisions, effects, diagnostics, analysis values, artifact links, and stream descriptors;
- finite offline renders represented as task results and/or resources.

Example internal state:

- `sclang` process/environment;
- `scsynth` process, synth/group/node IDs;
- bus and buffer IDs;
- OSC routing, temporary files, device handles, caches, and reconnect bookkeeping.

Example application state:

- games, players, scores, difficulty, target-note acceptance, song progress;
- UI layout, sliders, keyboard/vocal visualizations, rendering engines;
- agent conversation history and aesthetic approval workflow.

Naive tool names to reject include `create_game_session`, `start_song`, `create_drum_kit`, `make_retro_arcade_synth`, `render_keyboard`, `set_whistle_filter`, and `score_pitch`. These are application compositions or authored resources, not substrate primitives.
