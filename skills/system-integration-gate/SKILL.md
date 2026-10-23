---
name: system-integration-gate
description: Prevents "built but not wired" regressions by enforcing composition-root ownership, an Architect approval gate for runtime-service changes, and before/after smoke checks. Load when Planner plans composition-root changes; Architect reviews plans tagged ARCH-REQUIRED; Critic enforces the Architect gate on any plan touching runtime services; Implementer adds/modifies runtime services; DevOps packages or deploys products.
metadata:
  version: "1.0"
---

# system-integration-gate

## Purpose

Prevent "built but not invoked" regressions by enforcing system-level integration ownership in plans, establishing an Architect approval gate for composition-root changes, and requiring before/after smoke checks to ensure deployed artifacts remain runnable.

## When to Load

Load this skill when:
- **Planner**: Planning any feature that touches runtime services, composition roots, or deployable artifacts.
- **Architect**: Reviewing plans tagged `[ARCH-REQUIRED]` or marked `Architect_Review_Required: true`.
- **Critic**: Reviewing any plan; use the checklist to enforce composition-root completeness.
- **Implementer**: Adding or modifying runtime services; ensure TASK-COMPOSE-* and E2E acceptance are in the plan.
- **DevOps**: Packaging or deploying products; enforce smoke-check baseline before and after changes.

## Problem Statement

Components can be built and thoroughly tested in isolation but never wired into the production process, leaving critical behavior missing at runtime. Unit/integration tests may pass while the system fails to start or function. Example: a service layer was implemented with full conformance tests, but the production startup never instantiated it—discovered only at live-gate time.

## Core Definitions

### Composition-Root Non-Trivial (Triggers Architect Review)

A plan is **composition-root non-trivial** if it:
- Adds or modifies runtime services (any component instantiated in a production process).
- Changes the composition root or service wiring in any entrypoint.
- Modifies process startup behavior or initialization order.
- Introduces new deployable artifacts or changes artifact structure.
- Affects environment variables (`LD_LIBRARY_PATH`, `PATH`, etc.) or runtime configuration affecting multiple services.

**Trivial plans** (no Architect gate required): bugfixes to isolated functions, documentation, test-only changes, or changes to development scripts that do not affect deployed artifacts.

### TASK-COMPOSE-* (Composition Task)

Explicit task owned by an implementer that:
- Wires the component into the real production entrypoint (e.g., startup, composition root, factory).
- Does NOT instantiate the component only in tests; tests verify implementations, not wiring.
- Has acceptance criteria that run the deployed binary/config (same as release).
- Includes before/after smoke checks (see Smoke-Bracket Invariant below).

### Smoke-Bracket Invariant

Before any phase of composition-root non-trivial work begins, capture a baseline smoke check (app starts, key services visible in logs). After the phase completes, re-run the identical check. A phase is not done until after-state >= before-state. If after-state < before-state, the phase has introduced a regression.

## Architect Approval Gate Rules

### When Required
Plans marked as composition-root non-trivial MUST receive Architect review **before** Critic review.

### Plan Tags
**Planner** must mark composition-root non-trivial plans with:
- Title label: `[ARCH-REQUIRED]` in the plan ID or title, OR
- Frontmatter field: `Architect_Review_Required: true`

### Architect Checklist
Architect MUST verify and approve the following before handing off to Critic:

- [ ] **Composition Root Ownership**: Plan explicitly names the production entrypoint (e.g., `MyService.cpp`, `launch script`, service factory, process `main()`).
- [ ] **TASK-COMPOSE-* Present**: At least one composition task exists; wires components into the real entrypoint, not a test harness.
- [ ] **Acceptance Criteria (Real Entrypoint)**: Composition task acceptance criteria run the deployed artifact (same binary, same config as release) and assert service startup messages in logs (e.g., service startup confirmation within 60s).
- [ ] **Failure Modes Defined**: Plan includes FM entries:
  - `FM-COMPONENT-NOT-INVOKED`: component built, tests pass, but not instantiated in production.
  - `FM-SYSTEM-START-FAIL`: process fails to start due to missing wiring, bad config, missing library, or initialization error.
- [ ] **Real-Entrypoint E2E**: Plan includes at least one E2E test that starts the deployed binary and performs a minimal round-trip (e.g., client/server handshake, data plane request/response). Test runs the actual binary and config, not a mock.

