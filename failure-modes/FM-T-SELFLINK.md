---
class_id: FM-T-SELFLINK
guarantee: G-T-SELFLINK
status: mitigated
provisional: true
---

# FM-T-SELFLINK

## Mode: FM-T-SELFLINK.THROUGH-LINK

**Mechanism.** A destination path passed to `link_entry()` resolves, through a link higher in
its own parent path, back to the link source. `is_link(dest)` is false (the resolved path is a
real directory) and `trees_differ(dest, source)` reports no drift -- necessarily, because the
two paths are the same directory and compare byte-identical. The drift guard therefore reads
the destination as safe to replace, and with `backup_replaced: true` the back-up-then-replace
branch `shutil.move`s the **source** aside, after which the link call has nothing to point at.

**Oracle.** `scripts/test_link_setup.py` \* structural -- property: for a target whose
destination resolves through a whole-directory link back to the shared root, the run exits
non-zero, every source directory survives byte-intact, and no `.bak` is produced anywhere
(Case A); AND an ordinary, non-self-referential target still links, exits zero, and each link
resolves to its own source (Case B). Case B is part of the property, not decoration: Case A
alone would pass against an implementation that refused everything, which is the
regression-test-in-costume this skill's own corollary warns about.

Demonstrated red before green, against an implementation with the guard block removed:
Case A exits **0**, reports `failed: 0`, and destroys all three sources into `.bak` -- the
escaped instance reproduced in miniature, including its most misleading property, that the
pre-guard run announces total success while having emptied the tree. Last revalidated against
G-T-SELFLINK wording: 2026-09-16.

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | mitigated | **escaped** 2026-09-16 | -- | `make setup` with a `claude-user` target at `~/.agents`, where `~/.agents/skills` was already a whole-directory junction onto `<repo>/skills`; all 43 skill directories moved to `<name>.bak`, 0 linked, repo left with no skills. Recovered by rename; no content lost |

**Note on evidentiary weight.** This is an `escaped` instance -- it reached a real machine and
did real damage, rather than being caught pre-merge. The failure was not that a guard was
missing; a guard existed and was reasoned about explicitly when the script was written (its
docstring describes protecting exactly this kind of destruction). It asked whether the
destination *differs* from the source, and the single condition under which replacement is
unconditionally destructive is the one where it does not differ at all.
