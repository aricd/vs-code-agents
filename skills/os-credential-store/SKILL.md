---
name: os-credential-store
description: >-
  Best practices and working Python patterns for storing and retrieving secrets
  in the operating system's native credential store on interactive Windows and
  Ubuntu LTS desktops - 22.04, 24.04, and 26.04 (Windows Credential Manager /
  DPAPI and GNOME Keyring / Secret Service). Use this skill WHENEVER a Python
  project needs to persist a
  password, API token, OAuth refresh token, session cookie, or any corporate or
  user credential on the local machine instead of hard-coding it, dropping it in
  a .env / config file, or writing custom encryption. Trigger on requests like
  "store credentials securely", "save my login for the PLM system", "keyring",
  "Windows Credential Manager", "GNOME Keyring", "secret service", "where do I
  put this token", "stop putting passwords in code", or any desktop app that
  authenticates a user against a backend and must remember the login.
---

# OS-level credential store (Windows + Ubuntu 22.04 / 24.04 / 26.04 LTS)

## What this is and the one rule that matters

An "OS-level authentication store" is a secure, per-user vault that the operating
system provides for exactly one purpose: holding small secrets (passwords,
tokens) encrypted at rest, keyed to the logged-in user, so that only that user's
processes can read them back. On Windows that vault is **Credential Manager**
(backed by DPAPI); on an Ubuntu LTS desktop (22.04 through 26.04) it is **GNOME
Keyring**, reached through the freedesktop **Secret Service** API. The Secret
Service D-Bus API is stable across every one of those releases, so a single code
path works on all of them - only *installation* differs (see Setup below).

**The rule: never roll your own.** Do not invent an encryption scheme, do not
store a "lightly obfuscated" password in a config file, and do not put secrets in
environment variables baked into a script. The OS store already solves key
management (the hardest part) by tying the encryption key to the user's login.
Your job is to call it correctly.

In Python the correct way to call it is the **`keyring`** library
(`pip install keyring`). It is the de-facto standard, is maintained, and picks the
right native backend automatically: `WinVaultKeyring` on Windows and
`SecretService` on Linux. Everything below assumes `keyring`. Reach for the raw
Win32 / D-Bus APIs only when you hit a documented limitation (see the reference
files) - and even then, keep `keyring` as the front door.

## Mechanics: how the store actually works

You do not need to understand the cryptography to use the store safely, but you
need the mental model, because it explains every best practice and every gotcha.

**Windows - Credential Manager + DPAPI.** `keyring` calls the Win32 Credential
Management API (`CredWrite` / `CredRead`) to store a *generic* credential. Before
the secret hits disk, Windows encrypts it with the **Data Protection API
(DPAPI)**, whose master key is derived from the user's login secret and bound to
that user account on that machine. The encrypted blob lives in the user's profile
(the Credential Locker / Vault). The practical consequences: another user on the
same PC cannot read it; the blob is useless if copied to another machine or user;
and - importantly - *any* process running as the same user can read it once the
user is logged in. DPAPI protects secrets **at rest**, not from code already
running as you.

**Ubuntu 22.04 - Secret Service + GNOME Keyring.** `keyring` talks over **D-Bus**
to the Secret Service provider, which on a standard Ubuntu desktop is
`gnome-keyring-daemon`. Secrets are grouped into **collections**; the default one
is the **login keyring**, stored under `~/.local/share/keyrings/login.keyring`.
That file is encrypted (AES) with a key derived from your **login password**, and
the PAM stack **auto-unlocks it when you log in graphically**. When the collection
is unlocked, your process reads the secret transparently; when it is locked, the
desktop shows an unlock prompt. Same shape as Windows: encrypted at rest, keyed to
your login, readable by your session once unlocked.

Both platforms give you the same guarantees, so a single `keyring`-based code path
works on both. The differences that leak through - a length limit on Windows, a
"keyring stays locked" edge case on Linux - are covered in the reference files.

## How the store interacts with your application

Think of the store as a tiny key-value database with a two-part key:

- **service** - a stable string that names *what the secret is for*. Namespace it
  so different apps, environments, and endpoints never collide. Recommended shape:
  `"{app}:{system}:{environment}"`, e.g. `"acme-plm-client:windchill:prod"`.
- **username** - *whose* secret it is (the account login). Storing this - not just
  the password - lets one machine hold multiple accounts and lets you use
  `get_credential()` to recover both halves later.

The four operations you will ever need:

```python
import keyring

keyring.set_password(service, username, secret)      # create or overwrite
secret = keyring.get_password(service, username)      # -> str or None
cred = keyring.get_credential(service, None)          # -> obj with .username/.password (or None)
keyring.delete_password(service, username)            # raises if it does not exist
```

`get_password` returns `None` when nothing is stored - that is your "not logged in
yet" signal, which drives a first-run prompt. This is the whole application
contract: on startup you look up the credential; if it is missing you prompt the
user once and store it; on every subsequent run you read it silently; on logout or
account switch you delete it.

A production-ready wrapper that implements exactly this contract - with the safety
checks and the Windows length workaround below already built in - ships with this
skill at `scripts/credential_store.py`. Prefer adapting it over writing raw
`keyring` calls, because the raw calls omit the guards that matter for corporate
secrets.

## Best practices

**Store the smallest, shortest-lived secret you can.** For a corporate PLM system
(Windchill, Teamcenter, Aras, 3DEXPERIENCE, etc.) the ideal is to never store the
raw domain password at all. In order of preference: (1) use single sign-on -
Kerberos/SPNEGO on Windows via `requests-negotiate-sspi`, or the platform's OIDC
flow - so nothing is stored; (2) if the PLM speaks OAuth2/OIDC, run the login flow
once and store only the **refresh token**, which can be revoked centrally and
expires; (3) only if the PLM offers nothing but Basic auth do you store the
password itself - and then treat rotation as a first-class feature. A stored
refresh token limits the blast radius of a compromised machine far more than a
stored domain password, which may unlock email, VPN, and everything else.

**Verify the backend before you trust it - this is the non-negotiable one for
corporate secrets.** `keyring` will, if no native store is reachable, silently
fall back to a backend that *fails* or (if `keyrings.alt` is installed) one that
writes **plaintext**. Storing a corporate credential in a plaintext file because a
dependency quietly changed the backend is exactly the outcome you are trying to
prevent. At startup, confirm the active backend is a real OS store and refuse to
write otherwise. `scripts/credential_store.py` does this; the check looks like:

```python
import keyring
from keyring.backends import fail, null

def assert_secure_backend():
    kr = keyring.get_keyring()
    name = kr.__class__.__module__
    if isinstance(kr, (fail.Keyring, null.Keyring)) or "alt" in name or "plaintext" in name.lower():
        raise RuntimeError(
            f"Refusing to store secrets: active keyring backend {kr!r} is not a "
            "secure OS store. Ensure Windows Credential Manager or GNOME Keyring is available."
        )
```

**Namespace the service name and always store the username.** Encode app, system,
and environment so your dev PLM credential never overwrites prod. Keep the string
in one constant, not scattered across the codebase - it is effectively your
database key and changing it orphans previously stored secrets.

**Handle the Windows length limit.** Windows Credential Manager caps the secret at
**2560 bytes (~1280 UTF-16 characters)**. Short passwords are fine, but long OIDC
access/refresh tokens (JWTs) routinely exceed it and `set_password` fails with a
cryptic `CredWrite: The stub received bad data` error. The clean fix is to chunk
long values across numbered entries and reassemble on read; the shipped wrapper
does this transparently. Linux has no comparable limit.

**Fail loudly and helpfully when the store is unavailable.** On a headless or
misconfigured Ubuntu box the keyring may be locked or absent and `keyring` raises
`keyring.errors.KeyringLocked` / `NoKeyringError`. Catch these and tell the user
what to fix ("unlock your login keyring" / "install gnome-keyring") rather than
crashing with a stack trace.

