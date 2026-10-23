# Module: ci (rung 4)

**Purpose.** A repo without CI loses a row of test-outcome data at every merge, forever.
This module gives sensors a scheduler, starts the test/coverage event stream, and hosts
the load-bearing gate.

**Artifact.** `{artifacts_dir}/ci_events.jsonl`:

```json
{"ts": "2026-07-03T14:02:11Z", "sha": "3bc3de78", "job": "test", "status": "pass",
 "duration_s": 41.2, "failed_tests": [], "coverage_pct": 78.1,
 "coverage_by_file": {"src/pkg/mod.py": 64.0}}
```

`failed_tests` are fully-qualified test IDs. `coverage_by_file` optional but high-value
(enables complexity×low-coverage). One record per job per run.

**Workflow duties, in order** (see `assets/ci-workflow.yml` for GitHub Actions):
(1) checkout with full history; (2) run tests + coverage, appending the event record
**even on failure** — red runs are the valuable ones; (3) run enabled sensors (snapshot,
churn); (4) run `check_sensors.py` — this step is what makes load-bearing real: it exits
nonzero if any load-bearing artifact is missing/stale; (5) persist artifacts.

**Persisting artifacts — two options.** (a) Bot-commit `.observability/` back to the
default branch as `chore(observability): append sensor records [skip ci]` — durable,
survives CI retention, and the churn module already excludes it. (b) Upload as CI
artifacts — cleaner history, but records expire with retention policy. Default to (a);
respect an existing repo preference.

**Broken means.** Workflow file absent, `check_sensors` step removed, or no ci_event
within `freshness_days` despite merges. Removing the gate step from the workflow IS
breaking the sensor — maintenance mode restores it.

**Portability.** Specs name duties, not GitHub. GitLab CI / Jenkins / Buildkite implement
the same five duties in their own syntax.
