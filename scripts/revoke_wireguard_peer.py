#!/usr/bin/env python3
"""Revoke one managed FreeRoute WireGuard peer by its device label.

This script never handles client private keys. It removes the matching public-key
peer from the live WireGuard interface and the persistent managed config.
"""
from __future__ import annotations

import fcntl
import ipaddress
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

CONFIG_PATH = Path("/etc/wireguard/wg0.conf")
LOCK_PATH = Path("/run/lock/freeroute-peer-registration.lock")
MANAGED_MARKER = "# FreeRoute managed WireGuard configuration"
RESERVED_NAMES = {"windows", "android", "iphone"}


def validate_device_name(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?", value):
        raise ValueError("device_name must be 1-32 lowercase letters, digits or hyphens.")
    if value in RESERVED_NAMES:
        raise ValueError("Legacy peer names are reserved and cannot be revoked by this workflow.")
    return value


def _parse_peer_block(lines: list[str], start: int, end: int) -> tuple[str, list[str], bool]:
    public_keys: list[str] = []
    allowed_ips: list[str] = []
    marker_found = False
    for raw_line in lines[start + 1:end]:
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            if line.startswith("# freeroute-device: "):
                marker_found = True
            continue
        if "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key.lower() == "publickey":
            public_keys.append(value)
        elif key.lower() == "allowedips":
            for item in value.split(","):
                item = item.strip()
                try:
                    network = ipaddress.ip_network(item, strict=False)
                except ValueError as exc:
                    raise ValueError("The target peer has an invalid AllowedIPs entry.") from exc
                allowed_ips.append(str(network))
    if len(public_keys) != 1 or not allowed_ips:
        raise ValueError("The target peer must contain exactly one PublicKey and at least one AllowedIPs entry.")
    return public_keys[0], allowed_ips, marker_found


def build_revoked_config(config_text: str, device_name: str) -> tuple[str, str, list[str]]:
    """Return (new_config, public_key, allowed_ips) for exactly one labelled peer."""
    validate_device_name(device_name)
    if config_text.count(MANAGED_MARKER) != 1 or not re.search(r"(?m)^\[Interface\]\s*$", config_text):
        raise ValueError("Refusing to modify a config that is not a single FreeRoute-managed WireGuard config.")

    lines = config_text.splitlines(keepends=True)
    peer_blocks: list[tuple[int, int]] = []
    section = ""
    block_start: int | None = None
    for index, raw_line in enumerate(lines):
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            if section == "peer" and block_start is not None:
                peer_blocks.append((block_start, index))
            section = line[1:-1].strip().lower()
            block_start = index if section == "peer" else None
    if section == "peer" and block_start is not None:
        peer_blocks.append((block_start, len(lines)))

    marker = f"# freeroute-device: {device_name}"
    matches: list[tuple[int, int, str, list[str]]] = []
    target_marker_count = 0
    for start, end in peer_blocks:
        block_text = "".join(lines[start:end])
        target_marker_count += len(
            re.findall(rf"(?m)^\\s*{re.escape(marker)}\\s*$", block_text)
        )
        if re.search(rf"(?m)^\\s*{re.escape(marker)}\\s*$", block_text):
            public_key, allowed_ips, marker_found = _parse_peer_block(lines, start, end)
            if not marker_found:
                raise ValueError("The matching device marker could not be parsed.")
            matches.append((start, end, public_key, allowed_ips))

    if target_marker_count != len(matches):
        raise ValueError("The configuration contains a duplicate or malformed marker for this device.")
    if len(matches) != 1:
        raise ValueError("No uniquely registered FreeRoute device with this name was found.")

    start, end, public_key, allowed_ips = matches[0]
    if len(set(allowed_ips)) != len(allowed_ips):
        raise ValueError("The target peer contains duplicate AllowedIPs entries.")

    new_lines = lines[:start] + lines[end:]
    updated = "".join(new_lines).rstrip() + "\n"
    return updated, public_key, allowed_ips


def _run_wg(*args: str) -> str:
    result = subprocess.run(
        ["wg", *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def revoke_device(device_name: str) -> dict[str, object]:
    validate_device_name(device_name)
    if os.geteuid() != 0:
        raise PermissionError("Run this revocation script as root.")
    if not CONFIG_PATH.is_file() or CONFIG_PATH.is_symlink():
        raise FileNotFoundError("The FreeRoute WireGuard config was not found or is a symlink.")
    mode = stat.S_IMODE(CONFIG_PATH.stat().st_mode)
    if mode & 0o077:
        raise PermissionError("The WireGuard config must not be accessible by group or other users.")

    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("a", encoding="utf-8") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise RuntimeError("Another FreeRoute peer registration or revocation is already running.") from exc

        _run_wg("show", "wg0")
        runtime_peers = set(filter(None, _run_wg("show", "wg0", "peers").splitlines()))
        original = CONFIG_PATH.read_text(encoding="utf-8")
        updated, public_key, allowed_ips = build_revoked_config(original, device_name)
        if public_key not in runtime_peers:
            raise ValueError("The target device exists in the config but is not an active wg0 peer; refusing to guess.")

        temp_path: str | None = None
        runtime_removed = False
        try:
            fd, temp_path = tempfile.mkstemp(prefix=".wg0.conf.freeroute-revoke.", dir=str(CONFIG_PATH.parent))
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                os.fchmod(handle.fileno(), 0o600)
                handle.write(updated)
                handle.flush()
                os.fsync(handle.fileno())

            _run_wg("set", "wg0", "peer", public_key, "remove")
            runtime_removed = True
            os.replace(temp_path, CONFIG_PATH)
            temp_path = None
            runtime_removed = False
            try:
                directory_fd = os.open(CONFIG_PATH.parent, os.O_RDONLY)
                try:
                    os.fsync(directory_fd)
                finally:
                    os.close(directory_fd)
            except OSError:
                pass
        except Exception:
            if runtime_removed:
                subprocess.run(
                    ["wg", "set", "wg0", "peer", public_key, "allowed-ips", ",".join(allowed_ips)],
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            raise
        finally:
            if temp_path:
                try:
                    os.unlink(temp_path)
                except FileNotFoundError:
                    pass

        return {
            "device_name": device_name,
            "revoked": True,
            "removed_allowed_ip_count": len(allowed_ips),
        }


def main() -> int:
    try:
        device_name = os.environ.get("WG_DEVICE_NAME", "")
        print(json.dumps(revoke_device(device_name), sort_keys=True))
        return 0
    except Exception as exc:
        print(f"FreeRoute peer revocation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
