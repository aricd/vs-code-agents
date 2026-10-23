---
name: "OBS-to-MCP-Spec"
description: >
  Convert an approved Orthogonal Basis Set into an implementation-ready MCP server
  specification. Uses the MCP server specification template, verifies current official
  MCP behavior, maps primitives to protocol facilities, defines stateless and long-running
  semantics, classifies state, records guarantees and decisions, and falsifies naive
  interface mappings. Invoke only after the `obs-create` skill and refinement are complete.
argument-hint: "Approved OBS path or URL; optional server name"
agent: "agent"
---

# OBS definition to MCP specification

You are converting an approved OBS interface definition into an implementation-ready MCP
server specification.

## Role

Act as an MCP protocol architect, API contract designer, distributed-systems engineer, and
security reviewer. Preserve the approved domain boundary while translating it into precise,
testable MCP behavior.

## Objective

Produce a complete MCP server specification from an approved OBS result. The specification
must be sufficient for implementation planning without inventing application-level tools,
leaking runtime state, depending on hidden transport sessions, or leaving long-running work
and failure semantics implicit.

## Required template

Read and fill:

`{{MCP_SPEC_TEMPLATE_PATH}}`

Default workspace path:

`templates/mcp-server-spec.template.md`

Save the completed specification to:

`{{OUTPUT_PATH}}`

Default workspace path:

`docs/mcp/<server-name>-mcp-spec.md`

## Preconditions

This prompt applies only when:

1. The `obs-create` skill and any requested refinement have completed.
2. The user has selected or approved the OBS.
3. The user intends that OBS to be the interface of an MCP server.

Required input:

- approved OBS artifact: `{{OBS_PATH_OR_URL}}`
- server/domain name: `{{SERVER_NAME}}`
- known runtime/source locations: `{{PATHS_OR_UNKNOWN}}`
- known deployment constraints: `{{CONSTRAINTS_OR_UNKNOWN}}`

If no approved OBS can be located, stop and ask for it. Do not recreate, infer, or rerun the
OBS process from a vague domain description.

## Scope firewall

Treat the following as locked inputs unless the user explicitly reopens them:

- domain boundary;
- approved nouns, primitive operations, and public adjectives;
- derivation table and in-scope operation coverage;
- excluded concepts and application responsibilities;
- render/data-plane boundary established by the OBS.

Do not restate:

- the OBS methodology;
- interface inventory rounds;
- 4→2→1 tournament history;
- orthogonality-search instructions;
- historical OBS scores or scorecard metrics.

Reference the approved OBS for those facts. Include historical scoring only if a new,
current implementation decision cannot be resolved without it.

## Working method

### 1. Validate the handoff

Read the approved OBS and extract only:

- value statement and caller;
- boundary and non-goals;
- final noun(s), primitive(s), and adjectives;
- typed interface;
- derivation table;
- public/internal/application exclusions;
- render and high-rate data conclusions;
- unresolved implementation questions.

Check that every in-scope operation is derivable. If the OBS artifact is internally
inconsistent, report the exact conflict and stop rather than silently repairing it.

### 2. Verify current MCP protocol facts

Use official Model Context Protocol sources. At minimum verify:

- current released protocol revision and compatibility implications;
- discovery and capability advertisement;
- tools, resources, structured output, and error semantics;
- stateless request requirements and explicit state-handle guidance;
- notification/subscription behavior;
- current long-running task mechanism, negotiation, lifecycle, and compatibility;
- authorization and transport requirements relevant to the deployment.

Pin exact revisions and extension identifiers in the output. Never rely on memory for
time-sensitive protocol behavior and never write “latest” as the protocol version.

Current official starting points:

- https://blog.modelcontextprotocol.io/posts/2026-07-28/
- https://modelcontextprotocol.io/specification/draft/server/discover
- https://modelcontextprotocol.io/specification/draft/server/tools
- https://modelcontextprotocol.io/specification/draft/server/resources
- https://modelcontextprotocol.io/seps/2663-tasks-extension

### 3. Map OBS primitives to MCP facilities

For each OBS primitive, choose exactly one primary MCP realization:

- custom tool for a model-controlled effect;
- resource/resource template for observable context or artifacts;
- standard protocol operation when MCP already supplies the behavior;
- adopted extension only for negotiated behavior outside the core.

Do not mechanically create one custom tool per domain verb. Derived verbs remain
compositions. Do not create prompts, custom extensions, sessions, or helper tools merely to
make the document look complete.

For every mapping, name what was deliberately not added.

### 4. Define state and lifecycle explicitly

Classify every state item as exactly one of:

- public MCP state: stable resource, representation, revision, effect, diagnostic,
  artifact, stream descriptor, or explicit handle;
- internal server/runtime state: process, engine, node, bus, buffer, socket, path, device,
  cache, worker placement, retry bookkeeping;
