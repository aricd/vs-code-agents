---
name: git-commit-message
description: Craft best-practice git commit messages AND keep git history usable as a measurement dataset for code-health analytics (hotspot analysis, defect prediction, churn attribution). ALWAYS apply this skill whenever committing code, crafting or reviewing commit messages, creating or describing PRs, staging changes, deciding how to split a batch of work into commits, performing file renames or moves, or wrapping up a plan/feature with mixed changes — even when the user just says "commit this", "push my changes", "wrap this up", or "write the commit message". Uses Conventional Commits by default; plain standard format on explicit request.
metadata:
  version: "2.0"
---

# Git Commit Message & History Hygiene

A commit is two things at once: a **permanent human-readable artifact** and a **row in a
dataset**. Future tooling will grep this history to answer: *Which files keep breaking? Did
that refactor reduce rework? Where is risk concentrating?* It reads commit **types**,
**file sets**, and **trailers** as signal — and a sloppy commit poisons those labels forever.
A real audit found commit-message-based bug labels had ~50% precision, and a single 27-file
commit titled "Plan 192: … cluster fixes" accounted for half of all file-level bug labels in
a 90-day window. These rules cost seconds at commit time and are unrecoverable if skipped.

Two mandates, chosen by what was asked:

- **Message crafting** ("write a commit message for…") — produce one message per request
  under the rules below. If you can read the staged diff, read it; if not, ask briefly for
  *what changed* and *why*. Never fabricate change details.
- **Committing work** ("commit this", "wrap up plan N") — full hygiene: split mixed work
  into atomic commits, isolate renames, attach trailers, then commit.

## Format Rules (every message, both formats)

1. Separate subject from body with a blank line.
2. Subject ≤50 characters (hard target; revise if exceeded).
3. Imperative mood ("Add feature", not "Added feature"); capitalize the first word of the
   description; no trailing period.
4. Body wrapped at 72 characters; explains **what and why**, not a file-by-file changelog.
5. References and trailers go in the footer (see Trailers below).

**Default format — Conventional Commits:** `<type>(<scope>): <Subject>` (scope optional).
Types drive changelogs, SemVer automation, and — critically — defect analytics. Use the
plain standard format (no type prefix) only when the user explicitly asks for it; the
vocabulary rules below still apply either way.

## Exclusions: no transient state in a permanent artifact

Do NOT include process or repository state that becomes false or meaningless once the
commit is pushed, merged, or rebased:

- **Push/locality status** — `Local-commit-only`, `not pushed`, `do not push`. A workflow
  rule like *"commit locally, don't push"* is an action directive to the committer — never
  transcribe it into the message.
- **Branch/PR mechanics** — "on branch X", "will squash later", "WIP until review".
- **Ephemeral agent/process chatter** — orchestration or review scaffolding notes.

**Keep** durable provenance that stays true forever: issue/requirement IDs (`Closes #123`,
`AXIS-3820`, `Refs: PLAN-026`) and dated approval/gate records (`UAT Approved: 2026-06-21`).
These describe what the change is and how it was vetted — not where the commit currently sits.

## Type semantics: `fix:` is a measurement, not a vibe

Analytics pipelines label "this file had a defect" by grepping for fix-like commits. That
only works if the type is used precisely. **The one-question test:** *Was there observably
wrong behavior before this change — something a user, test, or downstream system experienced
as broken?* Yes → `fix:`, and name the broken behavior in the subject. No → not a fix, no
matter how much it improves things.

| The change is... | Type | NOT |
|---|---|---|
| New user-facing capability | `feat:` | — |
| Repairing observably wrong behavior | `fix:` | — |
| Hardening/defensive/reliability work, no known defect | `refactor:` or `perf:` | `fix:` |
| Planned improvement work ("Plan NNN", tech-debt cleanup) | `refactor:` / `chore:` | "Plan NNN: fixes" |
| Repairing a broken test (production code unchanged) | `test:` | `fix:` |
| Docs, typos, comments | `docs:` | `fix:` |
| Formatting only, no behavior change | `style:` | — |
| CI/build config repair | `ci:` / `build:` | `fix:` |
| Restoring behavior a previous commit broke | `fix:` + `Defect-Origin:` trailer | `revert:` unless a literal revert |

Use only these standard types — never invent types (`harden:`, `improve:`). Prefer a
user-provided type; infer from described intent, not filenames; if genuinely ambiguous, ask
one clarifying question.

