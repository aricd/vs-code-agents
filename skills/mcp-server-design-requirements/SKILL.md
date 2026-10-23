---
name: mcp-server-design-requirements
description: "Use when evaluating, designing, building, approving, operating, reviewing, or auditing any Model Context Protocol (MCP) server, or when defining or checking MCP server requirements, controls, or compliance. Covers two lenses: (1) consuming third-party/external MCP servers -- discovery, manifest transparency, tool-poisoning/rug-pull defense, sandboxing, auth, monitoring, governance; and (2) designing/building/operating an internal MCP proxy server against the requirement catalog (Req IDs 1.01-4.11). Load for MCP design requirements, tool manifests, transport/deployment choices, proxy architecture, third-party intake/approval gates, or security/governance review of MCP tools, resources, and prompts."
---

# MCP Server Design Requirements Skill

## Purpose

Use this skill to guide MCP server design requirements review across two related but different situations:

1. **Using a third-party MCP server**: a server not developed inside the organization. Treat it as untrusted until it is discovered through an approved channel, verified, sandboxed, least-privileged, monitored, and governed.
2. **Designing, building, implementing, or operating an internal MCP proxy server**: apply the internal requirement catalog by `req_id`, preserving exact requirement wording when quoting requirements.

The skill is designed for agent usage. It gives a core operating model, a routing protocol, crosswalks, and output templates. The source text is packaged under `references/` so an agent can quote or trace back to either source.

## Packaged references

- `references/owasp-third-party-mcp-server-security-skill.md` - text-only adaptation of the OWASP GenAI Security Project third-party MCP server guide.
- `references/owasp-third-party-mcp-source-raw-layout.txt` - raw layout text extracted from the OWASP PDF, retained for traceability.
- `references/proxy-server-security-requirements-source.md` - exact pasted internal MCP proxy server security requirement reference.
- `references/proxy-requirement-catalog.yaml` - extracted requirement catalog from the internal reference.
- `references/security-control-crosswalk.md` - practical map from MCP risk/control topics to the two source lenses.
- `templates/review-report-template.md` - reusable output format for reviews, approvals, and gap analyses.

## Source authority and conflict rules

When both sources apply, use both. Do not collapse them into one generic checklist.

- **Third-party consumption guidance** answers: Should we connect to this server? How should we discover, verify, sandbox, pin, scan, monitor, and govern an untrusted or externally maintained MCP server?
- **Internal MCP proxy requirements** answer: What must be true when designing, building, implementing, and operating an internal MCP proxy server?
- If the internal requirement catalog uses `must`, treat it as mandatory in internal/enterprise contexts.
- If OWASP guidance is stronger than a listed internal requirement, recommend the stronger control and label it as OWASP-derived or additional defense-in-depth.
- If an internal requirement has a blank `standards` field, treat it as an unmapped standard, not as non-applicable.
- Preserve exact internal requirement wording when quoting. Cite requirements as `Req ID X.XX`.
- Do not silently fix typos in source requirements. Only create cleaned derivative wording if explicitly asked.

## Fast routing protocol

Before recommending controls, classify the situation.

### Step 1 - Identify the server relationship

Choose one:

- `third_party_consumed`: The organization is using an MCP server from an external vendor, repository, registry, or other non-internal source.
- `internal_proxy_built`: The organization is designing/building/operating an internal MCP proxy server.
- `internal_proxy_consumes_third_party`: An internal proxy uses third-party code, third-party tools, external APIs, or externally maintained MCP servers. Apply both source lenses.
- `unknown`: Ask for or state missing facts. Do not assume trust.

### Step 2 - Identify deployment pattern

Choose one or more:

- `local_stdio`: Local MCP server, often launched as a subprocess and connected via STDIO.
- `remote_streamable_http`: Remote MCP server connected via Streamable HTTP.
- `mixed`: Local server that also calls remote APIs/tools, or proxy topology where multiple transport layers exist.
- `unknown`: Record as an assessment gap.

### Step 3 - Identify data/action risk

Capture:

- Data classification: public, internal, non-public, regulated, sensitive, unknown.
- Tool effects: read-only, write/update, delete/destructive, code execution, filesystem, network/API calls, email/messaging, privileged admin, unknown.
- Identity context: system identity, user-delegated identity, mixed, unknown.
- Runtime scope: local machine, container, server segment, cloud environment, remote vendor environment, unknown.

### Step 4 - Select the review path

- Third-party only -> use **Review Path A: third-party intake and consumption**.
- Internal proxy only -> use **Review Path B: internal MCP proxy lifecycle**.
- Internal proxy with third-party components -> use **Review Path C: combined review**.