**Treat deletion and rotation as real flows.** Provide "log out" (delete) and
"update credentials" (overwrite) paths. `delete_password` raises
`PasswordDeleteError` if nothing is stored - catch it so logout is idempotent.
When the PLM rejects a stored credential (rotated password, expired token), delete
the stale entry and re-prompt rather than looping on 401s.

**Do not undermine the store in your own code.** Never log the secret, never write
it to a temp file or crash dump, and hold it in memory no longer than needed. The
OS protects the secret at rest; only your code can leak it once retrieved.

## Minimal end-to-end pattern

```python
import getpass, keyring

SERVICE = "acme-plm-client:windchill:prod"

def get_or_prompt_credentials(username: str) -> str:
    secret = keyring.get_password(SERVICE, username)
    if secret is None:                       # first run
        secret = getpass.getpass(f"PLM password for {username}: ")
        keyring.set_password(SERVICE, username, secret)
    return secret

def logout(username: str) -> None:
    try:
        keyring.delete_password(SERVICE, username)
    except keyring.errors.PasswordDeleteError:
        pass                                 # already logged out
```

For anything beyond a throwaway script, use `scripts/credential_store.py`, which
wraps this pattern with the backend-safety check, service-name namespacing,
long-token chunking, and clear errors already in place.

## Setup and dependencies

- **Windows (interactive desktop):** `pip install keyring`. No extra system
  packages - Credential Manager is built in and `keyring` reaches it through
  `pywin32-ctypes`.
- **Ubuntu 22.04 / 24.04 / 26.04 LTS desktop:** the runtime is identical on all
  three - GNOME Keyring ships with the standard desktop, auto-unlocks at graphical
  login, and `keyring` always selects the `SecretService` backend (which pulls in
  `SecretStorage` + `jeepney`). Only *how you install* differs, because of PEP 668:
    - **22.04:** `pip install keyring` works globally.
    - **24.04 and 26.04:** the system Python is marked "externally managed", so a
      global `pip install` is blocked with `error: externally-managed-environment`.
      Install one of these ways instead, in order of preference:
      `sudo apt install python3-keyring` (packaged, no PEP 668 issue); a project
      virtual environment (`python3 -m venv .venv && .venv/bin/pip install
      keyring`); or `pipx`. Use `pip install --break-system-packages keyring` only
      on throwaway machines - it can break apt-managed tools.
  If you see D-Bus errors on any release, ensure `gnome-keyring` and `libsecret-1-0`
  are installed and you are in a real desktop session.

The shipped `scripts/credential_store.py` needs Python 3.10+ - satisfied by all
three releases (22.04 -> 3.10, 24.04 -> 3.12, 26.04 -> 3.13). Confirm the backend
once with `python3 -c "import keyring; print(keyring.get_keyring())"` - you want
`WinVaultKeyring` on Windows and `SecretService` on Ubuntu.

## Verification checklist

Before shipping, confirm on **both** targets:

1. `keyring.get_keyring()` reports the native backend, and the startup safety check
   rejects `fail`/`null`/plaintext backends.
2. Store -> read-back -> delete round-trips for a normal-length password.
3. A ~4 KB token round-trips (exercises the Windows chunking path).
4. `get_password` on an unknown key returns `None`; `delete_password` on an unknown
   key is handled, not fatal.
5. Windows: the entry appears in *Control Panel -> Credential Manager -> Windows
   Credentials* under your namespaced service name.
6. Ubuntu: the entry appears in **Seahorse** ("Passwords and Keys") under the Login
   keyring.
7. A second local user account cannot read the first user's secret.

## Reference files

- `references/windows-credential-manager.md` - DPAPI internals, the Win32 API
  `keyring` calls, the 2560-byte limit and chunking, storage location, threat model.
- `references/linux-secret-service.md` - Secret Service / D-Bus / GNOME Keyring
  internals, the login-keyring auto-unlock caveat, storage location, required
  packages, threat model.
- `scripts/credential_store.py` - production-ready `PLMCredentialStore` class
  implementing every best practice above; runnable as a CLI demo.
