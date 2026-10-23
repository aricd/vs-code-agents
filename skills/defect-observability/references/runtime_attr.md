# Module: runtime_attr (rung 5)

**Purpose.** File-level defect evidence that does not depend on commit hygiene at all: a
runtime failure attributed to the top in-repo frame of its traceback labels that file
directly, whether or not anyone later writes `fix:`. This is the purest defect sensor and
the strongest complement to commit-derived labels.

**Artifact.** `{artifacts_dir}/errors.jsonl`:

```json
{"ts": "2026-07-03T14:05:00Z", "kind": "KeyError", "fingerprint": "a41f0c22",
 "file": "src/pkg/router.py", "function": "dispatch", "line": 214,
 "boundary": "tool_dispatch", "context": {"tool": "lookup_class"}}
```

`fingerprint` = short hash of (kind, file, function) — stable across line drift, groups
recurrences. `file` = top **in-repo** frame (skip stdlib/site-packages/vendored). `boundary`
= the declared boundary name that caught it. `context` small and non-sensitive: no payloads,
no user data, no secrets — this file gets committed.

**Boundaries.** Declared in config: `runtime_attr: { state: advisory, boundaries:
["tool_dispatch", "cli_main"] }`. A boundary is wherever failures already converge — an MCP
server's dispatch, a web framework's error middleware, a worker's job loop, `main()`. Wrap
each with the recorder (`@observe_boundary("name")` or the `record_failure(exc)` call in an
existing except block). **Recorder rules:** it must re-raise or preserve existing handling
(observation, not suppression), and it must swallow its *own* errors — a broken sensor
must never break the app.

**Install.** Copy/adapt `scripts/record_failure.py` into the codebase (it is ~60 lines and
dependency-free — vendoring it is the point; the app must not import from a skill).
Register boundaries in the YAML. Trigger one synthetic failure and verify the record.

**Maintenance-mode duty.** New handlers/endpoints/tools inside a declared boundary are
covered automatically; a NEW failure-convergence point (second server, new CLI entry)
needs wrapping and adding to `boundaries` — do it as part of building it.

**Broken means.** A declared boundary whose code path no longer routes through the
recorder. Staleness does NOT apply — no errors is a fine state; `check_sensors` verifies
wiring (recorder import present at each declared boundary), not recency.

**Portability.** Same schema everywhere: JS wraps the Express error middleware; Go wraps
recover(); JVM wraps the top-level exception handler.
