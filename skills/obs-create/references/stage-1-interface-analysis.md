Contents: [1a Service identity](#1a-service-identity) · [1b Interface enumeration](#1b-interface-enumeration-all-of-the-following-that-apply) · [1c Render paths](#1c-render-paths--explicit-investigation-required) · [1d Domain objects](#1d-domain-object-identification) · [Stage 1 results block](#stage-1-results-block) · [Vocabulary target](#vocabulary-target)

## Stage 1 — Interface Analysis

**Delegate to the Analyst** to enumerate every interface the service exposes and consumes.
Use the next available analysis ID from `.agent-output/.next-id` (fallback: scan
`.agent-output/analysis/` for the highest NNN and use NNN+1). Save the document to
`.agent-output/analysis/<ID>-<service>-interface-inventory.md`.

### 1a. Service identity

- Source directory (the one found in Stage 0)
- Config file (e.g. `config/<ServiceName>.json` or `config/<service-name>.json`) — lists
  all topic/channel keys and their routing keys
- Service entry-point (e.g. `src/<ServiceName>.cpp`, `src/<ServiceName>Server.cpp`,
  `<service_name>/server.py`, `main.py`)

### 1b. Interface enumeration (ALL of the following that apply)

**C++ services** — search patterns:

| Channel | What to find | How to find it |
|---|---|---|
| **Message-bus subscribe** (clients → service) | Every topic the service subscribes to: routing key, payload type, handler | Config + `subscribe(` / `subscribeAdvanced(` calls |
| **Message-bus publish** (service → clients) | Every topic the service publishes: routing key, payload type, emitter | `publishTemplate(` / `publish(` calls |
| **Database / persistence** | Collections read/written | `RecordManager`, domain-specific DB classes, `loadFrom`, `saveTo`, `create(`, `update(` |
| **File I/O** | Direct filesystem reads/writes | `fstream`, `ifstream`, `ofstream`, path manipulation |
| **DDS topics** | Any DDS read/write | `dds::`, `DDSTopic`, `DataWriter`, `DataReader` |
| **Instrument / sensor data** | Tool tracking, pose data, sensor readings | domain-specific sensor APIs, tracking APIs |
| **IPC / RPC** | Synchronous RPC patterns | `publishRPCTemplate`, `publishRPC` |
| **Events / shared memory** | Cross-service event bus or shared-memory channels | `EventManager`, `IPCObject`, `SharedMemory` |
| **Audit / observability** | State-changing audit writes | `AuditLog`, audit topic subscriptions |
| **3D scene / rendering** | Topics consumed by the rendering service | Search the rendering service's subscription list for service topics |
| **GUI panel / state topics** | Topics consumed by UI panels for state display | Search the UI framework for subscriptions referencing service topics |

**Python services** — equivalent patterns:

| Channel | What to find | How to find it |
|---|---|---|
| **Message-bus subscribe** | RMQ queue/topic bindings | `channel.queue_bind`, `basic_consume`, `subscribe(`, pika callback registrations |
| **Message-bus publish** | RMQ publishes | `basic_publish`, `channel.publish`, `messenger.publish` |
| **Database / persistence** | DB reads/writes | `pymongo`, `psycopg2`, `sqlite3`, SQLAlchemy models |
| **File I/O** | Filesystem reads/writes | `open(`, `Path(`, `os.path`, `json.load`, `json.dump` |
| **DDS topics** | DDS read/write | `cyclonedds`, `DataWriter`, `DataReader`, `Topic(` |
| **REST / HTTP** | Outgoing HTTP calls | `requests.`, `httpx.`, `aiohttp.`, `urllib` |

**If fewer than 2 channel types produce results:** report this to the user before continuing.

### 1c. Render paths — explicit investigation (REQUIRED)

For EVERY topic the service publishes, determine whether it reaches:
- **3D viewport / scene** (the rendering service's subscription list) — YES / NO
- **GUI panel / side panel** (the UI framework's subscription list) — YES / NO
- **Neither** (data bus only — other services/controllers consume it)

**How to verify** (do NOT assume — check the source):
1. Find the rendering service's subscription registration (e.g. `topicSubscriptions()` or
   equivalent). List every topic it subscribes to. Mark YES only if the service's topic
   appears there.
2. Find the UI framework's panel subscription registration (e.g. `bulkSubscribe` calls or
   equivalent). Mark YES only if the service's topic appears there.
3. Check for **indirect auto-propagation paths**: intermediate GUI workflow controllers that
   subscribe to the service's data topic and re-publish to the render channel. These paths
   are conditional on the workflow controller being active — a headless adapter cannot rely
   on them. Flag them separately as "indirect (conditional)".

Present results in a render-path matrix.

### 1d. Domain object identification

From the payload types found above, list the service's **canonical data objects**.
For each object note which fields are:
- **Mutable by client** (settable via bus topics)
- **Server-derived** (assigned by server: IDs, computed fields, lifecycle flags)
- **Read-only** (returned in queries only, not settable)

---

### Stage 1 results block

**After the Analyst completes Stage 1**, present a structured summary to the user:

```
=== STAGE 1 RESULTS: <ServiceName> Interface Inventory ===

SUBSCRIBE TOPICS (<N> total):
  [routing key | payload type | purpose]
  ...

PUBLISH TOPICS (<N> total):
  [routing key | payload type | trigger condition]
  ...

RENDER PATHS:
  3D viewport:           [topics reaching the render service — or NONE]
  GUI panels:            [topics reaching the UI framework — or NONE]
  Indirect (conditional):[topics via workflow controllers — or NONE]
  Bus-only:              [topics consumed by other services/controllers]

OTHER CHANNELS:
  Database:     [collections / tables accessed]
  File I/O:     [paths / patterns]
  DDS:          [topics]
  RPC:          [endpoints]
  Events/IPC:   [channels]

CANONICAL OBJECTS:
  <Noun>: mutable=[fields] | server-derived=[fields] | read-only=[fields]
  ...
```

Ask: **"Does this inventory look complete? Anything to add or correct before I frame the domain?"**
Wait for confirmation before proceeding to Stage 2.

---

### Vocabulary target

In vocabulary mode the Analyst enumerates the vocabulary instead of a service's interfaces. The
inventory is saved to `.agent-output/analysis/<ID>-<vocabulary>-interface-inventory.md`.

**1a. Vocabulary identity.** The grammar or schema source location (from Stage 0), the IR
definition, each code generator, and the corpus of documents written in the vocabulary.

**1b. Vocabulary enumeration (ALL that apply):**

| Channel | What to find | How to find it |
|---|---|---|
| **Grammar rules** | Every production, keyword and construct the grammar admits | The grammar or schema source |
| **IR node kinds** | Every node kind the front end produces, with its fields | The IR definition and the front end that builds it |
| **Codegen targets** | Every artifact kind generated, and the IR node kinds each consumes | The code generators |
| **Host-language-defined vocabulary** | Builtins, operators and library names the vocabulary inherits from its host language | Expression and evaluation code; imports in the front end |
| **Library-defined vocabulary** | Standard policies, presets and named helpers shipped beside the grammar | The vocabulary's library directories |
| **Sub-languages** | Embedded mini-languages (expressions, patterns, templates) with their own grammar | String-typed fields that are parsed again |

**If fewer than 2 of these produce results:** report this to the user before continuing.

**1c. Render paths.** N/A for a vocabulary target. State "N/A — vocabulary target" in the
inventory and the results block; do not investigate render paths.

**1d. Canonical constructs.** In place of canonical data objects, list each construct kind or IR
entity, with its attributes marked author-set, defaulted, or derived.

**Results block.** Use the same block with these sections in place of the topic, render and
channel sections:

```
=== STAGE 1 RESULTS: <VocabularyName> Vocabulary Inventory ===

GRAMMAR RULES (<N> total):
  [rule or keyword | what it admits | layer]
  ...

IR NODE KINDS (<N> total):
  [node kind | fields | produced by]
  ...

CODEGEN TARGETS:
  [target | IR node kinds consumed]
  ...

HOST-LANGUAGE-DEFINED VOCABULARY:
  [builtin / operator | where used]
  ...

RENDER PATHS: N/A — vocabulary target

CANONICAL CONSTRUCTS:
  <Construct>: author-set=[attrs] | defaulted=[attrs] | derived=[attrs]
  ...
```

**Accepting the hand-off payload.** When `basis-redesign` supplies a Stage 1 results block, use
it as this block. Do not delegate the Analyst or re-enumerate. The caller renders its parts into
the block above: the inventory sections carry the catalog, and the block appends the sections
`VOCABULARY LAYERS`, `DISPOSITIONS` (each construct's disposition with both overlay flags and
evidence ids), `BASES` (every alternative basis, ties included), `CONFIRMED SCOPE DECISIONS` and
`CAPABILITY BASELINE`, each as a heading line followed by one entry per line. Check that every
one of them is present; ask the caller for anything missing. Present it to the user as the
Stage 1 summary and ask the confirmation question above.
