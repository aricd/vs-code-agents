---
ID: 905
Origin: 905
UUID: eeee5555
Status: Committed
---

# Rule-5 fixture plan: 905-fixture-collision-plan

Committed fixture plan whose own YAML execution-state (`900-fixture-collision-execution-state.yaml`, sharing plan 905's chain uuid `eeee5555`) is still open in `planning/`. Its expected close destination (`planning/closed/900-fixture-collision-execution-state.yaml`) is already occupied by an UNRELATED chain's file with different content -- reproducing the real `027-execution-state.yaml` collision shape. `check-chain-closure` must refuse this specific move (rule 5) without blocking the rest of the chain's closure.
