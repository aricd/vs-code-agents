# AGENTS.md — Repository-Level Agent Instructions

> This file governs contributors working **in this repository** (dogfooding the plugin).
> For instructions on *using* the plugin in your own project, see [USING-AGENTS.md](USING-AGENTS.md).
> For a detailed explanation of agent roles and workflow, see [AGENTS-DEEP-DIVE.md](AGENTS-DEEP-DIVE.md).

---

## Always load CONTEXT.md first

At the start of any session in this repository, load [`CONTEXT.md`](CONTEXT.md).

`CONTEXT.md` is the canonical domain glossary for this repo. It defines the terms used consistently across agents, skills, plans, and ADRs. Loading it ensures every agent and session uses the same vocabulary, reduces ambiguity in plan interpretation, and prevents archaeological comments from being introduced (see the `Archaeological Comment` entry in `CONTEXT.md` and `docs/adr/ADR-014-no-archaeological-comments.md`). ADR-014 is currently proposed; this repository instruction enforces the convention independently of ADR acceptance.

## No archaeological comments

Consumer-facing files in this repository (agents, skills, docs, scripts, root READMEs) must not contain references to this repository's own internal change history. Use the canonical term from `CONTEXT.md`: **Archaeological Comment**.

Exemptions (`.agent-output/`, `CHANGELOG.md`, `docs/adr/`, functional numbering, illustrative examples, legitimate domain vocabulary, and embedded provenance blocks) are defined in `docs/adr/ADR-014-no-archaeological-comments.md`.

The validator `scripts/validate-no-archaeology.{ps1,sh}` provides a mechanical check; run `make check-archaeology` to invoke it.
