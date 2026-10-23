# Validator Test Fixture — Allowed Content (should NOT be flagged)
#
# This file contains lines that the validate-no-archaeology validator MUST NOT flag.
# Used by TEST-002 to verify the validator ignores exempt/illustrative lines.

## CON-004: Illustrative examples (exempt)

Use a plan ID as an argument hint (e.g., plan 002) to reference documents.
The argument-hint value follows the format `plan 002` for backward lookup.

## CON-005: Legitimate domain vocabulary (exempt)

This skill evaluates the legacy term RCK as a proxy for caller knowledge.
The API is no longer the recommended approach — use the new interface instead.
The field was formerly optional; it is now required.
Previously, this was handled by the orchestrator directly.
This location is a legacy location, still supported for compatibility.

## Suppression marker (exempt)

This line contains per Plan 999 but is explicitly suppressed. <!-- archaeology-ok -->

## Plan-numbering in functional context (CON-003, exempt)

The .next-id file stores the next available plan ID integer for the numbering mechanism.
The argument-hint: "(e.g., plan 002)" example shows the format.
