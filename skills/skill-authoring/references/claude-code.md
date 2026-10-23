# Claude Code Skill Behavior -- Reference

Detail behind the Claude Code rules in `SKILL.md`. Sourced from https://code.claude.com/docs/en/skills (accessed 2026-10-14) unless marked **Observed**, which means seen on Claude Code 2.1.226 on Windows.

This file is a supporting file, so Claude Code does not preprocess it. The literal placeholder and shell-injection examples below are safe here. They would be live in a `SKILL.md`.

## Contents

- Where skills load from, and which one wins
- Frontmatter fields
- Parsing rules and silent failures
- Who can invoke a skill
- String substitutions and escaping
- Dynamic context injection
- Content lifecycle and compaction
- The skill listing budget
- Skills and subagents
- Using a skill outside Claude Code (claude.ai, Skills API)
- Verifying that a skill loads

---

## Where skills load from, and which one wins

| Location | Path | Applies to |
|---|---|---|
| Enterprise | `.claude/skills/<name>/SKILL.md` in the managed settings directory | All users |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects on this machine, but not Cowork or cloud sessions |
| Project | `.claude/skills/<name>/SKILL.md` | That project |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where the plugin is enabled; namespaced `/plugin-name:skill-name` |

**Name collisions:**

| Collision | Winner |
|---|---|
| Two of enterprise, personal, project | Enterprise over personal over project |
| Any of those and a **bundled** skill | **Your skill replaces the bundled command** (not its aliases), silently |
| A skill and a `.claude/commands/<name>.md` file | The skill |
| A plugin skill and any of the above | Both load (the plugin one is namespaced) |
| A local skill and a skill synced from claude.ai | `/name` runs the local one; the synced one runs only as `/anthropic-skills:name` |

**Observed:** a personal skill named `code-review` appears twice in the session's `skills` list, next to the bundled `code-review`, but `slash_commands` has only one `/code-review`. Per the table above, that one is the personal skill.

**Discovery details:**

- Project skills load from `.claude/skills/` in the start directory and every parent up to the repo root. A `.claude/skills/` *below* the start directory loads the first time Claude reads or edits a file in that subdirectory.
- Claude Code watches skill directories, so edits apply mid-session. A top-level skills directory created after the session started needs `/reload-skills`.
- A `<name>` entry may be a symlink to a directory elsewhere. **Observed:** `~/.claude/skills` itself can be a Windows junction, and all 46 skills behind it load.
- `synced/` is reserved. Claude Code 2.1.273+ downloads your claude.ai account skills into `~/.claude/skills/synced/` in signed-in terminal sessions, and moves removed ones to `~/.claude/skills/.trash/`. If `~/.claude/skills` is a link into a repo, those folders land **in the repo**. Set `syncClaudeAiSkills: false`, or link skills per item, to prevent that.
- Cowork, cloud sessions and routines don't read `~/.claude/skills/`. Desktop scheduled tasks do.

## Frontmatter fields

Claude Code ignores a field it doesn't recognize **without reporting an error**, so a typo such as `allowed_tools` simply does nothing. Booleans accept `true/false/yes/no/on/off/1/0` (2.1.218+).

| Field | Portable? | Meaning in Claude Code |
|---|---|---|
| `name` | Spec | Command name in the `/` menu. Defaults to the directory name, which also invokes the skill |
| `description` | Spec | Routing signal. Falls back to the first non-empty body line if absent |
| `license`, `compatibility` (<=500 chars), `metadata` (map) | Spec | Accepted, not acted on. A `metadata` value that isn't a map is dropped |
| `allowed-tools` | Spec (experimental) | Tools usable **without asking** during the invoking turn. It grants, it doesn't restrict, and the grant clears on your next message |
| `when_to_use` | Claude Code only | Appended to `description` in the listing; counts toward the 1,536-char cap |
| `argument-hint` | Claude Code, VS Code | Autocomplete hint, e.g. `[issue-number]` |
| `arguments` | Claude Code only | Names for positional arguments (`$issue`, `$branch`) |
| `disable-model-invocation` | Claude Code, VS Code | `true` = manual `/name` only; description leaves the listing |
| `user-invocable` | Claude Code, VS Code | `false` = hidden from `/` menu; Claude can still invoke |
| `model`, `effort` | Claude Code only | Override for the invoking turn |
| `context: fork`, `agent` | Claude Code (VS Code: `context`) | Run in a forked subagent of type `agent` |
| `hooks` | Claude Code only | Skill-scoped lifecycle hooks, active from invocation to session end |
| `paths` | Claude Code only | Glob patterns; auto-load only when working with matching files |
| `shell` | Claude Code only | `bash` (default) or `powershell` for injected commands |