**Verdict**: Architect approves only if all items above are present and credible. If missing, reject with specific guidance (e.g., "TASK-COMPOSE-001 is missing; add it wiring X into Y").

### Critic Checklist
Critic MUST enforce the Architect gate:

- [ ] **Architect Approval**: If plan is marked `[ARCH-REQUIRED]` or `Architect_Review_Required: true`, verify Architect has reviewed and approved. If not, reject with "Awaiting Architect approval."
- [ ] **Trivial Exemption**: If Architect has explicitly exempted the plan as trivial (e.g., "this is a dev-script change, no Architect gate needed"), Critic proceeds. Otherwise, Architect gate is mandatory.
- [ ] **Smoke-Bracket Invariant**: Plan includes a Definition-of-Done entry requiring before/after smoke checks for runtime changes. If missing, reject or request addition.
- [ ] **Completeness**: If plan is NOT marked `[ARCH-REQUIRED]` but Critic detects composition-root or entrypoint changes, route back to Planner with: "This plan touches [specific entrypoint]. Re-tag as `[ARCH-REQUIRED]` and route to Architect."

## Smoke-Bracket Invariant (Orchestration & DevOps)

### Definition
A smoke check is a minimal oracle confirming the deployed artifact (or entrypoint) still starts and runs. Before a phase of runtime changes, capture baseline smoke. After, re-run. Phase is not done until after-state >= before-state.

### OS-Agnostic smoke-check.sh Template

This template is designed to work on Linux, macOS, and Windows (with WSL or Git Bash). Adapt paths to your project structure. This is a copy of the canonical, tested script at `skills/system-integration-gate/smoke-check.sh` -- keep the two in sync.

```bash
#!/bin/bash
# smoke-check.sh -- verify production entrypoint still runs
# OS-agnostic smoke check for system-integration-gate
#
# Usage: ./smoke-check.sh [start|check] [--timeout 60]
#
# Environment variables (optional, override defaults):
#   SMOKE_ENTRYPOINT    Path to launch script (default: ./go release)
#   SMOKE_LOG_FILE      Log file to inspect (default: ./release_env/log/global_stdout_stderr.log)
#   SMOKE_TIMEOUT       Max seconds to wait (default: 60)
#   SMOKE_PATTERNS      Space-separated grep patterns to match in logs
#                       (default: "Service started")
#
# Returns: 0 if healthy, non-zero on failure
# Exit codes:
#   0  Success
#   1  Missing log file or pattern not found
#   2  Launch script not found
#   3  Invalid command

set -e

# Defaults
SMOKE_ENTRYPOINT="${SMOKE_ENTRYPOINT:-.}"
SMOKE_LOG_FILE="${SMOKE_LOG_FILE:-./release_env/log/global_stdout_stderr.log}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-60}"
SMOKE_PATTERNS="${SMOKE_PATTERNS:-Service started}"

# Helper functions
usage() {
  echo "Usage: $0 [start|check] [--timeout SECONDS]"
  echo "Commands:"
  echo "  start    Start the application (background)"
  echo "  check    Verify application health from logs"
}

log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

check_logs() {
  local pattern="$1"
  local log_file="$2"

  if [ ! -f "$log_file" ]; then
    log_error "Log file not found: $log_file"
    return 1
  fi

  if tail -120 "$log_file" 2>/dev/null | grep -q "$pattern"; then
    log_info "Pattern found: $pattern"
    return 0
  else
    log_error "Pattern not found: $pattern"
    return 1
  fi
}

# Parse command
main() {
  local COMMAND="${1:-check}"

  case "$COMMAND" in
    start)
      log_info "Starting application from: $SMOKE_ENTRYPOINT"
      if [ -d "$SMOKE_ENTRYPOINT" ]; then
        cd "$SMOKE_ENTRYPOINT"
      fi

      # Start the entrypoint (e.g., ./go release). Adjust for your launch script.
      if [ -f "./go" ]; then
        timeout "$SMOKE_TIMEOUT" ./go release 2>&1 | tee -a "$SMOKE_LOG_FILE" &
        log_info "Application started (PID: $!)"
        sleep 2
      elif [ -f "./go.ps1" ]; then
        timeout "$SMOKE_TIMEOUT" powershell -File "./go.ps1" release 2>&1 | tee -a "$SMOKE_LOG_FILE" &
        log_info "Application started (PID: $!)"
        sleep 2
      else
        log_error "Launch script not found (expected ./go or ./go.ps1)"
        return 2
      fi
      ;;

    check)
      log_info "Checking application health from: $SMOKE_LOG_FILE"

      local failed=0
      for pattern in $SMOKE_PATTERNS; do
        log_info "Checking pattern: $pattern"
        if ! check_logs "$pattern" "$SMOKE_LOG_FILE"; then
          failed=$((failed + 1))
        fi
      done

      if [ $failed -eq 0 ]; then
        log_info "PASS: All health checks passed"
        return 0
      else
        log_error "FAIL: $failed health check(s) failed"
        return 1
      fi
      ;;

    *)
      usage
      return 3
      ;;
  esac
}

main "$@"
exit $?
```

