# MCP Server Security Review Template

## 1. Decision

- Decision: `[Approve / Conditional approval / Reject / Insufficient evidence]`
- Rationale:
- Conditions before approval:

## 2. Classification

- Server relationship: `[third_party_consumed / internal_proxy_built / internal_proxy_consumes_third_party / unknown]`
- Deployment pattern: `[local_stdio / remote_streamable_http / mixed / unknown]`
- Environment: `[dev / staging / production / unknown]`
- Data classification:
- Tool effects:
- Identity model:

## 3. Scope and architecture

- MCP host/client/server topology:
- Tools exposed:
- Resources exposed:
- Prompts exposed:
- External systems/APIs reached:
- Storage/memory used:
- Trust boundaries:

## 4. Findings

| Severity | Finding | Evidence | Source basis | Required action | Owner |
|---|---|---|---|---|---|
| High |  |  | OWASP third-party guidance / Req ID ... |  |  |

## 5. Internal requirement traceability

Use for internal MCP proxy reviews or combined reviews.

| Req ID | Applicability | Status | Evidence / gap | Notes |
|---|---|---|---|---|
| 1.01 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.02 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.03 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.05 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.06 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.07 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.08 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.09 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.10 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.11 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.12 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 1.13 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 2.01-2.06 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 3.01-3.09 |  | `[Met / Partial / Gap / N/A]` |  |  |
| 4.01-4.11 |  | `[Met / Partial / Gap / N/A]` |  |  |

## 6. Third-party consumption controls

Use for third-party MCP server reviews or combined reviews.

| Control area | Status | Evidence / gap | Required action |
|---|---|---|---|
| Trusted discovery / approved registry |  |  |  |
| Origin verification / provenance |  |  |  |
| Full tool manifest transparency |  |  |  |
| Tool description and schema review |  |  |  |
| Version pinning / checksum / drift monitoring |  |  |  |
| Sandbox/container runtime |  |  |  |
| Filesystem/network/secrets restrictions |  |  |  |
| AuthN/AuthZ/scopes/token handling |  |  |  |
| HITL approval for high-impact actions |  |  |  |
| Staged rollout / telemetry / rollback |  |  |  |
| Periodic revalidation |  |  |  |

## 7. Approval gates

- Submitter / developer:
- Security reviewer:
- Domain owner:
- Approver:
- Operator / SRE:
- Asset owner:

## 8. Final recommendation

- Required before production:
- Required before broader rollout:
- Accepted residual risks:
- Next review trigger:
