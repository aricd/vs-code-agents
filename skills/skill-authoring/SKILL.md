---
name: skill-authoring
description: >-
  Rules, anti-patterns, and a validator for writing SKILL.md files that load and trigger
  correctly in Claude Code, VS Code, claude.ai uploads, and OpenAI: frontmatter and naming
  limits, strict YAML, the description budget, argument substitution, shell injection, and name
  collisions. Load when creating, reviewing, renaming, uploading, or troubleshooting a skill,
  including one that never triggers or fails to upload.
---

# Skill Authoring Skill

Authoritative guidance for authoring AI agent skills (reusable instruction sets), synthesized from official documentation by Anthropic (Claude Code, claude.ai, the Agent Skills API), Microsoft VS Code, OpenAI, and the [agentskills.io](https://agentskills.io) open standard. Recommendations are cited to source. **Observed** marks behavior seen on a real install rather than documented.

**The two failures that happen most and report least:** frontmatter that isn't strict YAML, and a description over 1,024 characters. Run the validator before shipping any skill.

## Validate First

`scripts/validate_skill.py`, in this skill's directory, checks one skill or a whole directory of skills against the rules each surface enforces:

```bash
python <this-skill-dir>/scripts/validate_skill.py <skill-dir-or-skills-dir> [--upload]
```

- Each finding names the surfaces it affects. `ERROR` means it breaks loading, triggering or upload there. `WARN` means it works but degrades or surprises.
- `--upload` turns non-spec frontmatter keys into errors. Use it before a claude.ai or Skills API upload.
- On a directory it also prints the total listing text, which is what Claude Code budgets against.
- It exits 1 on any ERROR. The strict YAML check needs PyYAML and reports when it is missing.

Then confirm loading in a fresh Claude Code session: see "Verifying that a skill loads" in [references/claude-code.md](references/claude-code.md).

---

## Universal Rules (the Portable Contract)

A skill in this repo is read by VS Code and Claude Code and may be uploaded to claude.ai, so write to the strictest rule among them. Claude Code is the most lenient loader and rarely reports anything. A skill can look fine there and still be broken everywhere else: lenient means **silent**, not correct.

### 1. File Shape

- The entrypoint is `SKILL.md`: YAML frontmatter, then a Markdown body.
- **`---` must be line 1.** A UTF-8 BOM, blank line or comment before it makes Claude Code treat the whole file, markers included, as content: no name, no description. (Anthropic)
- **Frontmatter must be strict YAML.** The usual break is a single-line `description` containing `: ` or ` #`. Write long descriptions as a folded block: `description: >-` followed by indented lines. Strict parsers (Agent Skills validators, claude.ai upload) reject invalid YAML outright. Where Claude Code's parser also rejects it, the skill loads with **empty metadata**: it stays in the `/` menu but never auto-triggers, and only `--debug` says why. (Anthropic)
- **The directory name equals `name`.** The spec, VS Code and claude.ai uploads require it. Claude Code tolerates a mismatch (both names invoke the skill), so it won't catch this for you.

### 2. Naming Rules (CRITICAL -- Silent Failures)

| Rule | Enforced by | Failure mode |
|------|-------------|--------------|
| 1-64 chars of `a-z`, `0-9` and single hyphens; no leading or trailing hyphen | Spec, VS Code, claude.ai/API | VS Code skips silently; upload rejected |
| Equals the directory name | Spec, VS Code, claude.ai | VS Code: not loaded |
| No namespace prefix, slash, colon, dot, space or uppercase | All | Silent skip (VS Code); upload rejected |
| Does not contain `anthropic` or `claude` | claude.ai, Skills API | Upload rejected |
| Not `synced` (any case) | Claude Code | Skipped; the name is reserved for skills synced from claude.ai |
| Not the name of a bundled Claude Code skill (e.g. `code-review`, `simplify`, `debug`, `loop`) | Claude Code | **Your skill silently replaces the built-in command** |

**Anti-pattern names**: `My_Skill` (underscore, uppercase), `myorg/analysis` (namespace prefix), `my.skill.name` (dots), `My Skill` (space), `claude-helper` (reserved word), `pdf--tools` (double hyphen).

The bundled set changes between Claude Code versions. A name listed twice in a fresh session's skill list is a collision; see [references/claude-code.md](references/claude-code.md).

### 3. Description is the Routing Signal

The model decides whether to load a skill from its description alone.

- **The hard limit is 1,024 characters** (spec, VS Code, claude.ai, Skills API). Claude Code's 1,536-character listing cap (description plus `when_to_use`) is where it truncates, **not** an allowance. A 1,500-character description works in Claude Code and fails everywhere else.
- **Write in third person** ("Generates reports from..."), never "I can..." or "You can use this...". The description is injected into the system prompt. (Anthropic)
- **Put the key use case and trigger phrases first.** Truncation cuts the end.
- **No XML tags.** A placeholder like `<ID>` counts. (claude.ai, Skills API)
- **It spends a shared budget.** Claude Code fits every installed skill's description into about 1% of the context window. When that overflows, it drops the descriptions of the least-used skills first, removing the keywords that would have triggered them. A long description therefore taxes every other skill. Aim for a few hundred characters and move detail into the body. (Anthropic)

### 4. Frontmatter Keys: Portable vs Surface-Specific

| Keys | Where they work |
|------|-----------------|
| `name`, `description`, `license`, `compatibility` (<=500 chars), `metadata` (string-to-string map), `allowed-tools` | Everywhere: the Agent Skills spec's six |
| `argument-hint`, `user-invocable`, `disable-model-invocation`, `context` | Claude Code and VS Code |
| `when_to_use`, `arguments`, `model`, `effort`, `agent`, `hooks`, `paths`, `shell` | Claude Code only |

- Any key outside the six makes a claude.ai upload, the Skills API or `package_skill.py` **fail with a hard error**. (Anthropic) Use surface-specific keys only in skills that are never uploaded, or strip them from the upload copy.
- Claude Code **ignores an unrecognized key without any error**, so a typo like `allowed_tools` simply does nothing. (Anthropic)
- `allowed-tools` **grants** permission-free use during the invoking turn. It never restricts.

### 5. Body Text Is Live in Claude Code

Claude Code preprocesses the rendered `SKILL.md`, but not supporting files, before the model sees it:

- **Argument placeholders are substituted** when the skill is invoked with arguments: a dollar sign followed by a digit, by `ARGUMENTS`, or by a name declared in `arguments`. The usual victims are shell snippets (a bash function's positional parameters, a usage line printing the script name, awk fields) and prices. Escape each with a single backslash, or move the snippet into a supporting file.
- **Inline shell injection runs at load time.** That is an exclamation mark immediately followed by a backtick-quoted command, at the start of a line or after whitespace, and also a fenced block opened with three backticks plus an exclamation mark. Never write that pattern in prose or examples; document it in a supporting file instead.
- **Paths**: name bundled files relative to the skill directory, and say that they are. An agent runs a bare `scripts/x.sh` against the session's working directory, which is the user's project. Claude Code has a skill-directory variable for injected commands and `allowed-tools`, but VS Code shows it literally, so keep it out of portable skills.

For exact token forms, escaping and examples, see "String substitutions" and "Dynamic context injection" in [references/claude-code.md](references/claude-code.md).

### 6. Progressive Loading, and What Survives Compaction

Skills load in stages on every vendor:
1. **Discovery**: only `name` and `description` are in context
2. **Instructions**: the `SKILL.md` body, when invoked
3. **Resources**: supporting files, when referenced

Design accordingly:
- Keep `SKILL.md` under 500 lines. Move detail to `references/`, linked **one level deep** from `SKILL.md`. Give reference files over 100 lines a table of contents, and use forward slashes in paths. (Anthropic, agentskills.io)
- Claude Code inserts the body **once** per invocation and never re-reads it, so write **standing** instructions ("run the tests after every edit"), not one-time steps. (Anthropic)
- After auto-compaction, Claude Code keeps only the **first 5,000 tokens** of each invoked skill (25,000 across all of them), so put non-negotiable rules **at the top**. A rule that must hold every time belongs in a hook. (Anthropic)

### 7. Treat Skills as Privileged Code

Skills inject instructions directly into the model's context, and in Claude Code they can run shell commands at load. Review them before installing, especially from external sources. (OpenAI explicit warning; applies to all vendors)

---

## Vendor-Specific Guidance

### Microsoft / VS Code

**Source**: [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)

#### File Layout
```
skills/
└── my-skill/
    ├── SKILL.md           # Required: skill definition
    ├── references/        # Optional: detailed docs
    │   └── guide.md
    └── scripts/           # Optional: automation
        └── check.sh
```

#### YAML Frontmatter Schema

| Field | Required | Notes |
|-------|----------|-------|
| `name` | **Yes** | kebab-case, <=64 chars, **must match directory name** |
| `description` | **Yes** | <=1024 chars; routing signal |
| `argument-hint` | No | Slash-command hint |
| `user-invocable` | No (default `true`) | `false` = hidden from `/` menu |
| `disable-model-invocation` | No (default `false`) | `true` = manual-only |
| `context` (Experimental) | No (default `inline`) | `fork` runs in dedicated subagent |

#### Extension Contribution
For VS Code extension contributions, register via `chatSkills` contribution point in `package.json`:
```json
{
  "contributes": {
    "chatSkills": [
      { "path": "skills/my-skill/SKILL.md" }
    ]
  }
}
```

#### Best Practices
- Keep `SKILL.md` under 500 lines; move detailed reference material to separate files loaded on demand. (Anthropic, applies to VS Code)
- Reference supporting files explicitly so the agent knows what each contains. (Microsoft, Anthropic)
- Use `context: fork` for skills that read many files / produce a focused result that doesn't need to influence the parent agent. (Microsoft)

### Anthropic / Claude Code

**Source**: [Claude Code Skills](https://code.claude.com/docs/en/skills). Full detail, including every frontmatter field, substitution and lifecycle rule, is in [references/claude-code.md](references/claude-code.md).

- **Locations**: personal `~/.claude/skills/<name>/`, project `.claude/skills/<name>/`, enterprise, and plugin (namespaced `plugin:skill`). On a name clash: enterprise beats personal beats project; any of them beats a bundled skill, silently; a skill beats a `.claude/commands/` file. A `<name>` entry may be a symlink. Personal skills don't load in Cowork, cloud sessions or routines. (Anthropic)
- **Invocation control**: use `disable-model-invocation: true` for side-effecting workflows (deploy, commit, send-message); its description then leaves the listing. Use `user-invocable: false` for background knowledge that isn't a command. (Anthropic)
- **Listing budget levers**: the `skillListingBudgetFraction` setting, `skillOverrides` (`name-only`, `off`), and `/doctor` and `/skill-doctor` to measure. (Anthropic)
- **Subagents** preload skills through their `skills:` field. A subagent with an explicit `tools:` list can invoke skills only if `Skill` is in that list. (Anthropic)
- **Dynamic context**: phrase injected command output as factual statements, not imperative instructions, to avoid prompt-injection defenses. (Anthropic)
- **Synced skills**: Claude Code 2.1.273+ downloads claude.ai account skills into `~/.claude/skills/synced/`. If `~/.claude/skills` is itself a link into a repo, that download lands in the repo. Either link skills per item or set `syncClaudeAiSkills: false`. (Anthropic)

### claude.ai Uploads and the Skills API

**Sources**: [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview), [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

- Zip the **skill folder** at the zip root (`my-skill.zip` contains `my-skill/SKILL.md`). The folder name equals `name`.
- Frontmatter is limited to the spec's six keys. `description` is at most 1,024 chars with no XML tags; `name` must not contain `anthropic` or `claude`.
- Validate with `--upload` first. A link to `../other-skill/` breaks once the skill is uploaded alone.
- Uploads don't sync between claude.ai, the Skills API and Claude Code. The one exception is Claude Code's download-only sync, above. (Anthropic)

### OpenAI / Hosted Shell Skills

**Source**: [OpenAI Tools & Skills](https://developers.openai.com/api/docs/guides/tools-skills)

OpenAI supports skills via the [agentskills.io](https://agentskills.io) standard, delivered as **uploaded bundles**.

#### Delivery Format
- Directory or zip containing `SKILL.md` + supporting files
- Max 50 MB zip / 500 files / 25 MB uncompressed
- `SKILL.md` matching is case-insensitive; exactly one allowed

#### Mounting
Skills are mounted via `tools[].environment.skills` on the hosted shell tool:
```json
{
  "tools": [{
    "type": "hosted_shell",
    "environment": {
      "skills": [
        { "type": "skill_reference", "skill_id": "...", "version": "..." }
      ]
    }
  }]
}
```

Or inlined as base64-encoded zip.

#### Versioning
Skills are versioned via the API with `default_version` and `latest_version` fields.

#### Security Warning
> "Treat Skills as privileged code and instructions -- review before installing; do not expose open Skills repos to end-users." (OpenAI)

**GAP**: OpenAI has no documented lifecycle hooks equivalent to Claude Code or VS Code.

---

## Anti-Patterns Checklist

❌ **Do NOT** write a description over 1,024 characters. Uploads reject it and it violates the spec and VS Code's limit; Claude Code merely truncates, which hides the problem. (Anthropic, agentskills.io)

❌ **Do NOT** leave `: ` or ` #` inside a single-line, unquoted description. It is invalid YAML; fold it with `>-`. (YAML; Anthropic)

❌ **Do NOT** put anything before the opening `---` (BOM, blank line, comment). Claude Code then reads no frontmatter at all. (Anthropic)

❌ **Do NOT** use namespace prefixes in `name` (`myorg/skill`, `myorg:skill`). The skill silently fails to load. (Microsoft explicit, Anthropic marketplace validator)

❌ **Do NOT** mismatch the directory name and the `name` field. The skill isn't loaded in VS Code, and Claude Code won't warn you. (Microsoft, agentskills.io)

❌ **Do NOT** use invalid characters (uppercase, slashes, colons, dots, spaces, double hyphens). The skill is silently skipped. (Microsoft, agentskills.io)

❌ **Do NOT** reuse the name of a bundled Claude Code skill. Yours silently replaces the built-in. (Anthropic)

❌ **Do NOT** use surface-specific frontmatter keys in a skill you upload. The upload fails with a hard error. (Anthropic)

❌ **Do NOT** rely on Claude Code to catch a misspelled field name. It ignores unknown keys silently; run the validator. (Anthropic)

❌ **Do NOT** leave literal argument placeholders or the inline shell-injection pattern in `SKILL.md` prose or examples. Claude Code substitutes or executes them. (Anthropic)

❌ **Do NOT** reference bundled scripts by a cwd-relative path (`./scripts/x.sh`). It resolves against the user's project, not the skill.

❌ **Do NOT** bury non-negotiable rules at the bottom of a long `SKILL.md`. Compaction keeps only the first 5,000 tokens. (Anthropic)

❌ **Do NOT** load large reference material directly in `SKILL.md`. It wastes context; use linked supporting files. (Anthropic, Microsoft)

❌ **Do NOT** phrase bash output as imperative system instructions. That triggers prompt-injection defenses; use factual statements. (Anthropic)

❌ **Do NOT** set `version` in both `plugin.json` and a marketplace entry. `plugin.json` silently wins, which can mask the intended version. (Anthropic)

❌ **Do NOT** distribute skills through an open user-facing marketplace. It opens a prompt-injection and data-exfiltration attack surface. (OpenAI explicit warning)

❌ **Do NOT** expect stale `additionalContext` from hooks to update on `--continue`/`--resume`. The saved text replays rather than re-runs. (Anthropic)

---

## New Skill Gate (Rung-2 Justification Required)

Before creating a new skill directory, you MUST pass this gate. It implements **lean-design rung 2** ("does an existing seam already cover this?") as an explicit checklist. `lean-design` owns the authoritative rung-ladder; this gate is its enforcement point for skill authoring.

**Required justification** (answer all four before creating `skills/<new-name>/`):

1. **Existing skill scan**: List every skill in `skills/` whose description overlaps with the proposed new skill. For each match, explain why the proposed capability does NOT belong in that skill's body or `references/` directory.
2. **Seam-widening check**: Could the need be satisfied by adding a new section or reference file to an existing skill? If yes, do that instead. If no, state why the new content is orthogonal enough to warrant a separate skill.
3. **Trigger independence**: Does the new skill have a genuinely distinct set of trigger conditions from all existing skills? A skill with triggers that are a strict subset of an existing skill's description is a shallow module — fold it in.
4. **Interface cost**: Estimate the new skill's interface surface (description keywords + load triggers). If it does not add a meaningfully different routing surface, it is a rung-1 candidate ("does it need to exist at all?"). In Claude Code that surface is also a recurring cost: every description shares one listing budget (Universal Rule 3).

**Gate outcome**: If you cannot answer all four with clear justification, do NOT create the new directory. Widen an existing seam instead.

> **Owner**: lean-design skill (rung 2 — "does an existing seam cover this?"). See `skills/lean-design/SKILL.md` for the full rung-ladder and lean guardrails.

---

## Repo-Local Convention (this repository)

> This is a project convention, not part of the official VS Code / agentskills.io schema.

**Write to the portable contract.** Skills here reach VS Code through `~/.agents/skills` and Claude Code through `~/.claude/skills`, and some are uploaded to claude.ai. Run `scripts/validate_skill.py` (this skill's directory) over any skill you add or change, and over the whole `skills/` directory when descriptions grow, because they share one listing budget.

**Minimal frontmatter.** Skills in this repo use only the vendor-defined fields (`name`, `description`, and the optional vendor fields above). When a `metadata` block is added, it carries at most `version` and optionally `author` -- no other sub-keys -- with quoted string values. The top-level `license` field may also be retained.

**No in-file changelogs.** Change history belongs in `CHANGELOG.md` (the repo root), not in a `changelog` field inside the skill. A frontmatter `changelog` creates two sources of truth that diverge over time. Record skill changes in the top-level `CHANGELOG.md` under the plan number that introduced them.

**Staged skills and cross-skill references.** A skill whose work runs in ordered stages follows one shape:

1. A staged skill is a hub `SKILL.md` plus one `references/NN-<stage>.md` file per stage, numbered in run order.
2. The hub indexes **every file a run reads**, one hop away, including files that live in other skills, each with a one-line "read when". A file a stage tells the agent to read that is missing from the index is a defect.
3. Must-hold rules stay in the hub, not in a stage file, so they survive when only the hub is loaded.
4. A link into another skill points into the skill that **owns the concept**, never into a shared folder. The owner stays the single place the concept is stated; the linking skill does not restate it.
5. A stage file becomes "shared" only once a second skill links to it. From then on, renaming it or changing the payload it receives is a breaking change for both skills, and the hub index lists the link.
6. A workflow that other skills must link to is written as a skill, not as a prompt. This is a deployment-policy limit, not a structural one: the whole-tree link deploys only `skills/` (`LINKING.md:19`), prompts have "no confirmed system-level location today" (`LINKING.md:44`), and per-workspace prompt linking is available only as an opt-in fallback (`LINKING.md:144-152`). A relative link from a skill to a prompt therefore does not resolve under the default deployment.

---

## Worked Examples

See [references/worked-examples.md](references/worked-examples.md):

1. **Methodology/checklist skill**: a keyword-rich description and structured sections
2. **Reference-heavy skill**: a concise `SKILL.md` with one-level-deep supporting files
3. **Scripted skill**: anchoring script paths to the skill directory, not the user's project
4. **Lifecycle skill**: a Claude Code/VS Code-only field, and what it costs on upload
5. **Repairing frontmatter that silently fails**: invalid YAML and an over-long description, before and after

---

## Cross-References

- Claude Code behavior in full (fields, substitutions, injection, lifecycle, listing budget, verification): [references/claude-code.md](references/claude-code.md)
- For agent authoring guidance, see `skills/agent-authoring/SKILL.md`
- For hook authoring guidance, see `skills/hook-authoring/SKILL.md`
- **agentskills.io standard**: https://agentskills.io/specification (cross-vendor skill format)

---

## Source Bibliography

- Anthropic, Claude Code: https://code.claude.com/docs/en/skills (accessed 2026-10-14)
- Anthropic, Agent Skills overview and best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview, https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (accessed 2026-10-14)
- Open standard: https://agentskills.io/specification (accessed 2026-10-14)
- Anthropic Help Center, creating custom skills: https://support.claude.com/en/articles/12512198-creating-custom-skills (accessed 2026-10-14; its 200-character description limit conflicts with the platform docs and with observed uploads, so the 1,024 limit above governs)
- Microsoft: https://code.visualstudio.com/docs/copilot/customization/agent-skills (accessed 2026-05-01)
- OpenAI: https://developers.openai.com/api/docs/guides/tools-skills (accessed 2026-05-01)
