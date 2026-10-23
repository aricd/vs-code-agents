# Windows Credential Manager + DPAPI (reference)

## Table of contents
1. What it is
2. How keyring uses it
3. The encryption chain (DPAPI)
4. Where secrets live
5. The 2560-byte limit and the chunking workaround
6. Threat model and limits
7. Inspecting and troubleshooting

## 1. What it is
Windows Credential Manager (also called the Credential Locker / Windows Vault) is
the built-in per-user secret store on Windows. It holds three kinds of entries;
the one that matters for application secrets is the **Generic** credential
(`CRED_TYPE_GENERIC`), which is arbitrary app data the OS will encrypt and hand
back only to the same user.

## 2. How keyring uses it
On Windows, `keyring` selects the `WinVaultKeyring` backend and reaches the store
through the Win32 Credential Management API using the `pywin32-ctypes`
(`win32ctypes`) bindings - no compiler or full pywin32 install required.

- `set_password(service, username, secret)` -> `CredWrite` with `Type =
  CRED_TYPE_GENERIC`, `TargetName = service`, `UserName = username`,
  `CredentialBlob = secret` (UTF-16), persistence `LOCAL_MACHINE`.
- `get_password(service, username)` -> `CredRead` on that `TargetName`, decrypt,
  return the blob as text.
- `delete_password(service, username)` -> `CredDelete`.

The `TargetName` (your `service` string) is the primary key. That is why a stable,
namespaced service name matters: change it and old entries are orphaned, not
migrated.

## 3. The encryption chain (DPAPI)
`CredWrite` does not persist plaintext. Windows runs the blob through the **Data
Protection API (DPAPI)** in the user's context. DPAPI's key hierarchy ultimately
derives from the user's logon secret and a per-user master key stored under the
profile; the resulting ciphertext is bound to **this user on this machine**.
Nothing in your code manages keys - that is the entire point, and the reason not
to hand-roll encryption. Consequences:
- A different local user cannot decrypt the entry.
- Copying the on-disk blob to another machine or user makes it undecryptable.
- Once the user is logged in, any process in that user's session can read it
  (DPAPI has no per-application isolation for generic credentials).

## 4. Where secrets live
Encrypted credential blobs are stored in the user profile under
`%LOCALAPPDATA%\Microsoft\Credentials\` and
`%APPDATA%\Microsoft\Credentials\`, with DPAPI master keys under
`%APPDATA%\Microsoft\Protect\<user-SID>\`. You never touch these directly; use the
API. The GUI view is *Control Panel -> Credential Manager -> Windows Credentials*.

## 5. The 2560-byte limit and the chunking workaround
The Win32 `CredentialBlob` is capped at **2560 bytes**, i.e. ~1280 UTF-16
characters. Passwords are fine; long OAuth/OIDC JWTs are not. Exceeding it throws
an unhelpful error:

```
pywintypes.error: (1783, 'CredWrite', 'The stub received bad data.')
```

Do not "solve" this by encrypting the token yourself into a file. The robust,
still-inside-the-OS-store fix is to split the value into numbered sub-entries and
reassemble on read:

```python
CHUNK = 1200  # characters, safely under the ~1280 UTF-16 ceiling

def set_long(service, username, secret):
    parts = [secret[i:i+CHUNK] for i in range(0, len(secret), CHUNK)] or [""]
    keyring.set_password(service, f"{username}\x00meta", str(len(parts)))
    for i, part in enumerate(parts):
        keyring.set_password(service, f"{username}\x00{i}", part)

def get_long(service, username):
    meta = keyring.get_password(service, f"{username}\x00meta")
    if meta is None:
        return None
    return "".join(keyring.get_password(service, f"{username}\x00{i}") or ""
                   for i in range(int(meta)))
```

`scripts/credential_store.py` ships a cleaner version of this that only chunks when
needed, so short secrets stay as a single, human-readable Credential Manager entry.

## 6. Threat model and limits
DPAPI defends the secret **at rest** and across users on the same box. It does
**not** defend against:
- Malware or a rogue script running as the same logged-in user (it can call
  `CredRead` too, or invoke DPAPI to decrypt). This is why short-lived tokens beat
  stored domain passwords.
- An attacker with the user's login password offline (they can reconstruct the
  DPAPI keys).
- Admin/SYSTEM-level compromise.
Keep the OS patched, run least-privilege, and store the narrowest credential the
PLM will accept.

## 7. Inspecting and troubleshooting
- List/verify from PowerShell-adjacent GUI: *Credential Manager -> Windows
  Credentials* - your namespaced `service` appears as the entry name.
- Confirm backend: `python -c "import keyring; print(keyring.get_keyring())"`
  should print a `WinVaultKeyring` instance.
- `CredWrite ... bad data` almost always means you exceeded the length limit - use
  chunking.