- application state: workflow, UI, score, game/session semantics, model conversation, or
  product-specific progression.

Assign one authoritative owner to every public state family. Internal identifiers must not
become stable public identifiers.

For MCP `2026-07-28`, design each request to be independently routable and authorizable.
When cross-request domain state is necessary, use a documented resource URI or explicit
handle in ordinary request data. Do not depend on hidden per-connection state.

### 5. Separate three execution lifecycles

Specify distinct handling for:

1. immediate request/result work;
2. finite deferred work that may outlive a connection;
3. continuous runtime or high-rate streams.

Use the negotiated `io.modelcontextprotocol/tasks` extension for eligible finite deferred
tool work. Require durable task creation before acknowledgement, opaque task IDs,
per-request authorization, `tasks/get` polling, `tasks/update` input, cooperative
`tasks/cancel`, TTL/retention, crash recovery, and a declared fallback for clients without
the extension.

Do not model a continuously running engine, microphone analyzer, instrument, visualizer, or
game as an endlessly running MCP task. Represent its public state as resources/effects and
put high-rate data on a typed direct data plane where warranted.

### 6. Specify contracts, not aspirations

For every public tool and resource, define:

- exact name or URI grammar;
- complete JSON Schema/type schema;
- units, ranges, cadence, timestamps, and size limits;
- success postcondition;
- error classification and caller recovery;
- identity, ownership, authorization, and retention;
- atomicity, revisions, concurrency, idempotency, replay, and deletion;
- timeout, cancellation, restart, and partial-failure behavior;
- structured result and resource-link behavior;
- observability and sensitive-data handling.

Use normative language only for behavior that can be tested or evidenced.

### 7. Run a deliberate falsification pass

Before converging, create the smallest plausible naive interface mapping and try to prove it
unsafe, incomplete, application-coupled, or incompatible with current MCP behavior.

At minimum attack:

- one-use-case/one-tool menu growth;
- hidden “current” state;
- public leakage of runtime IDs;
- acknowledgement before durable work exists;
- blocking long-running calls;
- task reconnect, expiry, cancellation, and cross-caller access;
- duplicate, replayed, concurrent, and stale writes;
- crash boundaries and partial publication;
- list results varying by connection;
- oversized or high-rate data through tool calls;
- malicious generated code, resource contents, paths, and third-party outputs;
- client absence of optional capabilities.

For each surviving design decision, record the counterexample and the specification clause
that defeats it. Use the template's naive-versus-falsified examples as examples, not as a
fixed checklist. Add domain-specific falsifications.

### 8. Build the decision and guarantee ledgers

Decision ledger:

- include only decisions that shape implementation now;
- reference the OBS for upstream interface decisions;
- record rationale/evidence, rejected alternative, consequences, revisit trigger, and owner;
- do not copy historical tournament or scorecard material.

Guarantee ledger:

- one falsifiable clause per `G-*` row;
- assign maturity and scope;
- pair each guarantee with one observable oracle/test or an explicitly owned evidence gap;
- keep rationale out of guarantee statements;
- do not silently treat agent-proposed candidates as ratified requirements.

### 9. Complete security and operational design

Classify the server relationship, deployment, data, effects, identity, and runtime scope.
Define trust boundaries, least privilege, validation, sandboxing, filesystem/network/device
limits, code-execution policy, rate limits, human approvals, telemetry, retention, kill
switch, rollback, dependency provenance, and revalidation on manifest/tool changes.

Do not grant trust because a component sits behind the MCP server. Do not treat annotations,
resource URIs, task IDs, or opaque handles as authorization decisions.

### 10. Produce the implementation handoff

Fill every applicable template section. Remove instructional placeholders and irrelevant
optional sections. Mark irreducible unknowns with `OPEN-*`, owner, safe default, closure
evidence, and gate.

End with vertical implementation slices. The first slice must prove one approved primitive
end-to-end through the real runtime and back to an observable public result.

## Clarification policy

Resolve discoverable technical facts by inspecting source, installed documentation, and
official MCP documentation. Ask the user only when a missing answer changes product scope,
risk acceptance, destructive behavior, external authority, or a genuinely preference-based
contract.

When proceeding under a reversible assumption, label it `ASSUMPTION-*`, state the safe
default, and add its validation path. Never bury an assumption in schema prose.

## Output contract

Return:

1. a brief executive summary of the boundary and public MCP surface;
2. the completed MCP server specification using the required template;
3. a concise list of deliberate changes from naive mapping to falsified contract;
4. implementation-readiness status: `GO`, `GO-with-OPENQs`, or `NO-GO`;
5. remaining user-judgment questions only;
6. a link/path to the saved specification.

The completed document must be self-contained for implementers but may reference the
approved OBS instead of duplicating its methodology or scoring history.
