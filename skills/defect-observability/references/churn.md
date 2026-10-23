# Module: churn (rung 2)

**Purpose.** Churn is the strongest single defect signal in the literature and costs one
git walk. This sensor appends per-commit per-file line deltas so any consumer can compute
windowed churn without re-walking history.

**Artifact.** `{artifacts_dir}/churn.jsonl`:

```json
{"sha": "86c1f450", "ts": "2026-06-20T10:11:00Z", "file": "src/pkg/mod.py",
 "added": 41, "deleted": 12, "renamed_from": null, "commit_type": "refactor"}
```

Rules: one record per file per commit. `renamed_from` set when git reports a rename
(pure-rename commits — see git-commit-message — make this reliable). `commit_type` is the
conventional-commit prefix when parseable, else null; consumers use it to exclude
mechanical commits (`style:`, `chore(observability)`). **Exclude `{artifacts_dir}/` paths**
so sensor bot-commits never count as churn. Idempotency: keep the last processed SHA in
`{artifacts_dir}/churn.state`; each run appends only newer commits.

**Install.** `scripts/churn.py` is complete for any git repo regardless of language. Hook
it beside `snapshots` (same cadence). Needs full clone depth — in CI set
`fetch-depth: 0`.

**Broken means.** Artifact missing, or last record older than `freshness_days` while the
default branch has newer commits.

**Portability.** The script shells out to `git log --numstat`; it is already
language-independent. Non-Python environments can port it or run it as-is.
