# Smoke-Check Violation Fixtures

Fixtures for manually verifying the extended smoke-test checks (c) and (d).

## Usage

To confirm a check fires on a violation, **temporarily** copy the fixture into the
live tree, run `make verify` (or `pwsh scripts/smoke-test-plugin.ps1`), verify the
expected FAIL output, then **remove** the fixture and confirm `make verify` returns
to green.

| Fixture file | Check triggered | How to inject |
|---|---|---|
| `missing-frontmatter/SKILL.md` | (a) missing frontmatter | Copy dir to `skills/test-missing-frontmatter/` |
| `name-mismatch/SKILL.md` | (b) dir != name field | Copy dir to `skills/test-name-mismatch/` |
| `crlf-frontmatter/SKILL.md` | (b) name mismatch via CRLF file | Copy dir to `skills/test-crlf-frontmatter/` |
| `bom-frontmatter/SKILL.md` | (e) UTF-8 BOM guard | Copy dir to `skills/test-bom-frontmatter/` |
| `dangling-ref.agent.md` | (c) dangling skill reference | Copy to `agents/test-dangling-ref.agent.md` |
| `duplicate-ordinal.agent.md` | (d) duplicate ordinal in list | Copy to `agents/test-duplicate-ordinal.agent.md` |
| `multilist-no-dup.agent.md` | (negative guard — must NOT fire) | Copy to `agents/test-multilist-no-dup.agent.md` |

## CRLF Note

`crlf-frontmatter/SKILL.md` uses CRLF (`\r\n`) line endings to validate that the
CRLF-safe parsing path is exercised.  The `.gitattributes` file marks it
`text eol=crlf` so git does not strip the carriage returns on checkout.

## BOM Note

`bom-frontmatter/SKILL.md` carries a leading UTF-8 BOM (`EF BB BF`) to validate
check (e), the BOM guard added in Plan 006 QA-DEF-001 fix.  The `.gitattributes`
file marks it `-text` (binary-equivalent) so git does not strip or rewrite the BOM
bytes on checkout.  Both `smoke-test-plugin.sh` and `smoke-test-plugin.ps1` must
FAIL with a "starts with UTF-8 BOM" message when this fixture is injected.

## SEC-001

All fixtures are **read-only** examples — the smoke test never executes or evals
repo content.
