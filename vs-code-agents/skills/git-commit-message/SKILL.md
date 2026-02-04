---
name: git-commit-message
description: Craft best-practice git commit messages. Supports standard format by default and Conventional Commits when explicitly requested. Load when crafting commit messages for staged changes.
license: MIT
metadata:
  author: groupzer0
  version: "1.0"
---

# Git Commit Message Skill

Produces one best-practice git commit message per request. Use this skill when:
- Crafting a commit message for staged changes
- Writing commit messages that follow best practices
- Creating Conventional Commit messages (when explicitly requested)

## Activation Triggers

Load this skill when the user says:
- "Craft a git commit message for …"
- "Write the commit message for the staged changes …"
- "Create a commit message for …"
- "Create a **Conventional Commit** message …" (Conventional format only when explicitly requested)

## Required Inputs

When context is missing, ask for the following (briefly):
- **What changed**: Summary of the change
- **Why changed**: Reason or user impact
- **Issue references** (optional): e.g., `Closes #123`
- **Breaking change** (if applicable): What breaks and how to migrate
- **For Conventional Commits only**: Desired `type` and optional `scope` (or permission to infer)

If the user declines to provide required context, return a short response:
> "Cannot complete: I need at minimum [what changed] and [why changed] to craft an accurate commit message."

Do NOT guess or fabricate change details.

---

## Output Format Rules (All Commit Messages)

Every commit message must follow these rules:

1. **Separate subject from body with a blank line**
2. **Subject line ≤ 50 characters** (hard target; revise if exceeded)
3. **Subject in imperative mood** ("Add feature" not "Added feature")
4. **No trailing period on subject line**
5. **Body wrapped at 72 characters**
6. **Body explains what and why** (not a file-by-file changelog)
7. **References (issues/PRs) in footer**

---

## Standard Commit Message Format

Use this format by default (when Conventional Commits is NOT requested):

```text
<imperative subject ≤50 chars>

<body: what changed and why, wrapped at 72 chars>

<optional footer: issue references>
```

---

## Conventional Commits Format

Use this format **only when the user explicitly requests** Conventional Commits.

### Header Format

```text
<type>(<scope>): <subject>
```

- `scope` is optional; omit parentheses when scope is absent
- Subject follows the same rules: imperative, ≤50 chars total for the header, no period

### What is Type?

**Type** is the change category that drives:
- **Release notes grouping**: Changelogs organize entries by type
- **SemVer automation**: Tools like semantic-release use type to determine version bumps
- **History filtering**: `git log --grep="^feat"` finds all features

### Type Selection (Minimum Set)

| Type | Use When |
|------|----------|
| `feat` | New user-facing capability |
| `fix` | Bug fix |
| `docs` | Documentation-only change |
| `style` | Formatting only, no behavior change |
| `refactor` | Code change that is neither fix nor feature |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `chore` | Build, tooling, or maintenance |

**Selection guidance:**
- Prefer user-provided type when available
- Infer type from described intent (not by guessing from filenames alone)
- If type is ambiguous, ask one clarifying question rather than guessing

---

## Breaking Change Handling

Breaking changes require **both**:
1. `!` after type/scope in the header: `feat!:` or `feat(api)!:`
2. `BREAKING CHANGE:` footer at the **bottom** (after other footers)

### Footer Format

```text
BREAKING CHANGE: <what breaks and how to migrate>
```

**Rules:**
- Only include when user confirms the change is breaking
- Must describe user-visible or API-visible impact
- Must include minimal migration guidance
- Must be placed **after** other footers (e.g., `Closes #123`) so it is unmissable

---

## Worked Examples

### Example 1: Standard Commit Message

**Input:**
- What: Added rate limiting to the API
- Why: Prevent abuse and ensure fair usage
- Issue: #456

**Output:**
```text
Add rate limiting to API endpoints

Implement token bucket algorithm to limit requests per user.
This prevents abuse and ensures fair resource allocation for
all API consumers.

Rate limits are configurable via environment variables and
default to 100 requests per minute per user.

Closes #456
```

### Example 2: Conventional Commit (Non-Breaking)

**Input:**
- User requests Conventional Commit
- Type: feat
- Scope: auth
- What: Add OAuth2 support
- Why: Users requested single sign-on
- Issue: #789

**Output:**
```text
feat(auth): Add OAuth2 support for single sign-on

Integrate OAuth2 authorization code flow with configurable
providers. Initially supports Google and GitHub as identity
providers.

Users can now authenticate via their existing accounts,
reducing friction during onboarding.

Closes #789
```

### Example 3: Conventional Commit with Breaking Change

**Input:**
- User requests Conventional Commit
- Type: feat
- Scope: api
- What: Change response format from XML to JSON
- Why: JSON is more widely supported by modern clients
- Breaking: All clients using XML parsing will break
- Issue: #123

**Output:**
```text
feat(api)!: Change response format from XML to JSON

Replace XML response serialization with JSON across all API
endpoints. JSON provides better tooling support and smaller
payload sizes.

Clients must update their parsers from XML to JSON format.
See migration guide in docs/api-migration.md.

Closes #123

BREAKING CHANGE: API responses are now JSON instead of XML.
All clients must update their response parsers. XML format
is no longer supported.
```

---

## Quick Reference

### Subject Line Checklist
- [ ] Imperative mood ("Add" not "Added")
- [ ] ≤ 50 characters
- [ ] No trailing period
- [ ] Capitalized first word

### Body Checklist
- [ ] Blank line after subject
- [ ] Wrapped at 72 characters
- [ ] Explains what changed
- [ ] Explains why it changed

### Conventional Commits Checklist (when requested)
- [ ] Valid type from the defined set
- [ ] Scope in parentheses (if used)
- [ ] `!` after type/scope for breaking changes
- [ ] `BREAKING CHANGE:` footer at the bottom for breaking changes