"Spec" means the Agent Skills spec's six fields. Every other field makes a claude.ai upload, the Skills API, or `package_skill.py` **fail with a hard error**.

## Parsing rules and silent failures

| Mistake | What Claude Code does |
|---|---|
| Line 1 is not `---` (BOM, blank line, comment) | Treats the whole file, markers included, as content. No name, no description |
| YAML between the markers doesn't parse | Loads the skill with **empty metadata**. `/name` still works, but Claude can't match the description, so it never auto-triggers. `--debug` shows the parse error |
| Unknown field name | Ignored, no error |

The commonest YAML break is a plain-scalar description containing `: ` or ` #`:

```yaml
description: Routes between three branches: a runnable app...   # invalid in strict YAML
description: >-
  Routes between three branches: a runnable app...             # valid
```

**Observed:** Claude Code 2.1.226 logged no parse error for exactly that invalid line, so its parser is laxer than strict YAML. The Agent Skills validators, PyYAML, and claude.ai's uploader are not, so fix it regardless.

`claude plugin validate ~/.claude/skills` (2.1.233+) finds frontmatter that doesn't parse.

## Who can invoke a skill

| Frontmatter | You (`/name`) | Claude | Listing |
|---|---|---|---|
| (default) | Yes | Yes | Description always in context |
| `disable-model-invocation: true` | Yes | No | Description **not** in context |
| `user-invocable: false` | No | Yes | Description always in context |

Use `disable-model-invocation: true` for side-effecting workflows (deploy, commit, send). Use `user-invocable: false` for background knowledge that isn't a command.

## String substitutions and escaping

These are substituted in the rendered `SKILL.md` content:

| Token | Becomes |
|---|---|
| `$ARGUMENTS` | All arguments. If no placeholder receives an argument, Claude Code appends `ARGUMENTS: <value>` instead |
| `$ARGUMENTS[N]`, `$N` | Argument N (0-based): `$0` is the first |
| `$name` | Named argument from `arguments:` |
| `${CLAUDE_SKILL_DIR}` | This skill's directory. Use it for bundled scripts in injected commands and `allowed-tools` |
| `${CLAUDE_PROJECT_DIR}` | Project root |
| `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}` | Session ID, effort level |
| `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` | Plugin skills only |

An indexed placeholder with no matching argument stays literal, so this text is safe until someone passes arguments. Then the usual victims break: shell functions (`local pattern="$1"`), `echo "Usage: $0"`, awk `'{print $1}'`, and prices like `$1,284.50`.

**Escape** a literal `$` before a digit, `ARGUMENTS` or a declared name with one backslash: `\$1.00` renders as `$1.00`. VS Code and claude.ai show the backslash, so prefer moving such snippets into a supporting file, which is never substituted.

## Dynamic context injection

`` !`command` `` runs `command` **before** the content is sent to Claude, and its output replaces the placeholder:

```markdown
- PR diff: !`gh pr diff`
```

