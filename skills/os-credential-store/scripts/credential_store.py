"""Production-ready wrapper around the OS-native credential store.

Targets interactive Windows (Credential Manager / DPAPI) and Ubuntu 22.04
desktops (GNOME Keyring / Secret Service) via the cross-platform ``keyring``
library. Built for storing a corporate PLM login on a per-user desktop.

Why use this instead of calling ``keyring`` directly:
  * refuses to run against an insecure/plaintext fallback backend,
  * namespaces the service key so dev/prod and multiple systems never collide,
  * transparently chunks secrets over the Windows ~1280-char limit,
  * turns keyring's raw exceptions into clear, actionable errors,
  * exposes a tiny interface (store / retrieve / delete / has) that maps 1:1 to
    an app's login lifecycle.

Dependency: ``pip install keyring``  (also pulls SecretStorage+jeepney on Linux).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Protocol

import keyring
import keyring.errors
from keyring.backends import fail, null

# Windows Credential Manager caps a secret at ~1280 UTF-16 chars (2560 bytes).
# Chunk below that with headroom; Linux has no such limit but chunking is safe.
_MAX_SINGLE_CHARS = 1000
_CHUNK_MARKER = "\x00plmchunks:"  # sentinel written into the primary slot


class _KeyringLike(Protocol):
    """The slice of the keyring API we use, so tests can inject a fake."""

    def get_password(self, service: str, username: str) -> Optional[str]: ...
    def set_password(self, service: str, username: str, password: str) -> None: ...
    def delete_password(self, service: str, username: str) -> None: ...


@dataclass(frozen=True)
class Credential:
    username: str
    secret: str


class CredentialStoreError(RuntimeError):
    """Raised for actionable, user-facing failures (insecure backend, locked keyring)."""


def assert_secure_backend(kr: _KeyringLike | None = None) -> None:
    """Fail fast if the active backend is not a real OS store.

    ``keyring`` silently falls back to a failing or (with ``keyrings.alt``
    installed) a *plaintext* backend when no native store is reachable. Storing
    a corporate credential in cleartext because a dependency changed the backend
    is exactly what we must prevent, so we check before every write.
    """
    kr = kr or keyring.get_keyring()
    module = type(kr).__module__.lower()
    classname = type(kr).__name__.lower()
    insecure = (
        isinstance(kr, (fail.Keyring, null.Keyring))
        or "alt" in module
        or "plaintext" in module
        or "plaintext" in classname
        or "encrypted" in classname  # keyrings.alt file backends
    )
    if insecure:
        raise CredentialStoreError(
            f"Active keyring backend {type(kr).__name__!r} is not a secure OS "
            "store. On Windows ensure Credential Manager is available; on Ubuntu "
            "ensure GNOME Keyring is installed and your login keyring is unlocked."
        )


class PLMCredentialStore:
    """Store one corporate PLM credential per (system, environment) on this box.

    Example
    -------
    >>> store = PLMCredentialStore(app="acme-plm-client",
    ...                            system="windchill", environment="prod")
    >>> store.store("jdoe", "s3cr3t")
    >>> store.retrieve("jdoe")
    's3cr3t'
    >>> store.delete("jdoe")
    """

    def __init__(
        self,
        app: str,
        system: str,
        environment: str = "prod",
        keyring_impl: _KeyringLike | None = None,
    ) -> None:
        if not (app and system):
            raise ValueError("app and system are required to build the service key")
        # The service string IS the primary key in the OS store. Keep it stable;
        # changing it orphans previously stored secrets.
        self.service = f"{app}:{system}:{environment}"
        self._kr: _KeyringLike = keyring_impl or keyring

    # -- lifecycle operations ------------------------------------------------

    def store(self, username: str, secret: str) -> None:
        """Create or overwrite the credential for ``username``."""
        assert_secure_backend(self._kr)
        self._clear_chunks(username)  # avoid stale tail from a longer prior value
        if len(secret) <= _MAX_SINGLE_CHARS:
            self._set(username, secret)
            return
        parts = [secret[i:i + _MAX_SINGLE_CHARS]
                 for i in range(0, len(secret), _MAX_SINGLE_CHARS)]
        self._set(username, f"{_CHUNK_MARKER}{len(parts)}")
        for i, part in enumerate(parts):
            self._set(self._chunk_key(username, i), part)

    def retrieve(self, username: str) -> Optional[str]:
        """Return the stored secret, or ``None`` if nothing is stored (first run)."""
        primary = self._get(username)
        if primary is None:
            return None
        if not primary.startswith(_CHUNK_MARKER):
            return primary
        count = int(primary[len(_CHUNK_MARKER):])
        return "".join(self._get(self._chunk_key(username, i)) or ""
                       for i in range(count))

    def retrieve_credential(self, username: str) -> Optional[Credential]:
        secret = self.retrieve(username)
        return Credential(username, secret) if secret is not None else None

    def has(self, username: str) -> bool:
        return self._get(username) is not None

    def delete(self, username: str) -> None:
        """Remove the credential. Idempotent: no error if already absent."""
        self._clear_chunks(username)
        self._delete(username)

    # -- internals -----------------------------------------------------------

    @staticmethod
    def _chunk_key(username: str, index: int) -> str:
        return f"{username}\x00chunk{index}"

    def _clear_chunks(self, username: str) -> None:
        primary = self._get(username)
        if primary and primary.startswith(_CHUNK_MARKER):
            count = int(primary[len(_CHUNK_MARKER):])
            for i in range(count):
                self._delete(self._chunk_key(username, i))

    def _set(self, username: str, value: str) -> None:
        try:
            self._kr.set_password(self.service, username, value)
        except keyring.errors.KeyringLocked as exc:
            raise CredentialStoreError(
                "The credential store is locked. On Ubuntu, unlock your login "
                "keyring; this can happen with automatic login or SSH sessions."
            ) from exc
        except keyring.errors.PasswordSetError as exc:
            raise CredentialStoreError(
                "Failed to write the credential. If the secret is very long on "
                "Windows this indicates the length limit; chunking should handle "
                "it - report this if you see it via PLMCredentialStore."
            ) from exc

    def _get(self, username: str) -> Optional[str]:
        try:
            return self._kr.get_password(self.service, username)
        except keyring.errors.KeyringLocked as exc:
            raise CredentialStoreError(
                "The credential store is locked; unlock your login keyring."
            ) from exc

    def _delete(self, username: str) -> None:
        try:
            self._kr.delete_password(self.service, username)
        except keyring.errors.PasswordDeleteError:
            pass  # already absent - deletion is idempotent


# --------------------------------------------------------------------------
# CLI demo:  python credential_store.py {store|get|delete|check} ...
# --------------------------------------------------------------------------
def _main(argv: Optional[list[str]] = None) -> int:
    import argparse
    import getpass

    p = argparse.ArgumentParser(description="OS credential store demo (PLM login).")
    p.add_argument("action", choices=["store", "get", "delete", "check"])
    p.add_argument("--app", default="acme-plm-client")
    p.add_argument("--system", default="windchill")
    p.add_argument("--env", default="prod")
    p.add_argument("--user", help="account login (prompted if omitted)")
    args = p.parse_args(argv)

    if args.action == "check":
        try:
            assert_secure_backend()
            print(f"OK - secure backend: {type(keyring.get_keyring()).__name__}")
            return 0
        except CredentialStoreError as exc:
            print(f"INSECURE: {exc}")
            return 1

    store = PLMCredentialStore(args.app, args.system, args.env)
    user = args.user or input("Username: ")

    if args.action == "store":
        secret = getpass.getpass(f"Secret for {user}: ")
        store.store(user, secret)
        print(f"Stored under service '{store.service}'.")
    elif args.action == "get":
        secret = store.retrieve(user)
        print("Not found (first run?)." if secret is None
              else f"Retrieved {len(secret)} chars for {user}.")
    elif args.action == "delete":
        store.delete(user)
        print(f"Deleted (if present) for {user}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
