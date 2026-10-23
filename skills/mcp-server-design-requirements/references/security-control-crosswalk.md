# MCP Server Security Control Crosswalk

This crosswalk supports `SKILL.md`. It maps practical security topics to both source lenses:

- **Third-party consumption**: public OWASP GenAI Security Project guidance for safely using third-party MCP servers.
- **Internal MCP proxy lifecycle**: internal requirement catalog cited by `Req ID`.

## Lifecycle map

| Lifecycle moment | Main question | Primary source lens | Key controls / Req IDs |
|---|---|---|---|
| Idea / intake | Should we even connect to or build this MCP server? | Both | Registry/origin verification; `Req ID 1.01`, `1.03`, `1.06`, `4.11` |
| Design | Is access least-privileged, contextual, and safely authenticated? | Internal + OWASP auth guidance | `Req ID 1.01`, `1.05`, `1.07`-`1.13`, `4.06`, `4.07` |
| Build | Is code/dependency/supply-chain risk controlled? | Internal + OWASP scanner/tooling guidance | `Req ID 2.01`-`2.06`; scan descriptions, dependencies, packages |
| Deployment | Is runtime blast radius constrained? | Both | Sandbox/container; secure segments; allowlists; TLS; `Req ID 3.02`-`3.06` |
| Approval | Is the server versioned, pinned, approved, and owned? | Both | Tool manifest, checksum, approval log; `Req ID 3.07`-`3.09` |
| Operations | Can we detect, respond, patch, rollback, and kill-switch? | Both | Monitoring, alerts, audit, revalidation; `Req ID 4.01`-`4.11` |

## Risk/control map

| MCP-specific risk | Review questions | Recommended controls | Req IDs |
|---|---|---|---|
| Tool poisoning | Are hidden instructions embedded in tool descriptions/parameters? Is the manifest complete and stable? | Full manifest review, sanitize descriptions, compare names/descriptions/code, scan, pin version/hash, alert on drift | `2.01`, `2.05`, `3.09`, `4.09`, `4.10`, `4.11` |
| Rug pull | Can an approved server/tool silently change after approval? | Version pinning, checksums, registry, staged rollout, revalidation, rollback | `1.02`, `2.06`, `3.07`, `3.08`, `4.02`, `4.11` |
| Prompt injection | Can external content influence the model into unsafe tool calls or data leakage? | Treat retrieved data as untrusted, validate/sanitize inputs, strict schemas, context separation | `2.03`, `2.04`, `2.05`, `3.01` |
| Memory poisoning | Can false/malicious state persist across users/sessions? | Validate memory updates, attribution, TTL, memory segmentation | `1.01`, `1.05`, `3.01`, `4.08`, `4.09` |
| Tool interference | Can output from one tool/server trigger another unintentionally? | Separate contexts, HITL for consequential actions, timeouts, action-level scopes | `1.01`, `1.05`, `4.07`, `4.11` |
| Token misuse | Can tokens issued for another service be accepted? | Verify audience/issuer/scope on all inbound requests | `1.09`, `1.10`, `4.07` |
| Session abuse | Can session IDs be guessed, reused for auth, or cross-user? | Do not use sessions for auth; secure random IDs; bind session IDs to user identity | `1.11`, `1.12`, `1.13` |
| Excessive local access | Can a local MCP server read files, secrets, or network it does not need? | Container/sandbox, filesystem/network restrictions, JIT permissions | `1.01`, `1.05`, `2.03`, `4.01`, `4.03` |
| Remote exposure | Can unknown clients reach the MCP server? | Secure network segment/DMZ, allowlists, TLS/mTLS/OAuth, rate limits | `3.02`, `3.03`, `3.04`, `3.05`, `4.06` |
| Sensitive data handling | Is non-public data accessed, transformed, logged, or retained? | Risk assessment, encryption in transit/at rest, data minimization, protected logs | `1.03`, `3.05`, `3.06`, `4.09` |
| Weak operations | Is there no owner, patching, monitoring, or incident path? | Asset owner, CMDB, audit, vulnerability testing, patching, alerts, kill switch | `3.07`, `3.08`, `4.01`-`4.10` |
