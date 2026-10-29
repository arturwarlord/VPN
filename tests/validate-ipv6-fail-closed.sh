#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

setup = Path("scripts/setup-wireguard.sh").read_text(encoding="utf-8")
diagnose = Path("scripts/diagnose-wireguard-server.sh").read_text(encoding="utf-8")

required_setup = [
    "Address = 10.77.0.1/24, fd4b:8d2c:6a91::1/64",
    "AllowedIPs = 10.77.0.${octet}/32, fd4b:8d2c:6a91::${octet}/128",
    "Address = 10.77.0.${octet}/32, fd4b:8d2c:6a91::${octet}/128",
    "AllowedIPs = 0.0.0.0/0, ::/0",
    "ip6tables -I FORWARD 1 -i wg0 -j DROP",
    "ip6tables -I INPUT 1 -i wg0 -j DROP",
    "while ip6tables -C FORWARD -i wg0 -j DROP",
    "while ip6tables -C INPUT -i wg0 -j DROP",
]
for item in required_setup:
    assert item in setup, f"Missing IPv6 fail-closed installer behavior: {item}"

assert "command -v ip6tables" in setup, "Installer must verify ip6tables exists"
assert "ip6tables -C FORWARD -i wg0 -j DROP" in diagnose, "Diagnostics must verify IPv6 forwarding is blocked"
assert "ip6tables -C INPUT -i wg0 -j DROP" in diagnose, "Diagnostics must verify IPv6 host access is blocked"
assert 'grep -Fq "AllowedIPs = 0.0.0.0/0, ::/0" "$file"' in diagnose, (
    "Diagnostics must verify each client sends both IP families through WireGuard"
)
assert 'grep -Fq "Address = 10.77.0.${octet}/32, fd4b:8d2c:6a91::${octet}/128" "$file"' in diagnose, (
    "Diagnostics must verify each client has an IPv6 tunnel address"
)
assert "IPv6 fail-closed: VPN client IPv6 forwarding and host access are blocked." in diagnose

print("IPv6 fail-closed tests: passed (dual-stack tunnel routes, ULA peer addresses, explicit IPv6 drops and diagnostics).")
PY
