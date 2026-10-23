# Module: labels (rung 7)

**Purpose.** Turn raw evidence into per-file outcome labels — the training targets a
future model needs and the ground truth reports can be checked against. This module is a
pure consumer: it derives, it never senses.

**Artifact.** `{artifacts_dir}/labels.jsonl`:

```json
{"as_of_sha": "3bc3de78", "as_of_ts": "2026-04-04T00:00:00Z", "file": "src/pkg/mod.py",
 "label": "bugfix_90d", "window_days": 90, "value": true,
 "evidence_type": "commit_trailer", "evidence_id": "e930e471"}
```

Every label row carries its evidence pointer — a label that cannot be audited back to a
commit/event is worthless (a real probe found unaudited grep labels at ~50% precision).

**Evidence sources, in precision order** (use all that exist, record each separately):
1. `Defect-Origin:` trailers — bug-introduction labels, the gold standard.
2. `fix:`-typed conventional commits touching ≤5 source files (the scope rule from
   git-commit-message is what makes this precise; never grep raw subjects for "fix").
3. `runtime_attr` fingerprints — defect evidence independent of commit hygiene.
4. `ci` failed_tests mapped to files (via coverage or naming convention).
5. Issue-tracker links (`Fixes: #N`) where type metadata exists.

**Windowing.** For each labeling point (default: each snapshot SHA), `bugfix_{W}d = true`
iff qualifying evidence touches the file within W days AFTER that SHA. Never let evidence
at-or-before the SHA satisfy a future window (leakage). Regenerating labels is allowed
(evidence is the durable record); regeneration must be deterministic.

**Cross-source audit.** When ≥2 evidence sources exist, emit an agreement summary (how
often trailer-labels and runtime-labels co-occur) into the report's Data Coverage section.
Disagreement is signal about label quality — surface it, don't average it away.

**Broken means.** Derivation exits nonzero, or labels reference evidence IDs that don't
exist. Not staleness-checked before enough history exists (labels need their windows to
close).
