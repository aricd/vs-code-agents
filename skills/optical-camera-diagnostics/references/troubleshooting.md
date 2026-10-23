# Optical Camera Troubleshooting Playbook

Deep-dive scenarios for the NDI optical tracking camera on a Stealth Axis dev box. Load **only** after the diagnostic ladder in [../SKILL.md](../SKILL.md) has identified a specific failure class. Each section is independent.

> **Source**: derived from `skills/optical-camera-diagnostics/notes.txt` (Erin Kearns, May 2024 + coworker notes).

---

## Care reminders (read once)

- **Don't leave the camera in a car or garage overnight in winter.** The temperature sensor can trip. Tripping is recoverable -- reset via NDI Toolbox (see "Bump / temperature sensor" below).
- **Don't drop or sharply bump the camera.** The bump sensor can trip with the same recovery path.
- **The camera allows only one controlling connection at a time.** Close NDI Toolbox before starting the clinical app and vice-versa.

---

## Scenario: camera has no lights / no beep on power-up

| Likely cause                        | Check                                                                 | Fix                                                                                  |
|-------------------------------------|-----------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| Cable in a non-powered switch port  | Some PoE switches color powered ports green                           | Move cable to a powered port                                                         |
| PoE switch is 802.3**af**, not at   | Read the sticker on the switch                                        | Replace with an 802.3**at** unmanaged switch (e.g. NETGEAR / TRENDNET)               |
| Switch itself is not powered        | Check switch LEDs                                                     | Plug in / replace the switch's wall wart                                             |
| Mazor X dev box: relying on PoE     | Mazor X has an internal powered switch                                | Skip the external PoE and use the internal switch                                    |
| Cable bad                           | Swap cable                                                            | Replace                                                                              |

---

## Scenario: camera connects and communicates, but does not track tools

Almost always **insufficient power**. The camera will happily talk to NDI Toolbox / the clinical app without enough power for the illuminators, then silently fail to detect markers.

- Confirm the switch is **802.3at** (25.5 W per port), not 802.3af (15.4 W).
- Confirm the camera is on a port that is actually delivering PoE (some switches mix PoE and non-PoE ports).
- Swap to a known-good powered port and re-test.

---

## Scenario: red light on the front of the camera

Diagnose by elimination:

1. **Is the camera configured for an SCU and you don't have one connected?**
   The red light is **expected** in this case. SCU is the box for active wired instruments (microscope, ultrasound, some frames).
2. **Bump sensor or temperature sensor tripped?**
   Open NDI Toolbox or check the clinical app's Optical log. If a sensor flag is set, reset it via NDI Toolbox (see next section).
3. **Permanent "current fault"?**
   If the fault persists after a reset and power cycle, the camera likely needs to be sent back to NDI.

> **Field caveat (not dev):** if a sensor trips on a hospital camera, the hospital must run a special **AAK test** to confirm the camera is OK. Dev does not need to run AAK.

---

## Scenario: bump / temperature sensor reset

1. Close the clinical app.
2. `cd /opt/mnav/NDIToolBox && ./Configure`
3. `File -> Connect To -> <your camera>`
4. Locate the sensor flag in the settings tree, clear it, and `File -> Save Parameters`.
5. Unplug / replug the camera.
6. Close NDI Toolbox before relaunching the clinical app.

---

## Scenario: clinical app banner says "Camera Faulted"

1. Note the exact wording of the banner.
2. Close the clinical app (frees the camera connection).
3. Open NDI Toolbox and connect -- the fault detail is usually visible on the main screen or in the settings tree.
4. Cross-reference with StealthApp logs, focusing on **`OpticalX`** entries.

---

## Scenario: clinical app banner says "Camera Firmware Incompatible"

The compat file does not list your camera's firmware major version.

1. Open NDI Toolbox, connect to the camera, read the **Firmware** field's **major** number (e.g. `008`).
2. Open `/opt/mnav/share/camera-firmware-compatibility/stealthapplication.d/ndi_vega.fw`.
3. Add the major version to `supported_ndi_combined_fw_revisions`:

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

4. Restart the clinical app.

> **Do NOT commit this change.** It is a local dev workaround. The clean fix is for the firmware-compatibility package to ship with your camera's version.

---

## Scenario: NDI Toolbox does not discover the camera

This is almost always a network problem.

1. Confirm the camera is powered (Step 1 of [../SKILL.md](../SKILL.md)).
2. Confirm `ip addr` on the dev box shows an adapter on `192.168.59.0/24`.
3. If the camera is brand new and shipped DHCP, it will be on `169.254.x.x` -- it cannot reach `192.168.59.220` without reconfiguration. Follow "Configuring the Camera Networking" below.
4. If the camera was previously working and you recently changed the dev box networking, restore the previous netplan / admin-app settings.

---

## Configuring the Camera Networking (first-time setup)

The dev box and camera both need static IPs in the same subnet.

