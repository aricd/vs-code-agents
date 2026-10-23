# Skill Authoring -- Worked Examples

Five examples, each followed by why it works. They are written to the portable contract in `SKILL.md` unless noted.

## Contents

- Example 1: Methodology/checklist skill
- Example 2: Reference-heavy skill with supporting files
- Example 3: Scripted/automation skill (script paths)
- Example 4: Lifecycle/process skill (Claude Code/VS Code-only field)
- Example 5: Repairing frontmatter that silently fails

---

## Example 1: Methodology/Checklist Skill

A skill that provides structured investigation methodology with confidence levels.

**Directory**: `skills/investigation-methodology/`

```markdown
---
name: investigation-methodology
description: A systematic approach to converting unknowns to knowns through structured investigation. Provides confidence levels, gap tracking, investigation techniques, and handoff protocols for analysis work. Load when conducting technical research, root cause analysis, or any investigation with uncertain outcomes.
---

# Investigation Methodology

This skill provides a structured framework for technical investigation.

## Confidence Levels

Label all findings with confidence:
- **Verified**: Directly observed, reproduced, or confirmed by authoritative source
- **High-confidence inference**: Strongly supported by evidence but not directly proven
- **Hypothesis (High/Med/Low)**: Plausible explanation requiring validation

## Gap Tracking

For each unknown, capture:
- What we need to know
- Why it matters
- Fastest path to resolution
- Fallback if unresolvable

## Investigation Techniques

1. **Evidence-first**: Gather data before forming hypotheses
2. **Disconfirmation**: Actively seek evidence against your hypothesis
3. **Timebox**: Set explicit limits on investigation depth

## Handoff Protocol

When investigation is complete or blocked:
1. Document verified facts
2. List remaining hypotheses with confidence levels
3. Specify what evidence would resolve remaining uncertainty
```

**Why this works**:
- Clear, keyword-rich, third-person description with trigger conditions, well under 1,024 chars, and no `: ` inside the plain scalar
- Structured sections the model can reference
- Actionable framework, not just theory
- Supports partial invocation (just the confidence levels section)

---

## Example 2: Reference-Heavy Skill with Supporting Files

A security patterns skill that keeps the main file concise and delegates details to references.

**Directory structure**:
```
skills/security-patterns/
├── SKILL.md
├── references/
│   ├── security-methodology.md
│   ├── python-vulnerabilities.md
│   ├── javascript-vulnerabilities.md
│   └── java-vulnerabilities.md
└── scripts/
    └── check-dependencies.sh
```

**SKILL.md**:
```markdown
---
name: security-patterns
description: Security vulnerability detection patterns including OWASP Top 10, language-specific vulnerabilities, and remediation guidance. Load when reviewing code for security issues, conducting audits, or implementing authentication/authorization.
---

# Security Patterns

Paths below are relative to this skill's directory.

## Quick Reference

- **Methodology**: See [references/security-methodology.md](references/security-methodology.md)
- **Python vulnerabilities**: See [references/python-vulnerabilities.md](references/python-vulnerabilities.md)
- **JavaScript vulnerabilities**: See [references/javascript-vulnerabilities.md](references/javascript-vulnerabilities.md)
- **Java vulnerabilities**: See [references/java-vulnerabilities.md](references/java-vulnerabilities.md)

## Review Process

1. Identify the technology stack
2. Load relevant language-specific reference
3. Check for OWASP Top 10 patterns
4. Run `scripts/check-dependencies.sh` (in this skill's directory) if package files are present

## Severity Ratings

| Level | Definition | Response |
|-------|------------|----------|
| Critical | Exploitable, severe impact | Block release |
| High | Exploitable, significant impact | Fix before release |
| Medium | Requires specific conditions | Fix in next sprint |
| Low | Theoretical or minor impact | Track in backlog |
```

**Why this works**:
- Main file is concise (~50 lines)
- Supporting files loaded only when needed, one level deep from `SKILL.md`
- Clear links tell the model what each reference contains
- States that paths are relative to the skill directory, so the script is not looked up in the user's project

---

## Example 3: Scripted/Automation Skill (script paths)

A skill that includes executable automation scripts.

**Directory**: `skills/release-procedures/`

