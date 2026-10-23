#!/usr/bin/env bash
# quick-diagnostic.sh
#
# Non-destructive diagnostic for the NDI optical tracking camera on a Stealth Axis
# (Juno / Mazor X / S7 / S8) development box. Walks through the cheap checks in the
# order recommended by skills/optical-camera-diagnostics/SKILL.md and prints PASS / WARN /
# FAIL with a next-step hint after each check.
#
# Exit codes:
#   0  all checks PASS or only WARN
#   1  at least one check FAILed (see first [FAIL] line for routing)
#   2  script could not run (missing 'ip', not Linux, etc.)
#
# Usage:
#   bash skills/optical-camera-diagnostics/scripts/quick-diagnostic.sh
#
# This script never modifies system state. It only reads.

set -u

# ---- formatting ----------------------------------------------------------------
if [ -t 1 ]; then
    C_PASS=$'\033[32m'
    C_WARN=$'\033[33m'
    C_FAIL=$'\033[31m'
    C_BOLD=$'\033[1m'
    C_OFF=$'\033[0m'
else
    C_PASS=""; C_WARN=""; C_FAIL=""; C_BOLD=""; C_OFF=""
fi

FAIL_COUNT=0
FIRST_FAIL=""

pass() { printf "  %s[PASS]%s %s\n" "$C_PASS" "$C_OFF" "$1"; }
warn() { printf "  %s[WARN]%s %s\n     -> %s\n" "$C_WARN" "$C_OFF" "$1" "$2"; }
fail() {
    printf "  %s[FAIL]%s %s\n     -> %s\n" "$C_FAIL" "$C_OFF" "$1" "$2"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    if [ -z "$FIRST_FAIL" ]; then FIRST_FAIL="$1"; fi
}
section() { printf "\n%s%s%s\n" "$C_BOLD" "$1" "$C_OFF"; }

# ---- environment guard ---------------------------------------------------------
if [ "$(uname -s)" != "Linux" ]; then
    printf "This diagnostic targets the Juno / Mazor / S7 / S8 Linux dev box.\n" >&2
    printf "Detected platform: %s -- exiting.\n" "$(uname -s)" >&2
    exit 2
fi

if ! command -v ip >/dev/null 2>&1; then
    printf "'ip' command not found; cannot inspect network adapters. Exiting.\n" >&2
    exit 2
fi

printf "%sNDI Optical Camera -- Quick Diagnostic%s\n" "$C_BOLD" "$C_OFF"
printf "Source: skills/optical-camera-diagnostics/SKILL.md\n"
printf "Host:   %s   Date: %s\n" "$(hostname)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- 1. ping psu ---------------------------------------------------------------
section "1. Camera reachability ('ping psu')"
if command -v ping >/dev/null 2>&1; then
    if ping -c 1 -W 2 psu >/dev/null 2>&1; then
        pass "psu is reachable on the network"
    else
        fail "psu is NOT reachable" \
             "Go to SKILL.md Step 4 (Network reachability). Camera is likely on the wrong subnet or the dev box is missing its 192.168.59.0/24 static adapter."
    fi
else
    warn "'ping' not available" "Install iputils-ping or run the reachability check manually."
fi

# ---- 2. dev box network adapters ----------------------------------------------
section "2. Dev box network adapters ('ip addr')"
IP_OUT="$(ip -4 -o addr show 2>/dev/null || true)"

if printf "%s\n" "$IP_OUT" | grep -Eq '192\.168\.59\.[0-9]+/'; then
    STATIC_LINE="$(printf "%s\n" "$IP_OUT" | grep -E '192\.168\.59\.[0-9]+/' | head -n 1)"
    pass "Static adapter present on 192.168.59.0/24:  ${STATIC_LINE# *}"
else
    fail "No adapter found on 192.168.59.0/24" \
         "Go to SKILL.md Step 4. Default expected static IP is 192.168.59.100; camera expects 192.168.59.220."