**Target end state**:

| Device   | Static IP         | Notes                          |
|----------|-------------------|--------------------------------|
| Dev box  | `192.168.59.100`  | On the camera-facing NIC       |
| Camera   | `192.168.59.220`  | Gateway `192.168.59.1`         |

**Procedure** (assumes camera currently shipped with DHCP and is on `169.254.x.x`):

1. Open NDI Toolbox, `File -> Connect To`, hover the discovered serial to read the camera's current IP (example: `169.254.10.190`).
2. **Temporarily** put the dev box in the same `169.254.10.0/24` subnet -- e.g. dev box static IP `169.254.10.1`.
   - **Preferred** (mnav-network-manager >= 3.0.0-505):
     `mnav-admin-app-electron -> Network Settings -> Wired Network Settings`
   - **Fallback** (older OS): edit `/etc/netplan/*.yaml`, then `sudo netplan apply`. **Changes are wiped on the next restart -- that is the intended behavior for a temporary change.**
3. In NDI Toolbox: `File -> Connect To -> <camera>` again -- it should now connect.
4. In the settings tree:
   - `Settings - Network - IP Method` = `Static IP`
   - `Settings - Network - Static - Gateway` = `192.168.59.1`
   - `Settings - Network - Static - IP Address` = `192.168.59.220`
5. `File -> Save Parameters`.
6. Unplug / replug the camera.
7. Restore the dev box static IP to `192.168.59.100` (admin-app or netplan).
8. `ping psu` should succeed.
9. **Close NDI Toolbox** before launching the clinical app.

---

## Scenario: infrared interference or "geometry complaints" in OpticalX log

Usually **transient and expected**:

- IR interference: another IR source (sunlight through a window, IR remote, another camera) is in view. Reposition or block.
- Geometry complaints: marker geometry was momentarily ambiguous. Reorient the tool.

Treat as actionable only if persistent across multiple sessions in a controlled environment.

---

## Scenario: single-NIC Mazor / home-dev-box networking

**The problem.** A Mazor-era Dell tower with a single Ethernet port (or any single-NIC dev box) cannot simultaneously DHCP onto the wall network and statically hold `192.168.59.100` for the camera.

**Three viable approaches:**

1. **Switch between modes** (simplest, least convenient).
   Toggle the single NIC between DHCP and static `192.168.59.100` depending on whether you need internet or the camera.

2. **Insert a Fortinet firewall / local subnet** (lab-grade).
   Mirrors the production cart topology -- the dev box DHCPs from the firewall, the firewall hosts `192.168.59.0/24` for the camera, the firewall uplinks to the wall.

3. **Reconfigure the camera to your home subnet** (most flexible for home dev).
   Change the camera's static IP to live on your home network (e.g. `192.168.1.220`) using the "Configuring the Camera Networking" procedure above with your home subnet substituted for `192.168.59.0/24`. Caveat: only do this if your home network supports a reliable static IP for the camera.

> Earlier in Juno, there was a helper script at `/opt/mnav/config-networking/scripts/attach_dev_localizer`. It may still work on some boxes; on Mazor-era boxes its support has decayed. Treat as best-effort.

---

## Custom netplan via mnav-network-manager

If you need a custom long-lived netplan (e.g. single-NIC Mazor setup with non-default IPs), use the supported override path **instead of** editing the generated file:

1. Copy the auto-generated netplan to the override location:
   ```bash
   sudo cp /etc/netplan/<generated>.yaml /opt/mnav/etc/custom_netplan.yaml
   ```
2. Edit `/opt/mnav/etc/custom_netplan.yaml` to match your topology. Example for a single-NIC box where the only adapter (find via `ip a`) carries a static camera IP:
   ```yaml
   network:
     ethernets:
       eno1:
         addresses:
           - 192.168.59.100/24
         dhcp4: false
         optional: true
     renderer: networkd
     version: 2
   ```
3. Apply via the supported script:
   ```bash
   sudo /opt/mnav/config-networking/scripts/apply_custom_netplan
   ```

> **Do not edit `/etc/netplan/*.yaml` directly for a long-lived change.** mnav-network-manager will overwrite it.

---

## Required dev packages (re-check)

If diagnostic Step 7 flagged missing packages, install via your standard dev channel:

- `mnav-config-networking3-dev`
- `mnav-config-etchosts3`
- `mnav-camera-firmware-compatibility`

---

## SCU connection

**TODO.** Not documented in the source wiki. Consult the camera owner / optical SME before wiring an SCU for the first time.

---

## When to escalate / stop tweaking

- **Permanent current fault** that survives a reset + power cycle -- send the camera back to NDI.
- **Sensor trip in the field** (not dev) -- hospital must run the AAK test.
- **All diagnostic steps pass but tracking is still wrong** -- collect StealthApp `LocX` and `OpticalX` logs and hand off to the optical SME. Do not keep flipping settings.
