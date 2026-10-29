#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from pathlib import Path

source = Path("scripts/setup-wireguard.sh").read_text(encoding="utf-8").splitlines()
post_up_lines = [line.removeprefix("PostUp = ") for line in source if line.startswith("PostUp = ")]
post_down_lines = [line.removeprefix("PostDown = ") for line in source if line.startswith("PostDown = ")]

assert len(post_up_lines) == 1, f"Expected one PostUp hook, found {len(post_up_lines)}"
assert len(post_down_lines) == 1, f"Expected one PostDown hook, found {len(post_down_lines)}"
post_up = post_up_lines[0]
post_down = post_down_lines[0]

# Refuse to flush any pre-existing chain unless our ownership marker is present.
owner_check = post_up.find("grep -Fq 'freeroute-managed'")
flush_chain = post_up.find("iptables -F FREEROUTE_FORWARD")
assert owner_check >= 0 and flush_chain > owner_check, "Chain ownership must be verified before flushing it"

required_before_internet_allow = [
    "iptables -A FREEROUTE_FORWARD -o wg0 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 0.0.0.0/8 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 10.0.0.0/8 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 100.64.0.0/10 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 127.0.0.0/8 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 169.254.0.0/16 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 172.16.0.0/12 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 192.0.0.0/24 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 192.0.2.0/24 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 192.88.99.0/24 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 192.168.0.0/16 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 198.18.0.0/15 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 198.51.100.0/24 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 203.0.113.0/24 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 224.0.0.0/4 -j DROP",
    "iptables -A FREEROUTE_FORWARD -i wg0 -d 240.0.0.0/4 -j DROP",
]
internet_allow = "iptables -A FREEROUTE_FORWARD -i wg0 -o ${WAN_IF} -j ACCEPT"
other_interface_drop = "iptables -A FREEROUTE_FORWARD -i wg0 ! -o ${WAN_IF} -j DROP"
marker_return = "iptables -A FREEROUTE_FORWARD -m comment --comment freeroute-managed -j RETURN"

allow_pos = post_up.find(internet_allow)
other_drop_pos = post_up.find(other_interface_drop)
marker_pos = post_up.find(marker_return)
assert allow_pos >= 0 and other_drop_pos > allow_pos and marker_pos > other_drop_pos, (
    "Rule order must be: restricted ranges dropped, internet WAN accepted, "
    "other interfaces dropped, then chain returns."
)
for rule in required_before_internet_allow:
    position = post_up.find(rule)
    assert 0 <= position < allow_pos, f"Missing or late firewall block: {rule}"

assert "iptables -I FORWARD 1 -j FREEROUTE_FORWARD" in post_up, "Restrictive chain must be first in FORWARD"
assert "iptables -I INPUT 1 -i wg0 -j DROP" in post_up, "VPN clients must not reach services on the VPN host"
assert "iptables -A FREEROUTE_FORWARD -i ${WAN_IF} -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT" in post_up, (
    "Established internet replies must be allowed back to clients"
)
assert "iptables -A FORWARD -i wg0 -j ACCEPT" not in post_up, "Do not install a broad FORWARD accept rule"

assert "while iptables -C INPUT -i wg0 -j DROP" in post_down, "PostDown must remove the host INPUT block"
assert "while iptables -C FORWARD -j FREEROUTE_FORWARD" in post_down, "PostDown must remove every FORWARD jump"
assert "iptables -F FREEROUTE_FORWARD" in post_down and "iptables -X FREEROUTE_FORWARD" in post_down, (
    "PostDown must flush and remove the dedicated chain"
)

print("Firewall policy tests: passed (ordered private-range drops, internet-only egress, host isolation and cleanup).")
PY
