# CREST Effect Policy Template

> Copy `effect_policy.example.json` to `effect_policy.json` in your project root,
> fill in the project-specific sections, and commit. `crest_metrics.py` picks it
> up automatically via `--effect-policy` or auto-discovery in the CWD.

**Version:** v1  
**Used by:** `crest_metrics.py` (loaded via `_load_effect_policy`).

This document explains the three-tier effect model so you can make deliberate,
documented decisions about what counts as "pure" in your project.

---

## 1. HARD effects — always impure

A function with a HARD effect in its own body is **own-impure** (and deep-impure).
These are irreducibly side-effectful: they touch the outside world in a way that
cannot be verified by inspecting return values alone.

| Effect class | Examples |
|---|---|
| `io` | `open()`, `Path()`, `json.dump/load`, `os.makedirs`, `shutil.*`, `.write()`, `print()` |
| `network` | HTTP clients (`requests`, `httpx`, `urllib`), gRPC, SOAP stubs, `socket.*`, `boto3`, `paramiko` |
| `db` | SQL execution (`.execute()`, raw DML strings), `sqlite3`, SQLAlchemy, PyMongo, Motor |
| `time_random` | `datetime.now`, `uuid.*`, `time.*`, `random.*`, `perf_counter` |

HARD-effect functions belong in the **imperative shell**. They should be thin
wrappers that delegate all logic to pure functions, then perform the effect.

**Extending for your project:** add project-specific patterns to
`effect_policy.json["hard_effect_patterns"]["network"]` and
`["db"]`. Example — zeep SOAP client:
```json
"network": ["\\brequests\\.", "\\bhttpx\\.", "\\bzeep\\.", "\\bclient\\.service\\."]
```

---

## 2. SOFT effects — conditionally impure

SOFT effects **disqualify deep-purity** but **not own-purity**. A function with
only soft effects can still be tested cheaply (no live I/O needed) but it
mutates shared state or carries asynchrony.

| Effect class | Detection | Implication |
|---|---|---|
| `state_mutation` | `self.x =`, `.append()`, `.update()`, `.pop()` on `self`/params | Disqualifies deep-pure; function modifies caller-visible state |
| `async_io` | `await`, `asyncio.*` presence | Disqualifies deep-pure; requires async test harness |

**Non-escaping local mutation** (e.g. building a list inside the function then
returning it) is NOT flagged. The scan distinguishes `self`/parameter mutation
from purely local accumulation.

---

## 3. AMBIENT effects — project-sanctioned exemptions

AMBIENT effects are an **explicit opt-in**. The default is: no exemptions —
logging is treated as HARD (`logging.` matches no built-in pattern so it is not
HARD by default either, but you may choose to make it so).

**Default built-in ambient:** `logger.*`, `log.*`, `logging.*` patterns are
listed in `AMBIENT_LOGGING_PATTERNS` but count as ambient (exempt) — they do
not disqualify own-purity. This is a deliberate default because logging is
observability, not behavior.

**Consequence (mandatory):** any snapshot produced with an active ambient
exemption reports `Confidence: Medium` in the meta block.

**Guardrail:** the exemption covers the logging call itself, not its arguments.
`logger.info(open(path).read())` still trips the `io` pattern.

To disable the logging exemption entirely, add logging to the HARD patterns:
```json
"hard_effect_patterns": {
  "network": [...],
  "db": [...],
  "_note": "To treat logging as HARD, add r\"\\blogger\\.\" | r\"\\blog\\.\" | r\"\\blogging\\.\" to the io list (not overridable via JSON; edit the script's HARD_EFFECT_PATTERNS directly)"
}
```

---

## 4. Substrate modules — boundary exemptions

Some modules legitimately own an infrastructure boundary (e.g. a database
session manager, a SOAP client adapter). Functions in these modules are expected
to expose infra types in their signatures and are **exempt from the
`signature_infra_leak_ratio` gate**.

Configure via `effect_policy.json["substrate_modules"]`:
```json
"substrate_modules": {
  "db/session.py": "db",
  "clients/soap_adapter.py": "network"
}
```

The `substrate_exempt_count` descriptor in the snapshot surfaces the exemption
footprint so reviewers can see how wide the allowlist has grown.

---

## 5. Extending CREST for a new project

1. **Copy** `effect_policy.example.json` → `effect_policy.json` in your project root.
2. **Add project-specific patterns** for any framework-specific network/DB clients.
3. **Set `substrate_modules`** for modules that own infrastructure boundaries.
4. **Set `infra_bare_types`** for any bare type names (no import prefix) from infra libraries.
5. **Bootstrap** a baseline:
   ```bash
   python crest_metrics.py --src src/ --write-baseline crest_baseline.json
   ```
6. **Run the ratchet** in CI:
   ```bash
   python crest_metrics.py --src src/ --check crest_baseline.json
   ```
   Exit 0 = no regression, 1 = regression (fail the build), 2 = config error.
7. **Improve** over time: the ratchet only fails when metrics regress; improvements
   are logged as "improved" and automatically become the new floor when you
   re-baseline.

---

## What is NOT an effect

- **Non-escaping local mutation** — building a list inside a function and returning it.
- **Deterministic exceptions** on contract violation — same input always raises the same exception.
- **Reads of an injected immutable value** — a config parameter passed as an argument is not state.
- **Type annotations and docstrings** — static metadata, not runtime behavior.
