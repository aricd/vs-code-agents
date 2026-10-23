---
ID: 901
Origin: 901
UUID: cccc3333
Status: Active
---

# Rule-3 fixture: suspected mis-inheritance

Filename stem matches fixture plan 901 (`901-fixture-terminal-plan`), but this document's own uuid (`cccc3333`) does not match that plan's uuid (`aaaa1111`). `check-chain-closure` must report this distinctly as rule 3 (suspected mis-inheritance, naming the probable plan) -- and must NEVER adopt it into plan 901's chain on the strength of the filename match alone.
