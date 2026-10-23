---
name: optical-camera-diagnostics
description: Step-by-step diagnostics for the NDI optical tracking camera (Spectra / Vega / Vega VT) on a Stealth Axis (Juno / Mazor X / S7 / S8) development system. Covers a quick automated connectivity check, NDI Toolbox discovery, static IP configuration (192.168.59.220), firmware compatibility, and a playbook of known failure scenarios (no power, red light, bump/temperature sensor, firmware incompatible, single-NIC Mazor box, custom netplan). Load when the camera is not detected, the clinical app shows a camera warning banner, tracking is broken, or a new camera or dev box is being set up.
---

# Optical Camera Setup -- Stealth Axis System

This skill walks a developer step by step from "is the camera even reachable?" through to a fully discoverable, tracking-capable NDI optical camera on a Juno / Mazor X / S7 / S8 development box. It is designed to be invoked the moment a camera problem is suspected; do not jump ahead.

> **Prior wiki source**: `skills/optical-camera-diagnostics/notes.txt` (Erin Kearns, May 2024 + coworker notes on single-NIC setups). All steps below are derived from that source.

---

## When to load this skill

Load when any of the following is true:
- Clinical app shows a **red camera warning banner** (Camera Faulted, Firmware Incompatible, missing camera, etc.)
- `ping psu` fails from a dev box that previously worked
- NDI Toolbox cannot discover the camera
- Tracking is intermittent or tools do not appear in the camera aimer
- A new camera, new dev box, or new lab cube is being set up
- The user mentions "Spectra", "Vega", "Vega VT", "NDI Toolbox", "PoE switch", or "192.168.59.220"

If the user just wants application-level diagnostics unrelated to the camera, do **not** load this skill.

---

## Operating rules (read first)

1. **Walk steps in order.** Each step is cheap and rules out a class of failure. Do not skip ahead because a later step "feels closer to the symptom."
2. **Only one controlling connection to the camera at a time.** Close NDI Toolbox before launching the clinical app and vice-versa.
3. **Never check in the firmware-compatibility edits** described in Step 6. They are a local dev workaround only.
4. **Do not edit `/etc/netplan/*.yaml` directly on a long-lived box.** Prefer `mnav-admin-app-electron -> Network Settings -> Wired Network Settings` (mnav-network-manager >= 3.0.0-505). Direct netplan edits are temporary and are wiped on the next restart.
5. **Stop and report at the first hard failure.** Capture the exact command output, then continue with the matching scenario in [references/troubleshooting.md](./references/troubleshooting.md).

---

## Step 0 -- Identify the camera flavor

Ask the user (or read off the box) which camera is in front of them:

| Flavor       | Historical platform        | Notes                          |
|--------------|----------------------------|--------------------------------|
| **Spectra**  | StealthStation S7          | Works on Juno dev boxes        |
| **Vega**     | StealthStation S8, Mazor X | Works on Juno dev boxes        |
| **Vega VT**  | Juno (official)            | Firmware versions 7, 8, or 11  |

Also confirm: PoE switch is **802.3at** (not 802.3af). If the user is on a Mazor X dev box, the internal networking switch may already be powered -- no external PoE needed.

---

## Step 1 -- Physical / power sanity (no commands yet)

Have the user confirm, in order:

1. Camera is plugged into a **powered** PoE port (often colored green on the switch).
2. PoE switch is plugged into the dev box (Juno / Mazor X).
3. Within ~5 seconds of power, the camera **beeps once** and the front lights come on.
4. There is **no red light** on the front of the camera. (Exception: if the camera is configured for an SCU and you do not have one connected, a red light is expected -- see [references/troubleshooting.md](./references/troubleshooting.md).)

If any of 1-4 fails, jump to the matching entry in [references/troubleshooting.md](./references/troubleshooting.md) before proceeding.

---

## Step 2 -- Fast functional check (clinical app)

This is the happy-path validation. If it passes, you are done.

1. Start the clinical application.
2. Select a **Spine** procedure -- the camera should beep again.
3. Go to the **Instruments** task. There should be **no** red camera-warning banner and the camera entry should appear in the tool status list.
4. Open the camera aimer and present a **passive optical tool** (silver-ball reference). The tool should move in the aimer window.

If all four pass: stop, the camera is healthy.

If any fail: **close the clinical app** (frees the camera connection), then continue with Step 3.

---

## Step 3 -- Automated quick diagnostic

Run the bundled script. It is non-destructive and only inspects state.

```bash
bash skills/optical-camera-diagnostics/scripts/quick-diagnostic.sh
```

The script checks, in order:
1. `ping psu` reaches the camera at its hostname.
2. `ip addr` shows both a DHCP adapter (for internet) and a static-IP adapter in the `192.168.59.0/24` subnet.
3. Required packages are installed: `mnav-config-networking3-dev`, `mnav-config-etchosts3`, `mnav-camera-firmware-compatibility`.
4. NDI Toolbox is present at `/opt/mnav/NDIToolBox/Configure`.
5. Firmware compatibility file exists at `/opt/mnav/share/camera-firmware-compatibility/stealthapplication.d/ndi_vega.fw`.

Each check prints `[PASS]`, `[WARN]`, or `[FAIL]` with the next-step hint. Read the **first** `[FAIL]` and route to the matching step below:

| First failure                     | Go to                                |
|-----------------------------------|--------------------------------------|
| `ping psu` fails                  | Step 4 (network reachability)        |
| `ip addr` missing static adapter  | Step 4 (network reachability)        |
| Package missing                   | Step 7 (required packages)           |
| NDI Toolbox missing               | Step 5 (NDI Toolbox)                 |
| Firmware compat file missing/stale| Step 6 (firmware compatibility)      |

---

## Step 4 -- Network reachability

The dev box needs **two** network interfaces configured: one DHCP for the wall/internet, and one with a **static IP in `192.168.59.0/24`** (default: `192.168.59.100`) to talk to the camera. The camera needs a **static IP of `192.168.59.220`**.

VT cameras currently ship with **DHCP** enabled, so a brand-new camera will usually appear on `169.254.x.x` and must be reconfigured to the static `192.168.59.220` on first use.

Procedure summary (full detail in [references/troubleshooting.md](./references/troubleshooting.md) "Configuring the Camera Networking"):

1. Run `ip addr` -- confirm both adapters are present and configured.
2. Try `ping psu`. If it works, network is fine -- jump to Step 5.
3. If `psu` does not resolve / ping, open NDI Toolbox: `cd /opt/mnav/NDIToolBox && ./Configure`, then `File -> Connect To`, hover over the discovered serial number to read its current IP (likely `169.254.x.x`).
4. **Temporarily** change the dev box static IP to share the camera's subnet (e.g. camera at `169.254.10.190` -> dev box at `169.254.10.1`). Use `mnav-admin-app-electron -> Network Settings` if available; otherwise edit netplan and `sudo netplan apply` (changes wiped on restart, which is intentional).
5. Reconnect via NDI Toolbox, then in the settings tree set:
   - `Settings - Network - IP Method` = `Static IP`
   - `Settings - Network - Static - Gateway` = `192.168.59.1`
   - `Settings - Network - Static - IP Address` = `192.168.59.220`
6. `File -> Save Parameters`, unplug/replug the camera.
7. Restore the dev box static IP to `192.168.59.100`.
8. `ping psu` should now succeed.
9. **Close NDI Toolbox** before continuing -- the camera only allows one controlling connection.

For single-NIC Mazor / home-dev-box setups: see the "Single-NIC and custom netplan" section in [references/troubleshooting.md](./references/troubleshooting.md).

---

## Step 5 -- NDI Toolbox discovery

NDI Toolbox is a GUI app and **cannot** run from a headless SSH session.

```bash
cd /opt/mnav/NDIToolBox
./Configure
# File -> Connect To -> select your camera serial number
```

- If the camera does not appear in the list, the dev-box-to-camera network is wrong -- return to Step 4.
- If it appears but will not connect, hover the serial to read its IP and confirm it matches what you expect. Mismatched subnets -> return to Step 4.
- If NDI Toolbox is not installed (OS predates 3.0.0-55), clone and install from `https://code.medtronic.com/ET/ns/NDIToolBox`, then run `./Configure` out of `NDIToolBox-master/files/opt/mnav/NDIToolBox`.

Once Toolbox connects successfully, **close it** before testing the clinical app.

---

## Step 6 -- Firmware compatibility

Only relevant if the clinical app banner says **"Camera Firmware Incompatible"** or the camera is a Vega VT with firmware version other than what is in the compat file.

1. In NDI Toolbox, connect to the camera and read the **Firmware** field on the main screen. Note the **major** number (e.g. `008`).
2. Open `/opt/mnav/share/camera-firmware-compatibility/stealthapplication.d/ndi_vega.fw`.
3. Confirm the major version appears in `supported_ndi_combined_fw_revisions`. Add it temporarily for dev work if missing.

Example contents:
```json
{
    "supported_ndi_combined_fw_revisions": [
        "002",
        "007",
        "008",
        "011"
    ]
}
```

> **Do NOT commit this change.** It is local dev only.

If still failing, inspect StealthApp logs -- focus on `LocX` and `OpticalX` log entries.

---

## Step 7 -- Required packages

Confirm the following packages are installed (the quick-diagnostic script does this automatically):

- `mnav-config-networking3-dev`
- `mnav-config-etchosts3`
- `mnav-camera-firmware-compatibility`

If any are missing, install via the standard dev-package channel for the OS image.

---

## Step 8 -- SCU connection (optional)

If you need to connect active wired tools (microscope, ultrasound, some frames), an SCU box is required. Wiring details are not yet documented in the source wiki -- treat as **TODO** and consult the camera owner.

---

## Troubleshooting playbook

For any failure not resolved by the steps above, consult [references/troubleshooting.md](./references/troubleshooting.md). It covers:

- Insufficient PoE power (connects but won't track)
- Red light interpretation (SCU expected vs. bump sensor, temperature sensor, current fault)
- Bump / temperature sensor reset via NDI Toolbox
- "Camera Firmware Incompatible" remediation
- Infrared interference and geometry complaints (usually transient)
- Single-NIC Mazor / home-dev-box network design
- Custom netplan via `/opt/mnav/etc/custom_netplan.yaml` and `apply_custom_netplan`

---

## Handoff / when to stop

Stop and escalate (do not keep tweaking) when:
- The camera shows a **permanent current fault** -- it likely needs to go back to NDI.
- A bump or temperature sensor tripped **in the field** (not dev) -- the hospital must run the AAK test, not the dev team.
- All steps pass but tracking is still wrong -- pull StealthApp `LocX` / `OpticalX` logs and hand to the optical SME.