## Review Path A - Third-party intake and consumption

Use this path when the target server is externally maintained or otherwise not developed inside the organization.

Minimum control sequence:

1. **Discovery and origin**
   - Use only approved registry/source channels.
   - Verify origin, repository, package provenance, signatures if available, and known vulnerability status.
   - Reject or quarantine unknown-origin servers.

2. **Full manifest transparency**
   - Review full tool manifests, descriptions, parameters, resources, prompts, and claimed capabilities.
   - Do not rely on shortened UI summaries.
   - Compare tool names, descriptions, schemas, and implementation behavior for mismatches.

3. **Tool poisoning and rug-pull protection**
   - Scan descriptions and parameters for hidden instructions, suspicious markup, and prompt-injection-like language.
   - Pin approved versions and manifests.
   - Record checksums/hashes and alert on drift.

4. **Prompt injection and untrusted content handling**
   - Treat tool responses, tool descriptions, user inputs, external resources, and retrieved content as untrusted.
   - Validate and sanitize inputs before model exposure.
   - Enforce strict tool input schemas.

5. **Sandbox and blast-radius control**
   - Prefer containers or equivalent isolation for local third-party servers.
   - Limit filesystem, network, environment variables, secrets, and host resources.
   - Use JIT and task-scoped permissions where possible.

6. **Authentication and authorization**
   - For system operations, prefer client credentials or equivalent service identity.
   - For user-bound operations, prefer user-delegated flows such as OIDC/PKCE.
   - Define least-permission scopes and action-level permissions.
   - Use short-lived, narrowly scoped credentials if OAuth is unavailable.

7. **Tool interference control**
   - Isolate context per server/tool execution.
   - Avoid accidental tool chains across MCP servers.
   - Require human approval for high-impact actions.
   - Set timeouts and rate limits.

8. **Staged rollout and monitoring**
   - Start in staging with telemetry.
   - Promote only after review/sign-off and a probation period.
   - Monitor unusual tool invocation patterns, file reads, API calls, auth failures, and data egress.
   - Maintain rollback and kill-switch procedures.

9. **Governance**
   - Record submitter, security reviewer, domain owner, approver, and operator.
   - Keep a registry of approved servers, versions, permissions, owners, evidence, and approval history.
   - Revalidate periodically and on version/tool/manifest changes.

## Review Path B - Internal MCP proxy lifecycle

Use this path when the organization is designing, building, implementing, or operating an internal MCP proxy server.

### Design requirements

Use these requirement groups early in architecture review:

- Least access / least privilege / contextual authorization: `Req ID 1.01`, `Req ID 1.05`
- Documentation and diagrams: `Req ID 1.02`
- Risk assessment for non-public data: `Req ID 1.03`
- Security-by-design, threat modeling, risk assessment: `Req ID 1.06`
- Client ID / authorization server behavior: `Req ID 1.07`, `Req ID 1.08`
- Token audience and inbound request verification: `Req ID 1.09`, `Req ID 1.10`
- Session rules: `Req ID 1.11`, `Req ID 1.12`, `Req ID 1.13`

### Build requirements

Use these requirement groups during implementation and pre-release engineering review:

- Open-source component vetting: `Req ID 2.01`
- Secure development environment: `Req ID 2.02`
- Secure design and architecture: `Req ID 2.03`
- Secure coding standards: `Req ID 2.04`
- Development and pre-production testing: `Req ID 2.05`
- Production readiness review and documentation: `Req ID 2.06`

### Implementation/deployment requirements

Use these requirement groups for deployment readiness:

- Harden auth, access controls, and data handling: `Req ID 3.01`
- Secure segment/DMZ: `Req ID 3.02`
- Firewall or allowlist controls: `Req ID 3.03`
- TLS / encryption in transit: `Req ID 3.04`, `Req ID 3.05`
- Encryption at rest: `Req ID 3.06`
- CMDB registration: `Req ID 3.07`
- Asset owner and lifecycle accountability: `Req ID 3.08`
- Approved/licensed/tested assets only: `Req ID 3.09`

### Operations requirements

Use these requirement groups for production operation and periodic review:

- Malicious code controls and supported platform: `Req ID 4.01`
- Ongoing audit, vulnerability testing, patching: `Req ID 4.02`
- Runtime protections and vulnerability monitoring: `Req ID 4.03`
- Secure administration, maintenance, training, owner identification, control verification, log review, and account/system monitoring: `Req ID 4.04`
- Secure operation procedures: `Req ID 4.05`
- Mutual server/client authentication: `Req ID 4.06`
- Minimum-permission connection/token scopes: `Req ID 4.07`
- AI-system logging and monitoring rationale: `Req ID 4.08`
- Auth/data/error logging: `Req ID 4.09`
- Alerting for significant security events: `Req ID 4.10`
- Control of tools/APIs/external sources: `Req ID 4.11`

## Review Path C - Combined review

Use this path when an internal MCP proxy server consumes third-party servers/components or exposes third-party APIs/tools through an enterprise interface.

Apply Path A and Path B together. The combined review must explicitly answer:

1. **Which part is internally built and which part is externally sourced?**
2. **Which identities cross the boundary?** User identity, system identity, service account, delegated OAuth token, API key, certificate.
3. **Where can a malicious tool description, server response, prompt, resource, or memory update enter the system?**
4. **Where can the MCP proxy enforce policy?** Registry, manifest validation, auth gateway, schema validation, tool router, sandbox, network egress, logging, HITL approval, kill switch.
5. **Which internal `Req ID`s are satisfied by the design, and which remain gaps?**
6. **Which third-party consumption controls are satisfied, and which remain gaps?**

Minimum combined stance:

- The internal proxy should not make an unvetted third-party MCP server appear trusted merely because it is proxied.
- The proxy should preserve or improve least privilege, not aggregate broad privileges into a single high-impact tool surface.
- The proxy should expose stable, reviewed tool/resource/prompt contracts and reject silent drift from upstream tools.
- The proxy should log enough to reconstruct who/what invoked which tool, against which data, under which identity/scope, and with which result/error.

## Threat/control crosswalk

Use this quick map to keep reviews complete.

| Topic | Third-party consumption lens | Internal proxy requirement lens |
|---|---|---|
| Origin and discovery | Trusted registry, origin verification, source/package review, staged rollout | Documentation and diagrams `Req ID 1.02`; CMDB and asset ownership `Req ID 3.07`, `Req ID 3.08`; control tools/APIs/external source `Req ID 4.11` |
| Tool poisoning / rug pull | Full manifest transparency, sanitize descriptions, pin versions, hashes/checksums, drift alerts | Open-source vetting `Req ID 2.01`; approved/tested assets `Req ID 3.09`; monitoring/alerting `Req ID 4.09`, `Req ID 4.10` |
| Prompt injection | Validate untrusted data, strong schemas, context segmentation | Secure coding/testing `Req ID 2.04`, `Req ID 2.05`; hardened data handling `Req ID 3.01` |
| Memory poisoning | Validate memory updates, require attribution, TTL, segment memory | Secure design `Req ID 2.03`; data handling `Req ID 3.01`; logging/monitoring `Req ID 4.08`, `Req ID 4.09` |
| Tool interference | HITL, separate context, timeouts, avoid cross-server accidental chains | Least privilege `Req ID 1.01`, `Req ID 1.05`; minimum-permission scopes `Req ID 4.07` |
| Authentication | Client credentials for system operations, OIDC/PKCE for user operations, protected registration when needed | Dynamic/static client ID `Req ID 1.07`, `Req ID 1.08`; no session auth `Req ID 1.11`; mutual auth `Req ID 4.06` |
| Authorization | Least-permission scopes, granular permissions, JIT access, HITL | Least access/privilege `Req ID 1.01`, `Req ID 1.05`; token scope `Req ID 4.07` |
| Token validation | Verify token use, audience, issuance, scopes | Tokens issued for MCP server only `Req ID 1.09`; verify inbound requests `Req ID 1.10` |
| Session safety | Isolate sessions and operations | Secure non-deterministic session IDs `Req ID 1.12`; bind session IDs to user info `Req ID 1.13` |
| Local server isolation | Containerize/sandbox; limit filesystem/network/secrets | Secure architecture `Req ID 2.03`; malicious code controls `Req ID 4.01`; runtime protections `Req ID 4.03` |
| Remote server connection | Streamable HTTP with TLS/mTLS/OAuth, WAF/rate limiting, credential rotation | Secure segments/DMZ `Req ID 3.02`; allowlists `Req ID 3.03`; TLS/encryption `Req ID 3.04`, `Req ID 3.05` |
| Data protection | Local data protection, sanitize data passed into LLM | Risk assessment for non-public data `Req ID 1.03`; encryption at rest/in transit `Req ID 3.05`, `Req ID 3.06` |
| Build assurance | Scan code/dependencies and package health | Secure dev environment/design/coding/testing `Req ID 2.02`-`Req ID 2.06` |
| Operations | Telemetry, incident detection, version monitoring, rollback/kill switch | Audit, patching, admin, logs, alerts `Req ID 4.02`-`Req ID 4.10` |

