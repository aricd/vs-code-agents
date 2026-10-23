---
name: security-patterns
description: Security vulnerability detection patterns, project review methodology, and language-specific vulnerability references. Load when reviewing code for security issues, conducting audits, or implementing authentication/authorization.
metadata:
  version: "1.1"
---

# Security Patterns

Systematic approach to identifying and remediating security vulnerabilities. Use this skill when:
- Reviewing code for security vulnerabilities
- Conducting security audits
- Implementing authentication, authorization, or data handling
- Assessing third-party dependencies

---

## Core Security Principles

| Principle | Application |
|-----------|-------------|
| **CIA Triad** | Confidentiality, Integrity, Availability in every assessment |
| **Defense in Depth** | Multiple layers; never rely on single control |
| **Least Privilege** | Minimum permissions for every component |
| **Secure by Default** | Default configurations must be secure |
| **Zero Trust** | Never trust, always verify — even internal traffic |
| **Shift Left** | Catch issues early in planning/design, not production |
| **Assume Breach** | Design with assumption attackers are already inside |

---

## Security Review Phases

| Phase | Focus | Key Checks | Output |
|-------|-------|-----------|--------|
| **Phase 1: Architectural** | System design weaknesses | Trust boundaries, STRIDE threat model, attack surface | `*-architecture-security.md` |
| **Phase 2: Code** | Implementation vulnerabilities | OWASP Top 10, language-specific patterns, auth/authz | `*-code-audit.md` |
| **Phase 3: Dependencies** | Supply chain risks | Vulnerability scanning, lockfiles, abandoned packages | `*-dependency-audit.md` |
| **Phase 4: Infrastructure** | Config and hardening | Security headers, TLS, container/cloud config | (included in audit) |
| **Phase 5: Compliance** | Regulatory requirements | OWASP ASVS, NIST, CIS Controls | (compliance mapping) |

**Automated checks** (via `security-patterns` skill scripts):
- `security-scan.sh` — Aggregated scanner (gitleaks, semgrep, npm audit, osv-scanner)
- `check-secrets.sh` — Lightweight secret detection
- `check-dependencies.sh` — Multi-ecosystem vulnerability check

**Full methodology details**: `security-patterns/references/security-methodology.md`

---

## Language-Specific Patterns

See detailed references:
- [references/javascript-vulnerabilities.md](references/javascript-vulnerabilities.md)
- [references/python-vulnerabilities.md](references/python-vulnerabilities.md)
- [references/java-vulnerabilities.md](references/java-vulnerabilities.md)
- [references/go-vulnerabilities.md](references/go-vulnerabilities.md)

---
