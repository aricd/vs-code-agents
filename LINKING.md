# Linking Agents and Skills

This directory is the **shared source** of VS Code agents and skills. The canonical implementation, `scripts/link_setup.py`, distributes them **into** wherever VS Code actually reads them from, so every consumer stays in sync with one copy instead of drifting from it.

See [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md) for why this is the one supported install path -- in short, the alternative this repo used to also document (installing as a VS Code Agent Plugin) is cached on the local client machine and silently stops being discovered once a workspace is reopened over Remote-SSH. Linking has no such cache: it puts real files (symlinks on POSIX, junctions on Windows) wherever the reading side -- the workspace, or a machine's home directory -- already looks, so whichever host actually opens the workspace sees the same thing a local session would.

## Requirements

- **Python 3** on `PATH` as `python` or `python3` -- `scripts/link_setup.py` is the canonical implementation and both shims (`link-setup.ps1`/`.sh`) exec it; there is no other supported entry point. Verified present as `python`/`python3` on Windows and WSL, and `/usr/bin/python3` on Ubuntu-based Remote-SSH hosts. PyYAML is used when importable (strictly more correct config parsing) but is optional -- a small built-in fallback reader covers the documented `link-config.yaml` subset with no third-party dependency required.
- **Windows: no Developer Mode and no elevated shell required.** Directory links use an NTFS _junction_ (`_winapi.CreateJunction`), not a symlink -- a junction needs neither. This matters because an earlier, bash-only implementation used `ln -s` unconditionally, which fails unprivileged on Windows; only individual _files_ (not directories) fall back symlink -> hardlink -> copy if a link cannot be created for some other reason, and a `copy` fallback is logged as a `[WARN]` because it **will** drift.

## The Default: System-Level Linking Is ONE Whole-Directory Link

VS Code's `.agents/skills` home-directory location is read for every local VS Code session on that machine, so one link covers every workspace you open there -- no per-workspace step, and no risk of the same skill showing up twice from two different sources.

**That link is a single whole-directory link, made once by hand. `link_setup.py` does not manage it, and must not be pointed at it.**

```
~/.agents/skills   -->   <shared repo>/skills          (ONE link, the whole tree)
```

Windows (junction -- no Developer Mode or elevation needed):

```
mklink /J "%USERPROFILE%\.agents\skills" "C:\path\to\vs-code-agents\skills"
```

POSIX:

```bash
ln -s /path/to/vs-code-agents/skills ~/.agents/skills
```

**Why whole-directory here rather than per-item.** A new skill appears the moment it is committed, with no re-run of anything. The `old/`-archive rationale that motivates per-item links elsewhere does not apply: nothing else lives _inside_ `~/.agents/skills` needing to survive alongside the links (`memories/` and any `skills.stale-backup-*` are siblings of `skills`, not contents of it).

> [!WARNING] **Do not add a `claude-user`-style target for `~/.agents` to `link-config.yaml`.** Once the whole-directory link exists, `~/.agents/skills/<name>` resolves _through_ it back to `<repo>/skills/<name>` -- the source. The linker then treats each source directory as its own replaceable destination and moves all of them aside. `link_setup.py` now refuses this (self-reference guard, `--check` reports it), but the correct configuration is simply not to declare the target: `targets: []` is the right content for a machine that only needs the home-level link.

**This currently covers skills only.** `~/.copilot/agents/` -- the closest analogous location for agents -- has a documented, currently-unresolved upstream defect where agents placed there are not loaded at all. A parallel `~/.claude/agents/` location is plausible from VS Code's own documentation but has not been verified working on any machine this repo has been set up on. Home-directory-level prompt discovery has no confirmed location at all as of this writing. **Do not enable `link_agents`/`link_prompts` on a system-level target on the strength of this paragraph alone** -- confirm discovery in a live Copilot Chat session first (reload the window, check the agents dropdown / a prompt-file picker), and update this file once you have.

## Per-Workspace Fallback

A per-workspace target -- `target_root` pointed at a specific workspace's `.github/` -- remains available for two cases the system-level default does not cover:

1. **Agents or prompts**, which have no confirmed system-level location today (above).
2. **A workspace that should not inherit the shared set at all** -- for example, one under someone else's review where an unreviewed shared skill/agent set should not silently apply.

Per-workspace linking has the same Remote-SSH-safety property as the system-level target (it is still real files inside the workspace, not a cache tied to one machine) -- what it does not have is the system-level target's protection against showing the same skill/agent twice. If a workspace has its own per-workspace agents/prompts target **and** is also opened on a machine where a future system-level agents/prompts location exists, check for duplicates before enabling both.

## Claude Code

Claude Code reads skills in the same format, but agents and prompts in a different one, so it is set up in two halves.

**Skills: one whole-directory link, made once by hand**, exactly like `~/.agents/skills` above:

```
mklink /J "%USERPROFILE%\.claude\skills" "C:\path\to\vs-code-agents\skills"
```

