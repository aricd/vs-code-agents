---
ID: 903
Origin: 903
UUID: dddd4444
Status: Active
---

# Rule-4 fixture plan A

Deliberately shares uuid `dddd4444` with fixture plan 904, but its content differs from plan 904's. `check-chain-closure` must report this as rule 4 (ambiguous, multiple plans claim one uuid) rather than guessing which is authoritative.