**Customization for your project**:

Before using, set environment variables or edit defaults:

```bash
# Example: for a Python-based service
export SMOKE_ENTRYPOINT="./python_service"
export SMOKE_LOG_FILE="./logs/service.log"
export SMOKE_PATTERNS="service initialized" "listening on port"
./smoke-check.sh start
./smoke-check.sh check

# Example: for a Node.js service
export SMOKE_ENTRYPOINT="."
export SMOKE_LOG_FILE="./logs/app.log"
export SMOKE_PATTERNS="Server started" "Database connected"
./smoke-check.sh start
./smoke-check.sh check
```

### Implementer Obligation (TASK-COMPOSE-* Acceptance)

Acceptance criteria for any TASK-COMPOSE-* must include:

1. **Before Smoke**: Run `./smoke-check.sh check` before making changes; log the baseline (or confirm "no log exists yet").
2. **Make Changes**: Wire the component into the entrypoint.
3. **Rebuild**: Rebuild products using your build system.
4. **After Smoke**: Run `./smoke-check.sh check` after rebuild; confirm all services/patterns present and startup succeeds.
5. **Real-Entrypoint E2E**: Run one client/server round-trip (or equivalent integration test) and verify exchange completes.

Acceptance is not satisfied unless all smoke checks pass and the E2E round-trip succeeds.

## Failure Mode Classes (Required in Plans)

All composition-root non-trivial plans MUST include these FM entries (or explicitly state "N/A"):

| FM ID | Failure Description | Mitigation / Test Obligation |
|-------|---------------------|------------------------------|
| FM-COMPONENT-NOT-INVOKED | Component built, unit/integration tests pass, but composition root does not instantiate it in production. Result: feature is missing at runtime. | **TASK-COMPOSE-*** wires into real entrypoint; real-entrypoint E2E test verifies behavior is present; Smoke-Bracket baseline confirms startup. |
| FM-SYSTEM-START-FAIL | Process fails on startup (exit code != 0) due to missing wiring, bad config, missing library, or initialization error. | Before/after smoke check (TASK-COMPOSE-* acceptance); linking checks; config validation. |

## Planner Responsibilities

When planning a composition-root non-trivial change:

1. **Detect**: Identify if plan touches runtime services, entrypoints, or deployable artifacts.
2. **Tag**: Add `Architect_Review_Required: true` to frontmatter or `[ARCH-REQUIRED]` to title.
3. **Include FM entries**: Add `FM-COMPONENT-NOT-INVOKED` and `FM-SYSTEM-START-FAIL` to the Failures section (or state "N/A" with justification).
4. **Add TASK-COMPOSE-***: At least one composition task, with real-entrypoint acceptance criteria (start the binary, verify service logs, run E2E).
5. **Smoke-Bracket DoD**: Add to Definition-of-Done: "Before/after smoke checks pass; after-state >= before-state."
6. **Handoff to Architect first**: Do not send to Critic until Architect has approved (or exempted as trivial).

## Critic Responsibilities

When reviewing a composition-root non-trivial plan:

1. **Verify Architect Approval**: Check frontmatter `Architect_Approved: true` and date; reject if missing.
2. **Enforce Composition Task**: Confirm TASK-COMPOSE-* entries exist with real-entrypoint acceptance.
3. **Check FM**: Verify FM-COMPONENT-NOT-INVOKED and FM-SYSTEM-START-FAIL are present.
4. **Smoke-Bracket DoD**: Confirm Definition-of-Done includes smoke-check baseline requirement.
5. **Redirect if Missed**: If plan touches entrypoints but is not tagged `[ARCH-REQUIRED]`, reject and request re-tag and Architect routing.

