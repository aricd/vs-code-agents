# Language

> **Non-redefinition disclaimer**: This file extends `deep-modules` with ICA-specific vocabulary. Module / Interface / Implementation / Depth are owned by `deep-modules`; do not redefine them here.

## Terms

**Seam** _(from Michael Feathers)_ — A place where you can alter behaviour without editing in that place. _Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter** — A concrete thing that satisfies an interface at a seam. Describes *role*, not substance.

**Leverage** — What callers get from depth: more capability per unit of interface learned.

**Locality** — What maintainers get from depth: changes concentrate in one place rather than spreading.

## Principles

- **Depth is a property of the interface, not the implementation.**
- **The deletion test.** If complexity reappears across N callers when you delete the module, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam.
- **One adapter means a hypothetical seam. Two adapters means a real one.**

## Relationships

- A **Module** has exactly one **Interface**.
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.
