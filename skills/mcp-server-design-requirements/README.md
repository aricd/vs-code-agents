# MCP Server Security Core Skill

This package combines two MCP security source lenses into one agent skill:

1. OWASP GenAI Security Project guidance for securely using third-party MCP servers.
2. Internal MCP Proxy Server Security Requirements, organized by `req_id` for design, build, implementation, and operations.

## Files

- `SKILL.md` - the core skill to install/use.
- `references/owasp-third-party-mcp-server-security-skill.md` - text-only source adaptation of the OWASP third-party MCP guide.
- `references/owasp-third-party-mcp-source-raw-layout.txt` - raw PDF text extraction retained for traceability.
- `references/proxy-server-security-requirements-source.md` - exact internal requirement reference.
- `references/proxy-requirement-catalog.yaml` - extracted YAML catalog.
- `references/security-control-crosswalk.md` - practical topic-to-source control map.
- `templates/review-report-template.md` - reusable report template.

## Usage

Use `SKILL.md` as the root skill file. Keep the `references/` folder with the skill so agents can quote exact source material and preserve requirement traceability.

When quoting internal requirements, preserve exact wording and cite by `Req ID`.
