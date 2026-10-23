# Runtime-Zone Specifics (project-specific lean-design content)

**Pull-not-push reference for `lean-design`.** Load when the project involves a regulated runtime, DDS middleware, audit ledgers, plan-doc ceremony, or hardware calibration requirements. The general `lean-design` SKILL.md describes the general zones, ladder, and guardrails; this file layers on project-specific rules.

---

## Regulated-runtime zone rules

In a two-zone regulated-software codebase (e.g. a regulated medical-device or avionics platform):

- **Runtime / contract zone** — regulated runtime, anything on a wire / schema / IPC boundary, or an audit / traceability surface. Correctness and evidence lead. The ladder trims code volume only; it never decides whether a guarantee exists.
- **Tooling zone** — MCP servers, plan docs, the test harness, the skills themselves. Over-build is the default failure here. Cut hard.

The zone argument `/lean tooling|runtime` forces the zone when context is ambiguous.

## DDS QoS guardrail

In systems using DDS middleware, the QoS durability / reliability / liveliness a contract requires, teardown ordering, and durability-collision avoidance are **correctness**, not generality. Never simplify these away. They belong under the "Contract / backcompat" guardrail of the general skill — but the mechanism is DDS-specific.

Pattern: verify QoS profile against the SDS/IDS contract before trimming any transport layer.

## Audit dossiers and verification evidence

In regulated development (e.g. IEC 62304 for medical-device software):

- **Validation dossiers** — the lifecycle artifacts the regulated path requires (test protocols, verification reports, SDLC deliverables). Mandatory, not bloat.
- **Verification evidence** — software test reports, code review records, IQ/OQ. Never dropped to save lines.

## Plan-doc ceremony

Lean applies to plan docs too — the "tooling zone" rule applies. Sections with no content, decisions that constrain no label, ADRs for uncontested choices, OPEN QUESTIONs already resolved → skip or close. The `document-lifecycle` skill governs closure procedures.

`DEFER-<id>` labels are the lean intent marker for plan-doc deferrals.

## Hardware calibration guardrail

In embedded / hardware-adjacent systems: **leave the knob.** A clock drifts, a sensor reads off, a PWM driver runs a few percent fast; the physical world needs tuning a minimal software model cannot see. Never remove a calibration parameter to tighten the API. This belongs under the "Contract / backcompat" guardrail — but the failure mode is physical-world drift, not schema change.

## Spec-substrate projects

Where a project declares a capability admission ladder for new capability (e.g. example-mcp's ADR-EXAMPLEMCP-032), that ladder **replaces** this skill's general reflex ladder for new-capability decisions — do not run both. The general ladder is a reflex: two rungs work, take the higher one and move on. A capability admission ladder is the opposite by design: it is a **research procedure with artifacts**, walked in order, and each rung must produce a reproducible artifact (a spec fragment, validator output, a test run, or a quoted `path:line`) before the next rung is attempted. A claim without an artifact counts as not done, and stopping early on a bare assertion is a violation of the ladder, not a lean win.

The zone gate above still applies to _how hard_ the surrounding code is cut once a rung's outcome is settled; it does not shortcut which rung the capability lands on.