fi

# Heuristic for a second (DHCP / internet) adapter: at least one non-loopback,
# non-59.x IPv4 address.
if printf "%s\n" "$IP_OUT" | grep -Ev '127\.0\.0\.1|192\.168\.59\.' | grep -Eq 'inet '; then
    pass "A second (DHCP / wall) adapter appears to be up"
else
    warn "No second adapter with a non-camera IPv4 address detected" \
         "Internet / wall access may be unavailable. Confirm DHCP on the second NIC if you need both."
fi

# ---- 3. required packages ------------------------------------------------------
section "3. Required mnav packages"
REQUIRED_PKGS="mnav-config-networking3-dev mnav-config-etchosts3 mnav-camera-firmware-compatibility"

if command -v dpkg-query >/dev/null 2>&1; then
    for pkg in $REQUIRED_PKGS; do
        STATUS="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
        if printf "%s" "$STATUS" | grep -q "install ok installed"; then
            pass "$pkg installed"
        else
            fail "$pkg NOT installed" \
                 "Install via your standard dev-package channel. See SKILL.md Step 7."
        fi
    done
else
    warn "dpkg-query not available" "Cannot verify packages on this distro. Confirm manually: $REQUIRED_PKGS"
fi

# ---- 4. NDI Toolbox binary -----------------------------------------------------
section "4. NDI Toolbox availability"
NDI_TOOLBOX="/opt/mnav/NDIToolBox/Configure"
if [ -x "$NDI_TOOLBOX" ]; then
    pass "NDI Toolbox present at $NDI_TOOLBOX"
elif [ -e "$NDI_TOOLBOX" ]; then
    warn "NDI Toolbox present but not executable" "chmod +x $NDI_TOOLBOX or reinstall."
else
    fail "NDI Toolbox not found at $NDI_TOOLBOX" \
         "Install from code.medtronic.com/ET/ns/NDIToolBox or update to OS 3.0.0-55+. See SKILL.md Step 5."
fi

# ---- 5. firmware compatibility file -------------------------------------------
section "5. Firmware compatibility file"
FW_FILE="/opt/mnav/share/camera-firmware-compatibility/stealthapplication.d/ndi_vega.fw"
if [ -r "$FW_FILE" ]; then
    pass "Firmware compat file present: $FW_FILE"
    if command -v grep >/dev/null 2>&1; then
        REVS="$(grep -oE '"[0-9]{3}"' "$FW_FILE" | tr -d '"' | sort -u | tr '\n' ' ')"
        if [ -n "$REVS" ]; then
            printf "         supported_ndi_combined_fw_revisions: %s\n" "$REVS"
        else
            warn "Could not parse firmware revisions from file" \
                 "Open $FW_FILE manually and confirm your camera's major firmware version is listed. See SKILL.md Step 6."
        fi
    fi
else
    fail "Firmware compat file missing or unreadable" \
         "Expected at $FW_FILE. Reinstall mnav-camera-firmware-compatibility. See SKILL.md Step 6."
fi

# ---- summary -------------------------------------------------------------------
section "Summary"
if [ "$FAIL_COUNT" -eq 0 ]; then
    printf "  %sAll checks passed (warnings, if any, are advisory).%s\n" "$C_PASS" "$C_OFF"
    printf "  Next: launch the clinical app, select a Spine procedure, confirm tracking in the camera aimer (SKILL.md Step 2).\n"
    exit 0
else
    printf "  %s%d check(s) FAILED.%s\n" "$C_FAIL" "$FAIL_COUNT" "$C_OFF"
    printf "  First failure: %s\n" "$FIRST_FAIL"
    printf "  Routing table: see SKILL.md Step 3 to find the matching follow-up step.\n"
    printf "  Deep-dive scenarios: skills/optical-camera-diagnostics/references/troubleshooting.md\n"
    exit 1
fi
