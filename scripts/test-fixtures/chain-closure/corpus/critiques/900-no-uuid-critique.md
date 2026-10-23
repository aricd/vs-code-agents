---
ID: 900
Origin: 900
Status: OPEN
---

# Rule-1 fixture: a document with no UUID frontmatter at all

Deliberately omits the `UUID:` field. `check-chain-closure` must report this document under rule 1 (no uuid, cannot be placed) rather than silently skipping it or crashing.
