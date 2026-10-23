# system-integration-gate Skill

Prevent "built but not invoked" regressions with mandatory Architect approval for composition-root changes and before/after smoke checks.

## Files

- **SKILL.md** — Full skill documentation, checklists, and guidance.
- **smoke-check.sh** — OS-agnostic reference implementation of the smoke-check oracle.
- **README.md** — This file.

## Quick Start

### 1. Copy smoke-check.sh to your project

```bash
# From this skill directory
cp smoke-check.sh /path/to/your/project/scripts/
chmod +x /path/to/your/project/scripts/smoke-check.sh
```

### 2. Customize for your entrypoint

Edit your project's `smoke-check.sh` to point to your actual entrypoint and expected patterns:

```bash
# Example: for a Python-based service
export SMOKE_ENTRYPOINT="./python_app"
export SMOKE_LOG_FILE="./logs/service.log"
export SMOKE_PATTERNS="Service initialized" "Listening on 0.0.0.0:8080"

# Example: for a Node.js + database
export SMOKE_LOG_FILE="./logs/app.log"
export SMOKE_PATTERNS="Server started" "Database connected"
```

### 3. Use in your plan (as Planner)

When planning a feature that adds/modifies runtime services:

```markdown
---
ID: 123
Architect_Review_Required: true
---

## 1. Value Statement and Business Objective
...

## ...

## 5. Failures
- FM-COMPONENT-NOT-INVOKED: Service X built and tested, but not invoked in production.
- FM-SYSTEM-START-FAIL: Startup fails due to missing wiring or config.

## 7. Implementation Plan (Phases)

### Phase 1: Wire into Production Entrypoint (GOAL-001)

**TASK-COMPOSE-001: Integrate Service X into startup**
- Owner: Implementer
- Wire Service X into `ProductionEntrypoint.cpp`
- Update config to enable Service X
- Acceptance Criteria:
  - Before: `./scripts/smoke-check.sh check` baseline passes
  - After rebuild: `./scripts/smoke-check.sh check` all patterns present
  - Real-entrypoint E2E: run `client_test.py` and observe Service X handshake

...

## 14. Smoke-Bracket Invariant
- All runtime changes must maintain before/after smoke baseline
- Implementer runs `./smoke-check.sh check` before + after each TASK-COMPOSE-*
- Phase done when after-state >= before-state
```

### 4. Critic enforces the gate

Critic checks:
- [ ] Is this plan tagged `Architect_Review_Required: true`?
- [ ] Does Architect_Approved field have a date?
- [ ] Do FM-COMPONENT-NOT-INVOKED and FM-SYSTEM-START-FAIL entries exist?
- [ ] Is there a TASK-COMPOSE-* with real-entrypoint acceptance?

### 5. Implementer uses smoke-check

```bash
# Before: capture baseline
./scripts/smoke-check.sh check > baseline.txt 2>&1

# Make changes, rebuild...

# After: confirm no regression
./scripts/smoke-check.sh check

# Run real-entrypoint E2E
python client_test.py

# Accept only if all green
```

## Platform Support

- **Linux**: native bash, all features
- **macOS**: native bash, all features
- **Windows**: Git Bash or WSL (no native bash on cmd.exe; use WSL or PowerShell variant)

## Customization Examples

### Python Flask service

```bash
export SMOKE_ENTRYPOINT="."
export SMOKE_LOG_FILE="./logs/flask.log"
export SMOKE_PATTERNS="WARNING in app.run" "Running on"
./scripts/smoke-check.sh start
./scripts/smoke-check.sh check
```

### Java/Spring Boot

```bash
export SMOKE_LOG_FILE="./build/app.log"
export SMOKE_PATTERNS="Started Application" "Listening on port"
./scripts/smoke-check.sh check
```

### Docker-based service

```bash
# Inside the container:
export SMOKE_ENTRYPOINT="/app"
export SMOKE_LOG_FILE="/app/logs/service.log"
export SMOKE_PATTERNS="Service ready"
/app/scripts/smoke-check.sh start && /app/scripts/smoke-check.sh check
```

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Smoke Check (Before)
  run: |
    cd ${{ github.workspace }}
    export SMOKE_PATTERNS="Service initialized"
    ./scripts/smoke-check.sh check || echo "No baseline yet (OK for first run)"

- name: Build
  run: ./build.sh

- name: Smoke Check (After)
  run: |
    cd ${{ github.workspace }}
    export SMOKE_PATTERNS="Service initialized"
    ./scripts/smoke-check.sh start
    sleep 5
    ./scripts/smoke-check.sh check
```

### GitLab CI

```yaml
smoke_test:
  stage: test
  script:
    - export SMOKE_PATTERNS="Service initialized"
    - ./scripts/smoke-check.sh start
    - sleep 5
    - ./scripts/smoke-check.sh check
  artifacts:
    paths:
      - ./release_env/log/global_stdout_stderr.log
    when: on_failure
```

## Troubleshooting

### "Log file not found"

Check that:
1. Your entrypoint actually creates the log file.
2. The path in `SMOKE_LOG_FILE` is correct (relative to cwd or absolute).
3. The entrypoint is running and has time to write logs.

### "Pattern not found"

1. Verify the pattern matches the actual log output (case-sensitive).
2. Use `tail -200 <log-file>` to inspect actual log content.
3. Escape special characters: `".*Service.*ready.*"` → `".*Service.*ready.*"`.

### "Launch script not found"

1. Ensure `./go` (or your entrypoint script) exists and is executable.
2. Check working directory: `pwd` should be the project root.
3. Provide `SMOKE_ENTRYPOINT` override if needed.

### "Timeout reached"

1. Increase `SMOKE_TIMEOUT` if startup is slow: `export SMOKE_TIMEOUT=120`.
2. Check if the process is actually running: `ps aux | grep <process-name>`.
3. Review logs for startup errors.

## References

- **Skill Full Docs**: [SKILL.md](SKILL.md)
- **Example Retrospective**: [Plan 332 Retrospective]

---

**Last Updated**: 2026-06-16  
**Status**: Active