A fenced block opened with ` ```! ` runs as a multi-line command. Use the `shell: powershell` field for PowerShell.

- The inline form fires only when `!` is at the start of a line or after whitespace. `` KEY=!`cmd` `` stays literal. Any prose or example in `SKILL.md` that puts a space before an exclamation mark and a backtick **will execute**. Keep such examples in supporting files.
- Reference bundled scripts with `${CLAUDE_SKILL_DIR}/scripts/x.sh`. A bare `scripts/x.sh` runs relative to the session's working directory, not the skill.
- Phrase command output as facts ("Current branch: main"), not imperatives.
- `"disableSkillShellExecution": true` (best in managed settings) replaces each command with `[shell command execution disabled by policy]`. Bundled and managed skills are unaffected.

## Content lifecycle and compaction

- On invocation, the rendered `SKILL.md` enters the conversation **once** and stays. Claude Code never re-reads the file on later turns. Re-invoking with identical rendered content adds only a short "already loaded" note.
- After auto-compaction, Claude Code re-attaches the most recent invocation of each skill but keeps **only its first 5,000 tokens**. All re-attached skills share **25,000 tokens**, filled newest first, so older skills can drop out entirely.

Design consequences:

1. Put non-negotiable rules **at the top** of `SKILL.md`.
2. Write standing instructions ("run the tests after every edit"), not one-time steps.
3. A rule that must hold every time belongs in a hook. A skill's `hooks` field keeps it with the skill.

## The skill listing budget

Every skill's name is always listed. Descriptions share a character budget of **1% of the model's context window**. When the listing overflows, Claude Code drops descriptions starting with the **least-invoked** skills, removing exactly the keywords that would have triggered them. Each entry is also capped at 1,536 characters (`skillListingMaxDescChars`).

- Measure: `/doctor` estimates the listing cost, `/context` shows the Skills row after budgeting, and `/skill-doctor` (2.1.252+) shows cost and usage per skill.
- **Observed** debug-log warning (abridged): `Skill listing over budget: 60 skills, 34293 chars > 30000 budget -- descriptions will be truncated.`
- Levers: `skillListingBudgetFraction` (e.g. `0.02`), `SLASH_COMMAND_TOOL_CHAR_BUDGET` (fixed chars), `skillOverrides` per skill (`on` / `name-only` / `user-invocable-only` / `off`), or shorter descriptions at the source.

A long description is a tax on every other skill in the user's setup. That is the reason to stay well under 1,024, not merely under it.

## Skills and subagents

- A subagent's `skills:` field preloads the full content of up to 32 skills. A skill with `disable-model-invocation: true` can't be preloaded.
- A subagent with an explicit `tools:` allowlist can invoke skills only if `Skill` is in the list.
- `context: fork` in a skill runs the skill itself in a subagent, chosen with `agent:`.

## Using a skill outside Claude Code (claude.ai, Skills API)

- Frontmatter: only `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Anything else is a hard error.
- `name`: <=64 chars, lowercase/digits/hyphens, no XML tags, must not contain `anthropic` or `claude`. `description`: non-empty, <=1,024 chars, no XML tags (`<ID>` counts).
- claude.ai zip: the **skill folder** at the zip root (`my-skill.zip` -> `my-skill/SKILL.md`), folder name = `name`.
- The Help Center article quotes a 200-char description limit. **Observed:** claude.ai accepts and serves 1,016-char descriptions, so 1,024 is the working limit.
- A `../other-skill/` link resolves only where sibling skills are installed too. An uploaded skill stands alone.

## Verifying that a skill loads

1. Run `scripts/validate_skill.py` from this skill on the skill, or on the whole skills directory, which also reports the listing size. Add `--upload` before a claude.ai upload.
2. In a **fresh** session from a neutral directory:

   ```bash
   claude -p "ok" --output-format stream-json --verbose --debug
   ```

   - The first line (`"subtype":"init"`) lists `skills`, `agents` and `slash_commands`. Check each name is present. **A name listed twice in `skills` is a collision**: your skill is shadowing a bundled one.
   - The debug log (`~/.claude/debug/<session_id>.txt`) has `Loaded N unique skills (... user: N ...)`, any parse errors, and the over-budget warning.
   - **Observed:** loading completes, and `init` is emitted, even when the model call then fails authentication, so this check works without a usable login.
3. Behavior: ask "What skills are available?", then give a prompt that should trigger the skill without naming it. Invoke `/name` directly to separate "doesn't load" from "doesn't trigger".