```markdown
---
name: release-procedures
description: Version management, release verification, and deployment procedures. Includes semver guidance, version consistency checks, and platform-specific constraints. Load when preparing releases, bumping versions, or validating release readiness.
---

# Release Procedures

Scripts live in this skill's `scripts/` directory -- not in the project being released.

## Version Bump Checklist

Before any release:
1. Run the version consistency check: `bash <this-skill-dir>/scripts/check-versions.sh`
2. Verify CHANGELOG entry exists for this version
3. Confirm all tests pass
4. Review breaking changes

## Semver Rules

- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

## Scripts

- `scripts/check-versions.sh` -- validates that versions agree across package.json, plugin.json, CHANGELOG.md
- `scripts/validate-release.sh v1.2.3` -- pre-release validation for one version

## Platform Constraints

### VS Code Plugins
- Version must be valid semver
- `plugin.json` version is authoritative
- Cache invalidation may require version bump

### npm Packages
- Cannot republish same version
- Use prerelease tags for testing: `1.2.3-beta.1`
```

**Why this works**:
- Actionable procedures with bundled scripts
- **Script paths are anchored to the skill directory.** The previous version said `./scripts/check-versions.sh`, which an agent runs against the session's working directory, i.e. the user's project, where no such script exists.
- In a **Claude Code-only** skill, write the anchor as `${CLAUDE_SKILL_DIR}/scripts/check-versions.sh`. Claude Code substitutes the real path, but VS Code shows that text literally, so don't use it in a portable skill.
- Platform-specific sections for different contexts

---

## Example 4: Lifecycle/Process Skill (Claude Code/VS Code-only field)

A skill that manages document lifecycle and workflow state.

**Directory**: `skills/document-lifecycle/`

```markdown
---
name: document-lifecycle
description: Unified document lifecycle management for agent-output artifacts. Defines terminal statuses, unified numbering via .next-id, close procedures, and orphan detection. Load when creating, closing, or auditing planning/implementation/QA documents.
user-invocable: false
---

# Document Lifecycle

This skill defines how agent-output documents are created, tracked, and closed.

## Status Values

| Status | Meaning | Terminal? |
|--------|---------|-----------|
| Draft | Initial creation | No |
| Active | In progress | No |
| Committed | Successfully merged | **Yes** |
| Released | Published to users | **Yes** |
| Abandoned | Canceled, no completion | **Yes** |
| Deferred | Postponed indefinitely | **Yes** |
| Superseded | Replaced by another doc | **Yes** |

## ID Assignment

All documents get a unique numeric ID from `.agent-output/.next-id`:
1. Read current value
2. Increment and save
3. Use format: `ID: <number>`, `Origin: <number>`, `UUID: <short-hash>`

## Close Procedure

When a document reaches terminal status:
1. Update Status field in frontmatter
2. Move file to `closed/` subdirectory
3. Add closure entry to document's changelog

## Orphan Detection

Periodically scan for:
- Documents with terminal status outside `closed/`
- Documents with non-terminal status that haven't been updated in 30 days
- Documents referenced by others but missing
```

**Why this works**:
- `user-invocable: false` -- background knowledge, not a command: hidden from the `/` menu, and the model can still load it
- Clear status taxonomy
- Actionable procedures
- Supports both creation and audit workflows

**Portability cost**: `user-invocable` is not in the Agent Skills spec, so this skill **fails to upload** to claude.ai or the Skills API as written. That is fine for a skill only ever used in Claude Code and VS Code. Strip the field from the upload copy otherwise.

---

## Example 5: Repairing Frontmatter That Silently Fails

**Before**: two defects, neither reported by Claude Code at load time.

```markdown
---
name: prototype
description: Build a throwaway prototype before committing to a design. Routes between three branches: a runnable terminal app (LOGIC), UI variations (UI), or a differential harness (PARITY). Use when the user wants to prototype... [continues past 1,024 chars]
---
```

1. `branches: a runnable` puts `: ` inside a plain scalar, which is **invalid YAML**. Strict parsers (Agent Skills validators, claude.ai upload, PyYAML) reject the file. Where a parser does reject it, Claude Code loads the skill with empty metadata: it stays in the `/` menu but never auto-triggers.
2. The description is over 1,024 characters, so the upload is rejected. Claude Code truncates it in the listing, and under budget pressure drops it.

**After**:

```markdown
---
name: prototype
description: >-
  Builds a throwaway prototype to settle a design question before committing to it. Routes
  between three branches: a runnable terminal app for state and business logic (LOGIC), several
  UI variations toggleable from one route (UI), or a differential harness comparing two real
  implementations (PARITY). Use when the user wants to prototype, mock up a UI, explore design
  options, or reconcile two implementations that must agree.
---
```

**Why this works**:
- `>-` folds the lines into one string, so `: ` and `#` are safe.
- Third person, the key use case first, trigger phrases last, about 450 characters.
- Detail that was crowding the description (the branch selection rules) moves into the body, which loads only on use.
- The "after" frontmatter passes `scripts/validate_skill.py`; the "before" fails it with both errors.
