# Module: mutation (rung 6)

**Purpose.** When a repo is too young to have enough real defects, mutation testing
manufactures synthetic ones: a surviving mutant in a file means a plausible bug there that
the test suite would NOT catch. "High complexity × low kill-rate" is the most actionable
report a label-poor repo can produce, available on demand with zero history.

**Artifact.** `{artifacts_dir}/mutation.jsonl`:

```json
{"ts": "2026-07-03T02:00:00Z", "sha": "3bc3de78", "file": "src/pkg/router.py",
 "mutants": 58, "killed": 41, "survived": 17, "kill_rate": 0.707, "tool": "mutmut"}
```

One record per file per run. Do not store individual mutant diffs in the artifact (bulky);
the tool's own cache holds those.

**Scope discipline — this is the burden-control module.** Never run repo-wide. Target only
the current top-K hotspot files (from the `reports` ranking; K from config, default 10),
on a schedule (default monthly), never in the inner loop, never as a merge gate. Mutation
at load-bearing means "the monthly run happens", NEVER "kill-rate must exceed X".

**Install.** `scripts/mutation_targets.py` emits the target list from the report ranking
and, when mutmut is available, runs it per-target and appends records. Wire to a scheduled
CI job (`assets/ci-workflow.yml` includes a commented schedule block).

**Broken means.** No record within 2× the configured cadence.

**Portability.** JS: Stryker; JVM: PIT; Go: go-mutesting. Same record shape; `tool` field
names the engine.
