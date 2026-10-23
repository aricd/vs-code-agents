# Single Supported Install Path: System-Level Linking; Retire the VS Code Agent-Plugin Install Option

## Status

accepted

## Amendment -- 2026-09-16: the home-level link is whole-directory, not per-item

The decision below stands unchanged: system-level linking is the one supported path, and the
Agent Plugin install is retired. **One mechanism detail in it was wrong and is corrected here.**

This ADR described the home-level target as `scripts/link_setup.py` driving a `claude-user`
target at `~/.agents`, producing per-item links. Acting on that description emptied this
repository: `~/.agents/skills` is a single whole-directory junction onto `<repo>/skills`, so
`~/.agents/skills/<name>` resolves through it back to the source, and the linker moved all 43
source directories aside (recovered; no content lost -- see the `fix(link-setup)` commit adding
the self-reference guard).

Corrected mechanism: the home-level link is **one whole-directory link, made once by hand**
(`mklink /J` on Windows, `ln -s` on POSIX), and `link_setup.py` does not manage it. Per-item
linking via `link_setup.py` remains correct for the per-workspace fallback, which is what it was
built for. `LINKING.md`, `README.md`, `USING-AGENTS.md` and `link-config.example.yaml` are
corrected to match; `targets: []` is the right config for a machine needing only the home link.

Everything the decision rests on is unaffected -- the Remote-SSH evidence concerns the Agent
Plugin cache, not how the link is made, and a whole-directory link has the same
Remote-SSH-safety property per-item links do.

## Context

This repository has documented three overlapping ways to get its agents/skills into a
consuming VS Code workspace at once: (A) "Install as a Plugin" (`README.md`/`USING-AGENTS.md`
Option A/1 — VS Code's Agent Plugin feature, `chat.plugins.enabled`, **Chat: Install Plugin
From Source**, introduced preview in VS Code 1.110, Feb 2026), (B) manual per-workspace copy
into `.github/agents`/`.github/skills`, or user-level copy into VS Code's own profile folder,
and (C) the config-driven symlink system (`scripts/link_setup.py`, documented in `LINKING.md`),
which automates (B) and has since grown a `claude-user` (system/home-directory) target in
addition to its original per-workspace targets.

