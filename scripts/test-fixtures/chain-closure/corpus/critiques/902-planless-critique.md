---
ID: 902
Origin: 902
UUID: bbbb2222
Status: OPEN
---

# Rule-2 fixture: a planless document (healthy, out-of-chain-scope)

Carries a uuid (`bbbb2222`) that no fixture plan claims, and a filename stem that matches no fixture plan either. `check-chain-closure` must report this as rule 2 (planless, out-of-chain-scope) -- a healthy state, not an error -- and must never adopt it into any chain by filename inference.