## Minimum evidence checklist

Ask for or inspect evidence in this order. If evidence is missing, mark it as a gap rather than assuming compliance.

### Identity and access evidence

- Authentication flow diagram.
- Identity provider and token issuer.
- Token audience validation approach.
- Scope model and per-tool/action permission model.
- User-delegated vs system identity boundaries.
- HITL approval points for high-impact actions.
- Session ID generation and binding behavior.

### Tool/resource/prompt evidence

- Full tool manifest.
- Tool descriptions, parameters, schemas, and capabilities.
- Resource list and data classifications.
- Prompt templates exposed by the server.
- Diff of current manifest against approved/pinned manifest.
- Tool implementation/code or vendor attestation when available.

### Runtime and network evidence

- Deployment architecture.
- Transport mode: STDIO, Streamable HTTP, mixed.
- Container/sandbox configuration.
- Filesystem, network, secret, and environment-variable access restrictions.
- Network segment, firewall, IP allowlist, WAF/rate-limit configuration.
- TLS/mTLS/certificate/OAuth configuration.

### Build and supply-chain evidence

- Source repository and dependency list.
- Open-source and third-party library review results.
- SAST/SCA/secrets/malware scan results.
- Secure coding/test evidence.
- Release approval record.
- Version pinning and checksum/hash record.

### Operations evidence

- CMDB/asset record and asset owner.
- Logging fields and protected log storage.
- Monitoring and alert rules.
- Vulnerability management and patching process.
- Kill-switch/rollback procedure.
- Periodic revalidation cadence.
- Approval history and owners.

## Output rules for agents

Every assessment output must include:

- Classification: third-party, internal proxy, or combined.
- Deployment pattern: local STDIO, remote Streamable HTTP, mixed, or unknown.
- Decision: approve, conditionally approve, reject, or insufficient evidence.
- Top risks: focused on MCP-specific failure modes, not generic security boilerplate.
- Control map: each major recommendation tied to OWASP-derived guidance, internal `Req ID`, or both.
- Evidence gaps: specific missing artifacts needed to close the review.
- Human approval points: security reviewer, domain owner, approver, operator/asset owner.

Do not produce an approval if:

- Origin is unknown or unverified.
- Tool manifest is not reviewable.
- The server requires broad filesystem/network/secrets access without sandboxing and justification.
- Authentication or token audience validation is unknown for remote/internal deployments.
- The server handles non-public data without a risk assessment and data protection controls.
- There is no owner/operator or no monitoring/kill-switch plan for production use.

## Review report skeleton

Use the packaged `templates/review-report-template.md` for a full report. For a concise response, use this shape:

```markdown
# MCP Server Security Review

## Decision
[Approve / Conditional approval / Reject / Insufficient evidence]

## Classification
- Server relationship: [third_party_consumed / internal_proxy_built / internal_proxy_consumes_third_party / unknown]
- Deployment pattern: [local_stdio / remote_streamable_http / mixed / unknown]
- Data/action risk: [summary]

## Key Findings
| Severity | Finding | Source basis | Evidence | Required action |
|---|---|---|---|---|
| High | ... | OWASP third-party guidance; Req ID ... | ... | ... |

## Requirement Traceability
| Req ID | Applicability | Status | Evidence / gap |
|---|---|---|---|
| 1.01 | Applicable | Gap | ... |

## Third-Party Consumption Controls
| Control | Status | Evidence / gap |
|---|---|---|
| Origin verification | ... | ... |

## Required Approval Gates
- Security reviewer: ...
- Domain owner: ...
- Approver: ...
- Operator / asset owner: ...
```

## Quick prompts for agents

Use these prompt frames when applying the skill.

### Intake triage

```text
Classify this MCP server review using the MCP Server Design Requirements Skill. Determine whether it is third-party, internal proxy, or combined; identify deployment pattern; list missing facts; then produce the minimum evidence checklist needed before approval.
```

### Design review

```text
Review this MCP proxy server design against the internal requirement catalog. Preserve exact requirement wording when quoting. Cite requirements by Req ID. Also apply third-party consumption controls if the design consumes external MCP servers, packages, tools, or APIs.
```

### Production readiness

```text
Assess production readiness for this MCP server. Map findings to design, build, implementation, and operations requirement groups; include OWASP third-party controls for discovery, verification, sandboxing, auth, monitoring, and governance where applicable.
```
