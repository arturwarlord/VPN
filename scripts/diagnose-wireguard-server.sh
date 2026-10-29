#!/usr/bin/env bash
set -Eeuo pipefail

fail() { echo "SERVER CHECK FAILED: $*" >&2; exit 1; }

command -v wg >/dev/null || fail "wireguard-tools is not installed."
systemctl is-active --quiet wg-quick@wg0 || fail "wg-quick@wg0 is not active."
systemctl is-enabled --quiet wg-quick@wg0 || fail "wg-quick@wg0 is not enabled at boot."
[[ -s /etc/wireguard/wg0.conf ]] || fail "Server config is missing."
grep -Fq '# FreeRoute managed WireGuard configuration' /etc/wireguard/wg0.conf || fail "Config is not marked as FreeRoute-managed."
[[ "$(stat -c '%a' /etc/wireguard/wg0.conf)" == "600" ]] || fail "Server config permissions are not 600."
[[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] || fail "IPv4 forwarding is disabled."

port="$(wg show wg0 listen-port)"
[[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || fail "Cannot read active WireGuard listen port."
wg show wg0 >/dev/null || fail "WireGuard did not return interface status."

for name in windows android iphone; do
  file="/root/wireguard-clients/$name.conf"
  [[ -s "$file" ]] || fail "Missing client profile: $name."
  [[ "$(stat -c '%a' "$file")" == "600" ]] || fail "Client profile $name permissions are not 600."
  grep -Fq 'Endpoint = ' "$file" || fail "Client profile $name has no endpoint."
  ! grep -Fq 'REPLACE_WITH_PUBLIC_SERVER_IP' "$file" || fail "Client profile $name still has a placeholder endpoint."
done

peers="$(wg show wg0 peers | wc -l | tr -d ' ')"
nat_rules="$(iptables -t nat -S POSTROUTING | grep -c -- '-s 10.77.0.0/24' || true)"
echo "WireGuard service: active"
echo "Enabled at boot: yes"
echo "Listen port: UDP/$port"
echo "Configured peers: $peers"
echo "NAT rule count matching VPN subnet: $nat_rules"
echo "IPv4 forwarding: enabled"
echo "Client profiles: present with mode 600 (private contents not printed)"
echo "Server-side checks passed. External reachability, client handshake, public IP, DNS and IPv6 leaks still require client-side tests."