**Agents and prompts: generated by the `claude-code` target.** A target with `format: "claude-code"` converts instead of linking:

```
~/.claude/agents/<name>.md     <=  agents/<agent>.agent.md
~/.claude/commands/<name>.md   <=  prompts/<prompt>.prompt.md
```

```bash
python scripts/link_setup.py --target claude-code --check   # preview
python scripts/link_setup.py --target claude-code           # apply
```

**Re-run after editing an agent or prompt.** Unlike a link, a generated file does not follow its source. Skills need no re-run.

What the conversion does:

- **Names** are the source `name` lowercased, with runs of other characters turned into `-` (`Code Reviewer` -> `code-reviewer`, `OBS-Create` -> `obs-create`).
- **Tools** map through `VSCODE_TO_CLAUDE_TOOLS` in `link_setup.py`: `execute` -> `Bash`, `PowerShell`; `read` -> `Read`, `LSP`; `edit` -> `Edit`, `Write`, `NotebookEdit`; `search` -> `Glob`, `Grep`, `LSP`; `web` -> `WebFetch`, `WebSearch`; `todo` -> `TaskCreate`/`TaskGet`/`TaskList`/`TaskUpdate`/`TodoWrite` (Claude Code uses whichever set is active); `agent` -> `Agent`; `vscode` -> `AskUserQuestion`. Single tools (`read/readFile`, `edit/createFile`, ...) map to their nearest equivalent; a tool with no equivalent (`read/terminalSelection`, `vscode/vscodeAPI`) is dropped. `Skill` and `ToolSearch` are added to every list, because an explicit allowlist would otherwise stop the agent from loading skills. An unmapped tool is reported as a warning.
- **`argument-hint`** is appended to an agent's description (Claude Code agents have no hint field), and kept as `argument-hint` on a command.
- **Repo paths** under `scripts/`, `agents/`, `templates/` and `skills/` become absolute (`<repo>/scripts/...`) when they exist in the repo, so the scripts the agents run resolve from any workspace. Workspace paths such as `.agent-output/...` are never rewritten.
- **Command bodies** have `$0`..`$N` and `$ARGUMENTS` escaped, since Claude Code would otherwise substitute them. Arguments typed after the command are appended by Claude Code itself.
- **Hooks** are not converted.

**Ownership.** Every generated file carries a `# generated-by:` line in its frontmatter. Only a file carrying that line is ever overwritten or pruned (a generated file whose source was removed or renamed is deleted). A hand-written agent or command at the same path gets the same drift protection as a real directory in link mode: it is reported and left alone unless you pass `--backup` or `--force`.

## Architecture

**Direction:** shared repo -> each consuming location (a home directory, or a workspace). `link_setup.py` creates one link **per skill / per agent / per prompt / per script** (not one directory-level link), so a target can keep sibling content -- notably an `old/` archive of previously-vendored items -- right next to the links, and `preserve` (default: `old`) is never touched.

```
vs-code-agents/                      <- Shared source (this repo)
├── scripts/
│   ├── link-config.example.yaml     <- Committed template
│   ├── link-config.yaml             <- Your local config (gitignored, never committed)
│   ├── link_setup.py                <- Canonical implementation -- edit behaviour only here
│   ├── link-setup.sh                <- Thin shim, execs link_setup.py
│   └── link-setup.ps1               <- Thin shim, execs link_setup.py
├── skills/<skill>/                  <- Canonical skills
├── agents/<agent>.agent.md          <- Canonical agents
└── prompts/<prompt>.prompt.md       <- Canonical prompts

~/.agents/ (the "claude-user" target, this machine's home directory)
├── skills/
│   ├── <skill>  -> vs-code-agents/skills/<skill>     (per-item link)
│   ├── ...
│   └── old/                          <- Preserved; never touched
└── (agents/, prompts/ intentionally not linked here yet -- see above)

A per-workspace target, e.g. <workspace>/.github/:
├── skills/...
├── agents/<agent>.agent.md -> vs-code-agents/agents/<agent>.agent.md
└── prompts/<prompt>.prompt.md -> vs-code-agents/prompts/<prompt>.prompt.md
```

**Link strategy, and why it matters.** On POSIX, a directory is a symlink. On Windows, a directory is an NTFS **junction** (created via `_winapi.CreateJunction`) rather than a symlink, because a junction needs neither Developer Mode nor an elevated shell -- a symlink does. An earlier bash-only implementation used `ln -s` unconditionally, which fails unprivileged on Windows; the observed result, once, was that someone copied the tree by hand instead, and the copy silently forked from the repo in both directions. Individual files fall back symlink -> hardlink -> copy if a junction/symlink cannot be created; a `copy` fallback is logged as a warning because it **will** drift, the same way the hand-copy did.

**Safety.** `link_setup.py` refuses, by default, to destroy a real (non-link) target whose contents differ from the source -- that is exactly how the hand-copy divergence above was found in the first place. `--check` reports the drift without changing anything, `--backup` moves the divergent real path aside (`<name>.bak` by default), and `--force` overwrites it deliberately. A target whose parent directory does not exist is skipped with a warning rather than manufactured -- so a config entry for a Remote-SSH host's home directory does not silently create a bogus `C:\home\...` tree when run from Windows, or vice versa.

