# Secret Service + GNOME Keyring on Ubuntu 22.04 / 24.04 / 26.04 LTS (reference)

Applies to every current Ubuntu LTS desktop: 22.04 (Jammy), 24.04 (Noble), and
26.04 (Resolute, the latest LTS). The Secret Service D-Bus API and GNOME Keyring
behaviour are the same across all three; the only material differences are in
Python packaging (see section 6) - summarised in section 9.

## Table of contents
1. The stack: Secret Service, D-Bus, GNOME Keyring, libsecret
2. How keyring uses it
3. Collections and the login keyring
4. The auto-unlock caveat (the #1 gotcha)
5. Where secrets live
6. Required packages (and the PEP 668 change in 24.04+)
7. Threat model and limits
8. Inspecting and troubleshooting
9. Version differences: 22.04 -> 24.04 -> 26.04

## 1. The stack
On Linux there is no single vault - there is an **API contract**, the freedesktop
**Secret Service** specification, spoken over **D-Bus**. Any provider that
implements it works; on a standard Ubuntu LTS desktop (22.04 through 26.04) the
provider is **`gnome-keyring-daemon`**, and this has not changed across those
releases. `libsecret` is the C client library apps normally use;
Python's `keyring` uses its own pure-Python client (`SecretStorage` on top of
`jeepney`) that speaks the same D-Bus protocol. Net effect: your Python code and
the GNOME login dialog read and write the same store.

## 2. How keyring uses it
`keyring` selects the `SecretService` backend and, per call, opens a D-Bus session
connection to the daemon:
- `set_password(service, username, secret)` -> create/replace an item in the
  default collection whose lookup **attributes** encode `service` and `username`.
- `get_password(service, username)` -> search the collection by those attributes,
  unlock if needed, return the secret.
- `delete_password(service, username)` -> remove the matching item.

Because items are matched by attributes (not a filename), your namespaced
`service` string plus `username` is the key - keep it stable.

## 3. Collections and the login keyring
Secrets are grouped into **collections**, each independently lockable. The desktop
creates a default collection called the **login keyring**. Its on-disk file,
`~/.local/share/keyrings/login.keyring`, is encrypted with AES using a key derived
from your **login password**.

## 4. The auto-unlock caveat (the #1 gotcha)
The login keyring is auto-unlocked by the PAM stack **only when the key derived
from your login password matches the keyring's key** - i.e. the normal case where
you type your password at the graphical greeter. It will **not** auto-unlock, and
your app will hit a locked keyring / unlock prompt, when:
- the machine uses **automatic login** (no password typed, so PAM never derives
  the key),
- you logged in over **SSH / a text console** rather than the desktop greeter,
- the login password and the keyring password were changed out of sync.

On an interactive desktop with a normal password login (your target) this Just
Works. Still handle `keyring.errors.KeyringLocked` and surface a clear "unlock your
login keyring" message for the auto-login users you cannot control.

## 5. Where secrets live
`~/.local/share/keyrings/` - `login.keyring` (default) plus any extra collections
as `*.keyring`. These files are encrypted; do not parse or back them up expecting
portability - they are tied to the login-derived key.

## 6. Required packages (and the PEP 668 change in 24.04+)
- Python `keyring` pulls `SecretStorage` + `jeepney` automatically. **How** you
  install it depends on the release:
  - **22.04:** `pip install keyring` works against the system Python.
  - **24.04 and 26.04:** the system Python is flagged **externally managed**
    (PEP 668), so a global `pip install` fails with
    `error: externally-managed-environment`. This is an Ubuntu/Python packaging
    policy change, not a keyring change. Install one of these instead:
    - `sudo apt install python3-keyring` - packaged, cleanest, sidesteps PEP 668;
    - a virtualenv: `python3 -m venv .venv && .venv/bin/pip install keyring`;
    - `pipx install` for CLI-style tools.
    - `pip install --break-system-packages keyring` works but can clobber
      apt-managed packages - reserve it for disposable machines/containers.
- System (present by default on Ubuntu Desktop, install if a minimal image):
  `gnome-keyring`, `libsecret-1-0`. Seahorse (`gnome-keyring`'s GUI, package
  `seahorse`) is handy for inspection.
- A running D-Bus **session** bus and an unlocked collection. In a full desktop
  session both exist; that is the assumption for this skill.

## 7. Threat model and limits
Same shape as DPAPI on Windows. The store protects secrets **at rest** and unlocks
them for your session; it does **not** protect against code already running as you
once the collection is unlocked, nor against an attacker who has your login
password. There is **no small size limit** like Windows' 2560 bytes, so long
tokens store fine - but keep the code cross-platform by using the shared wrapper,
which chunks only where required (Windows).

## 8. Inspecting and troubleshooting
- GUI: open **Seahorse** ("Passwords and Keys") -> Login keyring; your entries
  appear by their `service` attribute.
- Confirm backend: `python -c "import keyring; print(keyring.get_keyring())"`
  should print a `SecretService` keyring.
- `NoKeyringError` / D-Bus "no such interface" usually means no Secret Service
  provider is running (minimal/headless box) - install `gnome-keyring` and run
  inside a desktop session.
- `KeyringLocked` -> the login keyring is locked; see the auto-unlock caveat above.

## 9. Version differences: 22.04 -> 24.04 -> 26.04
The short version: **your credential-store code does not change.** Across these
LTS releases the Secret Service D-Bus API, `gnome-keyring-daemon` as the default
provider, the `SecretService` keyring backend, the login-keyring auto-unlock
behaviour, and the storage location (`~/.local/share/keyrings/`) are all the same.
What changes lives in the platform, and only two items actually affect this skill:

| Concern | 22.04 (Jammy) | 24.04 (Noble) | 26.04 (Resolute) | Impact on this skill |
| --- | --- | --- | --- | --- |
| Global `pip install` | Works | Blocked by PEP 668 | Blocked by PEP 668 | **Install path only** - use apt/venv/pipx (section 6). No code change. |
| Default Python | 3.10 | 3.12 | 3.13 | None - the shipped script needs 3.10+, satisfied everywhere. |
| GNOME version | 42 | 46 | 48+ | None - Secret Service API is stable; backend stays `SecretService`. |
| Default display server | Wayland (X11 easy) | Wayland | Wayland | None - Secret Service is D-Bus, independent of X11/Wayland. |
| Secret Service provider | gnome-keyring | gnome-keyring | gnome-keyring | None. (KDE users get KWallet, which also implements the API.) |

Two extra notes for wider deployment, neither specific to a single release:
- **Snap/Flatpak confinement.** A confined app cannot reach the session Secret
  Service unless it holds the right portal/interface - for a snap, the
  `password-manager-service` plug. Classic (unconfined) installs and plain
  `python3` scripts are unaffected. If a packaged build suddenly gets
  `NoKeyringError` while the same code works unpackaged, suspect confinement.
- **KWallet desktops (Kubuntu).** `keyring` will use the `kwallet` backend there;
  the same `set_password`/`get_password` calls work unchanged.
