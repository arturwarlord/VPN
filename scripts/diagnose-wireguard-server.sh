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
command -v iptables >/dev/null || fail "iptables is not installed."

port="$(wg show wg0 listen-port)"
[[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || fail "Cannot read active WireGuard listen port."
wg show wg0 >/dev/null || fail "WireGuard did not return interface status."

wan_if="$(ip -4 route show default | awk 'NR==1 {print $5}')"
[[ -n "$wan_if" ]] || fail "Cannot detect the default IPv4 interface."
iptables -t nat -C POSTROUTING -s 10.77.0.0/24 -o "$wan_if" -j MASQUERADE || fail "VPN subnet NAT rule is missing."

iptables -C FORWARD -j FREEROUTE_FORWARD || fail "The restrictive FreeRoute forwarding chain is not attached."
forward_rules="$(iptables -S FORWARD | grep '^-A FORWARD' || true)"
first_forward_rule="${forward_rules%%
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
\\n'*}"
[[ "$first_forward_rule" == "-A FORWARD -j FREEROUTE_FORWARD" ]] || fail "The FreeRoute forwarding chain is not first; a prior rule could bypass its restrictions."
jump_count="$(printf '%s\\n' "$forward_rules" | grep -Fc -- '-j FREEROUTE_FORWARD' || true)"
[[ "$jump_count" == "1" ]] || fail "Expected exactly one jump to the FreeRoute forwarding chain."

expected_chain_rules="$(cat <<EOF
-A FREEROUTE_FORWARD -i $wan_if -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FREEROUTE_FORWARD -o wg0 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 0.0.0.0/8 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 10.0.0.0/8 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 100.64.0.0/10 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 127.0.0.0/8 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 169.254.0.0/16 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 172.16.0.0/12 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 192.0.0.0/24 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 192.168.0.0/16 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 198.18.0.0/15 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 224.0.0.0/4 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 240.0.0.0/4 -j DROP
-A FREEROUTE_FORWARD -i wg0 -o $wan_if -j ACCEPT
-A FREEROUTE_FORWARD -i wg0 ! -o $wan_if -j DROP
-A FREEROUTE_FORWARD -j RETURN
EOF
)"
actual_chain_rules="$(iptables -S FREEROUTE_FORWARD)" || fail "Cannot inspect the FreeRoute forwarding chain."
[[ "$actual_chain_rules" == "$expected_chain_rules" ]] || fail "The FreeRoute forwarding chain differs from the approved rule set; refusing to mark the server as secure."

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