## Configuration (scripts/link-config.yaml)

Gitignored; copy the committed template to bootstrap it:

```bash
cp scripts/link-config.example.yaml scripts/link-config.yaml
```

Schema:

```yaml
# Root of the shared skills/agents repo, relative to scripts/ unless absolute.
shared_root: ".."

# Names never touched in a target directory (archives, workspace-only items).
preserve: "old"

# Backup behavior for pre-existing real files/dirs that collide with a link.
backup_replaced: true
backup_ext: ".bak"

targets:
  # The default: one system-level target per machine you use.
  - name: "claude-user"
    target_root: "~/.agents"
    link_skills: "true"
    link_agents: "false" # ~/.agents has no agents/ tree VS Code reads yet -- see ADR-017
    link_prompts: "false" # no confirmed discovery location yet -- see ADR-017
    link_scripts: "false"

  # Per-workspace fallback -- only for a workspace that specifically needs it (see above).
  # - name: "my-project"
  #   target_root: "/path/to/my-project/.github"
  #   link_skills: "true"
  #   link_agents: "true"
  #   link_prompts: "true"
  #   link_scripts: "false"
```

`link_scripts` defaults to `false` on every target because it distributes **executable** content, not markdown -- enable it deliberately, per target (see ADR-016).

## Usage

```bash
# Preview (no changes made)
python3 scripts/link_setup.py --check --verbose
# or: make setup-dry-run

# Apply
python3 scripts/link_setup.py --verbose
# or: make setup

# Only one target
python3 scripts/link_setup.py --target claude-user

# A pre-existing real path differs from the repo -- see what, without touching it
python3 scripts/link_setup.py --check
# ...then either:
python3 scripts/link_setup.py --backup     # move the real path aside, then link
python3 scripts/link_setup.py --force      # overwrite it deliberately
```

`link-setup.sh` / `link-setup.ps1` are thin shims that exec `link_setup.py` -- they hold no logic of their own, so a rule implemented in one shell and not the other cannot happen. Edit behaviour only in `link_setup.py`.

## Set Up a New Machine (Including a Remote-SSH Host)

The system-level target is scoped to one machine's home directory, so it needs to be set up once per machine you actually use -- your local Windows desktop, and separately, once each, on every Remote-SSH host you open these workspaces from:

```bash
git clone https://git.example.com/acme/vs-code-agents.git
cd vs-code-agents
cp scripts/link-config.example.yaml scripts/link-config.yaml   # claude-user target is the default
make setup
```

This is the same one-time cost either of the two retired/fallback paths would also carry -- the difference is what it buys: no plugin cache to go stale, and no per-workspace copy to keep in sync with the repo.

## Verify / Find Broken Links

```bash
make verify     # walks the targets in scripts/link-config.yaml, reports ok/BROKEN per link

# Or by hand, for the claude-user target:
ls -la ~/.agents/skills
readlink ~/.agents/skills/<skill-name>
find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {} \\; -print   # broken links
```

## Making Changes to Shared Skills

Edit the skill directly in this repo (`skills/<name>/SKILL.md`). Every linked target sees the change immediately -- no re-run needed. Only re-run `make setup` when a skill/agent/prompt is **added or removed**, or when onboarding a new machine or workspace target.

## Troubleshooting

**"Config file not found"** -- `scripts/link-config.yaml` is gitignored; `make setup` will copy the template and exit with a reminder if it is missing.

**A real directory already exists where a link should go** -- `link_setup.py` refuses to destroy it if its contents differ from the repo (see Safety, above). Run `--check` to see the diff, then `--backup` or `--force` deliberately.

**Symlinks/junctions not created on Windows** -- directories use a junction (no special privilege needed); only individual _files_ fall back to a symlink, then a hardlink, then a plain copy if neither is available. A `copy` fallback in the log output means that file will drift from the repo until re-linked -- treat it as a signal something about that host's filesystem or permissions needs attention, not as steady-state.

**Why does a per-workspace target behave differently under Remote-SSH than the system-level one?** It doesn't, and that is the point -- both are real files inside whatever machine's filesystem is reachable, so both are read correctly from wherever a workspace happens to be opened. What does _not_ behave consistently under Remote-SSH is the retired VS Code Agent Plugin install path (ADR-017): its registration lives in the local client machine's own application data, not in any workspace or home directory, so the remote side that actually needs to read it for a Remote-SSH session never sees it. Neither kind of link has that problem, because neither one depends on that cache.

## References

- [ADR-017](docs/adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md): why this is the one supported path, and what is explicitly still an open question (agents/prompts at system level).
- [Link Setup Implementation](scripts/link_setup.py)
- [Link Configuration Template](scripts/link-config.example.yaml)

---

**Last Updated**: 2026-10-13 **Status**: Ready for use