Keep fix-adjacent words (`fix`, `bug`, `broken`, `regression`, `repair`, `patch`) out of the
subjects of non-fix commits — in both formats. "refactor: Harden session teardown", not
"refactor: Fix up session teardown". Naive greps will run against this history.

## Scope: one concern per commit

File-level analytics attribute a commit's meaning to **every file it touches**. A commit
that fixes one bug and also reformats six other files just labeled six innocent files as
defective.

- One logical concern per commit; "and" in a subject line is a splitting signal.
- A `fix:` commit touches only the files involved in the defect — typically 1–5 source
  files plus their tests. A 10+ file "fix" is almost certainly bundled concerns.
- Separate unrelated test-only and doc-only changes. Tests written *for* a fix belong with
  the fix.
- Wrapping up mixed plan/feature work: split with `git add -p` / per-file staging:

```text
BAD  (one commit):  Plan 214: reliability fixes and cleanup        [27 files]

GOOD (four commits):
  fix(router): Dispatch drops params on retry paths     [2 files]  Refs: PLAN-214
  fix(session): Stale lock left after failed promote    [3 files]  Refs: PLAN-214
  refactor(soap): Extract row-cell parsing helpers      [6 files]  Refs: PLAN-214
  test: Consolidate session fixtures                    [9 files]  Refs: PLAN-214
```

Same work, same day — but history now says two real defects existed in five files, instead
of "27 files are buggy."

## Trailers: link commits to their evidence

Machine-parseable `Key: value` footers let future tooling join commits to issues, plans, and
defect origins without guesswork. Use them when the information exists — an absent trailer
is honest; a wrong one is not.

- `Fixes: #NNN` / `Closes: #NNN` — the issue this repairs or completes.
- `Refs: <id>` — the plan, epic, or ticket the work belongs to (context, not causation).
- `Defect-Origin: <sha>` — the commit that introduced the defect. For every `fix:` commit,
  spend the ten seconds to check `git blame`/`git log -L` on the repaired lines; if the
  introducing commit is identifiable, add this trailer. It is the single highest-value
  trailer for analytics — it makes rigorous bug-introduction (SZZ-style) analysis possible
  instead of forcing tools to guess.
- `BREAKING CHANGE: <what breaks and how to migrate>` — see below; always the **last** footer.

```text
fix(session): Stale lock left after failed promote

Promote failures returned early without releasing the session
lock, so the next request on the same session hung.

Fixes: #482
Refs: PLAN-214
Defect-Origin: 3bc3de78
```

## Breaking changes

Both markers, always: `!` after type/scope in the header (`feat(api)!:`) and a
`BREAKING CHANGE:` footer placed after all other footers so it is unmissable. Only when the
user confirms the change is breaking; describe user/API-visible impact plus minimal
migration guidance.

## Renames and moves: pure, in their own commit

Churn attribution breaks silently when a rename is combined with edits — git's rename
detection degrades below ~50% similarity and the file's history appears to end at the move.

- A rename/move commit contains only renames/moves (100% similarity), typed `refactor:`
  with a subject that says it's a move.
- Edit contents in a separate commit before or after the move.
- Isolate mass mechanical changes too (`style: Apply formatter — no logic change`) so they
  can be excluded from churn analysis.

## Snapshot cadence

If the repo has metric snapshot tooling (e.g. `make snapshot`), run it at every merge to the
default branch — or at minimum at every plan/feature completion — so snapshots tie to merge
SHAs. Retain machine-readable artifacts (coverage, metric JSON). Never rewrite published
history; it orphans the SHAs that snapshots and CI records point to.

## Worked example (conventional, breaking)

```text
feat(api)!: Switch responses from XML to JSON

Replace XML response serialization with JSON across all API
endpoints. JSON provides better tooling support and smaller
payload sizes.

Closes #123
BREAKING CHANGE: API responses are now JSON instead of XML.
All clients must update their response parsers.
```

## Pre-commit checklist

1. Type passes the one-question test; no fix-vocabulary in non-fix subjects; no invented types.
2. One concern (no "and" in subject; fix commits ≤5 source files or justified in the body).
3. Subject ≤50 chars, imperative, capitalized, no period; body wrapped at 72, says what + why.
4. No transient state (push status, branch mechanics, agent chatter).
5. Trailers where evidence exists (`Fixes:`, `Refs:`, `Defect-Origin:`); `BREAKING CHANGE:` last.
6. Renames pure and separate; mechanical changes isolated.
7. Landing on the default branch with snapshot tooling present? Run the snapshot.

When a user's request would violate these (e.g. "just commit everything as 'fixes'"), don't
silently comply or silently override: make the compliant split and note why in one sentence.