Maintaining three documented paths costs more than it appears to: they can silently disagree
(the same agent showing up twice with different provenance — README's own "Migrating from
Workspace-Level Agents to Plugin" section exists only because this already happened once), and
only one of them turns out to behave consistently for how this repo is actually used.

**Path (A) does not work when a workspace is opened over Remote-SSH.** VS Code's Agent Plugin
data is registered and cached in the *local client machine's* profile directory (platform-
specific, e.g. under the local machine's VS Code application-data folder), not in anything the
*remote* extension host — which is what actually needs to see the agents/skills for a
Remote-SSH-opened workspace — reads from. The result is that a plugin installed and working
perfectly for a local workspace silently fails to appear at all once the same workspace is
reopened over Remote-SSH: no error, just an empty agents dropdown. This is a known, currently
unresolved limitation of the Agent Plugin feature, not a misconfiguration on this repo's part,
and there is no setting that fixes it — the plugin cache is inherently tied to whichever
machine's local profile VS Code's UI process is running from.

Given that this repository's primary maintainer works over Remote-SSH routinely, path (A) is
not just "one option among equals" — it is the one documented path that is known to fail for a
common, everyday way this repo is actually consumed. It should not be presented as the
"Recommended" option (as both README.md and USING-AGENTS.md currently do).

**Path (C)'s workspace-relative form has the opposite property but a different cost.**
Symlinking into each consuming workspace's own `.github/{skills,agents,prompts}` works
identically under Remote-SSH (there is no separate cache — the extension host that opens the
workspace reads the workspace's own files, wherever the workspace happens to be checked out),
but it means re-running the linker, and reviewing what gets linked, per workspace — and it
raises a real risk of showing the same agent twice if a workspace is *also* covered by a
system-level location (exactly the interference README's Plugin-migration section already
had to explain once, for a different pair of sources).

**Path (C)'s system-level form (`claude-user` target, `~/.agents`) avoids the per-workspace
duplication question by being the single place every local VS Code session on that machine
reads from — but it is scoped to one machine's home directory.** Used across multiple
machines (a Windows desktop and one or more Remote-SSH hosts), it needs to be set up once per
machine, the same one-time cost path (B)/(A) would also carry, but without either the
duplicate-registration risk of double-linking, or the Remote-SSH cache-locality bug that
disqualifies (A). It is currently the working, verified path for one of the three primitives
this repo distributes: **skills** are confirmed live at `~/.agents/skills` (all skills
hash-identical to this repo as of the most recent verification) and VS Code's `.agents/skills`
home-directory discovery location is a confirmed, working mechanism.

**Agents and prompts do not have an equivalent, confirmed system-level location today.**
`~/.copilot/agents/` is a documented, currently-unresolved upstream defect (agents placed
there do not load, tracked against the Copilot CLI project). A parallel `~/.claude/agents/`
location is plausible from VS Code's own documentation but does not exist yet on this
machine and has not been empirically verified here. Home-directory-level prompt discovery has
no confirmed location at all as of this writing. Asserting either of these works today, without
having verified it in a live Copilot Chat session, would repeat the exact failure mode this ADR
exists to stop: presenting an install path as supported before confirming it actually loads.

## Decision

**Retire path (A) — VS Code Agent Plugin installation — as a documented, supported install
method for this repository.** Remove the "Install as a Plugin" instructions from
`README.md` and `USING-AGENTS.md`. This does **not** touch `plugin.json` or
`hooks/hooks.json`: those files are the manifest for this repository's separate identity as a
Claude Code plugin (`hooks/hooks.json`'s `${CLAUDE_PLUGIN_ROOT}`-templated hooks are Claude
Code's own plugin-hook schema, unrelated to VS Code's Agent Plugin feature or its Remote-SSH
defect), and nothing in this ADR's evidence bears on that usage. Only
`scripts/install-probe.{sh,ps1}` — which exists solely to register this repo as a *VS Code*
Agent Plugin in a scratch profile and confirm VS Code discovered it — is removed, since the
install path it probes is the one being retired.

**Adopt system-level linking (`scripts/link_setup.py`, `claude-user`-style target pointed at
`~/.agents`) as the one documented, supported path for distributing this repo's skills into
VS Code.** `LINKING.md` is rewritten to present this as the default, with per-workspace
`.github/{skills,agents,prompts}` targets documented as a fallback for a workspace that
specifically should not read from the shared system-level location (for example, a workspace
under someone else's review where an unreviewed shared skill set should not silently apply) —
not as a co-equal default, to avoid the double-registration risk.

**Agents and prompts are left an explicitly open gap, not silently routed to an unverified
location.** `LINKING.md` states plainly that this repository does not yet have a confirmed
system-level distribution path for agents or prompts, names the two candidate locations
(`~/.claude/agents/`, and whatever location a future VS Code release documents for
`.agents/agents` or `.agents/prompts`) as unverified, and directs whoever picks this up to
confirm discovery in a live Copilot Chat session before updating this ADR or `LINKING.md` to
claim it works — rather than inventing a rationale for why one of them should work, which is
exactly the discipline `deep-modules`/`lean-design`'s own owner-intent rule already asks for
elsewhere in this repo.

**Remote-SSH behavior is documented in `LINKING.md` in plain prose, without a hyperlink to any
specific external tracker issue** (per explicit instruction — this repo's own convention is to
describe defects it has independently verified as a mechanism, not to depend on an external
issue number that could be renumbered, closed, or reworded out from under a citation).

## Considered Options

1. **Keep all three paths documented, let the user pick.** Rejected: this is the status quo
   and it is what produced the Plugin-vs-workspace duplicate-agent problem README already
   documents a cleanup procedure for. A second migration section for
   Plugin-vs-system-level would be the same defect recurring.
2. **Drop symlinking, standardize on the Plugin path.** Rejected outright: the Plugin path is
   the one with a confirmed Remote-SSH failure mode, and Remote-SSH is not an edge case for
   this repo's actual use.
3. **Standardize on system-level linking; retire the Plugin install path; leave agents/prompts
   an open, honestly-labeled gap instead of picking an unverified home for them (chosen).**
   Matches the evidence exactly: ships the one primitive (skills) that is confirmed working,
   commits to nothing that has not been checked.

## Consequences

### Positive

- One documented install path for skills, verified to behave the same whether the consuming
  workspace is local or opened over Remote-SSH.
- Removes the Plugin-vs-workspace duplicate-registration failure mode at its source (there is
  only one thing to install now) instead of documenting a cleanup procedure for it.
- `plugin.json`/`hooks/hooks.json` and their validator (`scripts/smoke-test-plugin.{sh,ps1}`)
  are explicitly preserved and re-scoped in this ADR's record as serving this repo's Claude
  Code plugin identity, so a future reader does not mistake their presence for leftover VS Code
  Agent Plugin scaffolding and remove them by the same reasoning that removed
  `install-probe.*`.

### Negative

- Agents and prompts have no supported system-level distribution path until one is verified;
  a workspace that wants synced agents/prompts must use the per-workspace fallback target for
  those two primitives specifically, which reintroduces the double-registration question for
  exactly those two primitives, in exactly the workspaces that opt into it.
- System-level linking must be set up once per machine (Windows desktop, each Remote-SSH host
  used) rather than once per repository clone — an explicit, accepted operational cost, not a
  defect.

## Related ADRs

- [ADR-016](ADR-016-executive-summary-skill-extraction.md): unrelated in subject, establishes
  the precedent this ADR follows of extracting a concern into its own clearly-scoped owner
  rather than leaving it implicit across multiple files.
