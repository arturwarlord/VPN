#!/usr/bin/env python3
"""Safely register one WireGuard peer without ever handling its private key.

Run as root on a deployed FreeRoute server. The caller supplies only a device
label and the device-generated public key. The client private key stays on the
device and is never sent to this script or to GitHub Actions.
"""
from __future__ import annotations

import base64
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
from typing import Iterable

CONFIG_PATH = Path("/etc/wireguard/wg0.conf")
LOCK_PATH = Path("/run/lock/freeroute-peer-registration.lock")
MANAGED_MARKER = "# FreeRoute managed WireGuard configuration"
IPV4_POOL = ipaddress.ip_network("10.77.0.0/24")
IPV6_POOL = ipaddress.ip_network("fd4b:8d2c:6a91::/64")
RESERVED_NAMES = {"windows", "android", "iphone"}


def validate_device_name(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?", value):
        raise ValueError("device_name must be 1-32 lowercase letters, digits or hyphens, with alphanumeric ends.")
    if value in RESERVED_NAMES:
        raise ValueError("device_name is reserved for a legacy FreeRoute peer.")
    return value


def validate_public_key(value: str) -> str:
    if not isinstance(value, str) or len(value) != 44:
        raise ValueError("client_public_key must be a canonical WireGuard public key.")
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, base64.binascii.Error) as exc:
        raise ValueError("client_public_key is not valid base64.") from exc
    if len(decoded) != 32 or base64.b64encode(decoded).decode("ascii") != value or not any(decoded):
        raise ValueError("client_public_key must encode a non-zero 32-byte WireGuard key.")
    return value


def _peer_data(config_text: str) -> tuple[set[str], list[ipaddress._BaseNetwork], set[str]]:
    section = ""
    peer_keys: set[str] = set()
    allowed_networks: list[ipaddress._BaseNetwork] = []
    peer_comments: set[str] = set()

    for raw_line in config_text.splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip().lower()
            continue
        if section != "peer" or not line:
            continue
        if line.startswith("#"):
            peer_comments.add(line)
            continue
        if line.startswith("#") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key.lower() == "publickey":
            peer_keys.add(value)
        elif key.lower() == "allowedips":
            for item in value.split(","):
                item = item.strip()
                try:
                    allowed_networks.append(ipaddress.ip_network(item, strict=False))
                except ValueError as exc:
                    raise ValueError("The managed WireGuard config contains an invalid AllowedIPs entry.") from exc

    return peer_keys, allowed_networks, peer_comments


def _address_is_used(candidate: ipaddress._BaseNetwork, used: Iterable[ipaddress._BaseNetwork]) -> bool:
    return any(candidate.overlaps(existing) for existing in used if candidate.version == existing.version)


def build_updated_config(config_text: str, device_name: str, public_key: str) -> tuple[str, str, str]:
    """Return (new_config, ipv4, ipv6), refusing unmanaged or conflicting peers."""
    validate_device_name(device_name)
    validate_public_key(public_key)

    if config_text.count(MANAGED_MARKER) != 1 or not re.search(r"(?m)^\[Interface\]\s*$", config_text):
        raise ValueError("Refusing to modify a config that is not a single FreeRoute-managed WireGuard config.")

    peer_keys, used_networks, peer_comments = _peer_data(config_text)
    if public_key in peer_keys:
        raise ValueError("This public key is already registered.")
    if f"# freeroute-device: {device_name}" in peer_comments:
        raise ValueError("A device with this name is already registered.")

    selected_id = None
    for host_id in range(2, 255):
        ipv4 = ipaddress.ip_address(int(IPV4_POOL.network_address) + host_id)
        ipv6 = ipaddress.ip_address(int(IPV6_POOL.network_address) + host_id)
        if not _address_is_used(ipaddress.ip_network(f"{ipv4}/32"), used_networks) and not _address_is_used(
            ipaddress.ip_network(f"{ipv6}/128"), used_networks
        ):
            selected_id = host_id
            break

    if selected_id is None:
        raise ValueError("The FreeRoute client address pool is exhausted.")

    ipv4 = str(ipaddress.ip_address(int(IPV4_POOL.network_address) + selected_id))
    ipv6 = str(ipaddress.ip_address(int(IPV6_POOL.network_address) + selected_id))
    suffix = (
        f"\n\n[Peer]\n"
        f"# freeroute-device: {device_name}\n"
        f"PublicKey = {public_key}\n"
        f"AllowedIPs = {ipv4}/32, {ipv6}/128\n"
    )
    updated = config_text.rstrip() + suffix
    return updated, ipv4, ipv6


def _run_wg(*args: str) -> str:
    result = subprocess.run(
        ["wg", *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def register_device(device_name: str, public_key: str) -> dict[str, str]:
    validate_device_name(device_name)
    validate_public_key(public_key)

    if os.geteuid() != 0:
        raise PermissionError("Run this registration script as root.")
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
            raise RuntimeError("Another FreeRoute device registration is already running.") from exc

        _run_wg("show", "wg0")
        runtime_peers = set(filter(None, _run_wg("show", "wg0", "peers").splitlines()))
        if public_key in runtime_peers:
            raise ValueError("This public key is already active on the WireGuard interface.")

        original = CONFIG_PATH.read_text(encoding="utf-8")
        updated, ipv4, ipv6 = build_updated_config(original, device_name, public_key)
        server_public_key = _run_wg("show", "wg0", "public-key")
        listen_port = _run_wg("show", "wg0", "listen-port")
        if not listen_port.isdigit() or not 1 <= int(listen_port) <= 65535:
            raise RuntimeError("The active WireGuard interface returned an invalid listen port.")

        temp_path: str | None = None
        runtime_updated = False
        try:
            fd, temp_path = tempfile.mkstemp(prefix=".wg0.conf.freeroute.", dir=str(CONFIG_PATH.parent))
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                os.fchmod(handle.fileno(), 0o600)
                handle.write(updated)
                handle.flush()
                os.fsync(handle.fileno())

            _run_wg(
                "set",
                "wg0",
                "peer",
                public_key,
                "allowed-ips",
                f"{ipv4}/32,{ipv6}/128",
                "persistent-keepalive",
                "25",
            )
            runtime_updated = True
            os.replace(temp_path, CONFIG_PATH)
            temp_path = None
            runtime_updated = False  # The atomic config replacement is now the durable commit.
            try:
                directory_fd = os.open(CONFIG_PATH.parent, os.O_RDONLY)
                try:
                    os.fsync(directory_fd)
                finally:
                    os.close(directory_fd)
            except OSError:
                # Some filesystems do not support syncing directory metadata.
                pass
        except Exception:
            if runtime_updated:
                subprocess.run(
                    ["wg", "set", "wg0", "peer", public_key, "remove"],
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
            "ipv4": ipv4,
            "ipv6": ipv6,
            "server_public_key": server_public_key,
            "listen_port": listen_port,
        }


def main() -> int:
    try:
        device_name = os.environ.get("WG_DEVICE_NAME", "")
        public_key = os.environ.get("WG_CLIENT_PUBLIC_KEY", "")
        result = register_device(device_name, public_key)
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception as exc:
        print(f"FreeRoute peer registration failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