## Implementer Responsibilities

When implementing a composition-root non-trivial plan:

1. **Wire into Real Entrypoint**: Do not create a test-only or temporary wiring; use the production entrypoint.
2. **Run Smoke-Bracket Checks**: Before starting work, run `./smoke-check.sh check`; after rebuild, re-run; confirm after-state >= before-state.
3. **Execute Real-Entrypoint E2E**: Run the E2E test (see plan for specifics) and verify a client/server exchange completes.
4. **Log Acceptance Evidence**: Include smoke-check output and E2E test logs in the implementation artifact (handoff to Code Reviewer or QA).

## DevOps Responsibilities

When packaging or deploying:

1. **Add Smoke-Stage to CI** (optional, for automation):
   - After product build: run `./smoke-check.sh start && ./smoke-check.sh check` in a headless/containerized environment.
   - Assert startup completes within 60s and all patterns appear in logs.
   - Fail the build if smoke fails.

2. **Linking/Packaging Checks** (option, low friction):
   - On Linux: run `ldd` on key runtime libraries and verify all needed symbols resolve.
   - On all platforms: check that packaging rules include all necessary artifacts (e.g., sonames, config files, locale data).

## Example: Service Integration Incident

**Incident**: A reader service was implemented with full unit/integration tests, but the production startup never instantiated it. Discovered at live-gate.

**Root Cause**: No explicit task owned composition-root wiring; acceptance criteria were test-scoped, not production-scoped.

**Remedy Applied**:
- Added `TASK-COMPOSE-001` to wire the service into the production startup.
- Updated startup config to enable the service.
- Acceptance: start the entrypoint, verify service startup message in logs, run real-entrypoint E2E test.
- Smoke-Bracket: baseline smoke (before) confirmed startup succeeded; after composition task, smoke confirmed service present.

**Prevention**: Plans adding runtime services now require Architect approval, explicit FM-COMPONENT-NOT-INVOKED entry, TASK-COMPOSE-* in plan, and real-entrypoint E2E in acceptance criteria.

## Guidance & Examples

### Q: How do I define "SMOKE_PATTERNS"?

**A:** Choose patterns that confirm critical services/subsystems have started. Examples:

- For a web server: `"Listening on port 8080"` or `"HTTP server started"`
- For a message queue client: `"Connected to broker"` or `"Consumer registered"`
- For a multi-service app: `"Service A initialized" "Service B ready" "Service C online"`

Keep patterns broad enough to avoid false failures (e.g., avoid timestamps), but specific enough to confirm the intended behavior.

### Q: Can I run smoke-check on Windows?

**A:** Yes. The template uses bash (via Git Bash, WSL, or native bash on modern Windows). Ensure your entrypoint script is compatible. If using PowerShell, translate the script to PowerShell syntax (conditionally: `if ($? -eq $false) { return 1 }`).

### Q: What if my entrypoint doesn't produce logs?

**A:** Adapt the `check` command to inspect something else:
- Process list: `ps aux | grep MyService` (or `tasklist /FI "IMAGENAME eq MyService.exe"` on Windows).
- Network port: `netstat -tuln | grep 8080` (or equivalent platform command).
- Health endpoint: `curl http://localhost:8080/health 2>/dev/null` (if available).

### Q: How do I integrate smoke-check into CI?

**A:** Add a stage after your product build:

```yaml
# Example GitLab CI / GitHub Actions pattern
smoke_test:
  script:
    - ./smoke-check.sh start
    - sleep 5
    - ./smoke-check.sh check
  on_failure: |
    tail -200 ./release_env/log/global_stdout_stderr.log
```

---

## References & Cross-Links

- **Skill**: `deep-modules` — ensures service APIs and wiring boundaries are minimal and auditable.
- **Skill**: `testing-patterns` — complements this skill by requiring E2E tests against real entrypoints.
- **Skill**: `execution-orchestration` — applies Smoke-Bracket invariant as part of phase Definition-of-Done.
- **Plan Template**: Include `Architect_Review_Required` frontmatter and FM section; reference this skill for composition-root non-trivial detection.
