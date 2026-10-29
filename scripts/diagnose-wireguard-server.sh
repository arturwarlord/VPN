#!/usr/bin/env bash
set -Eeuo pipefail

fail() { echo "SERVER CHECK FAILED: $*" >&2; exit 1; }

command -v wg >/dev/null || fail "wireguard-tools is not installed."
command -v iptables >/dev/null || fail "iptables is not installed."
command -v ip6tables >/dev/null || fail "ip6tables is not installed."
command -v ip >/dev/null || fail "iproute2 is not installed."
systemctl is-active --quiet wg-quick@wg0 || fail "wg-quick@wg0 is not active."
systemctl is-enabled --quiet wg-quick@wg0 || fail "wg-quick@wg0 is not enabled at boot."
[[ -s /etc/wireguard/wg0.conf ]] || fail "Server config is missing."
grep -Fq '# FreeRoute managed WireGuard configuration' /etc/wireguard/wg0.conf || fail "Config is not marked as FreeRoute-managed."
[[ "$(stat -c '%a' /etc/wireguard/wg0.conf)" == "600" ]] || fail "Server config permissions are not 600."
[[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] || fail "IPv4 forwarding is disabled."
grep -Fq "Address = 10.77.0.1/24, fd4b:8d2c:6a91::1/64" /etc/wireguard/wg0.conf || fail "Server IPv6 tunnel address is missing."

port="$(wg show wg0 listen-port)"
[[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || fail "Cannot read active WireGuard listen port."
wg show wg0 >/dev/null || fail "WireGuard did not return interface status."

wan_if="$(ip -4 route show default | awk 'NR==1 {print $5}')"
[[ -n "$wan_if" ]] || fail "Cannot detect the default IPv4 interface."
iptables -t nat -C POSTROUTING -s 10.77.0.0/24 -o "$wan_if" -j MASQUERADE || fail "VPN subnet NAT rule is missing."
ip6tables -C FORWARD -i wg0 -j DROP || fail "IPv6 forwarding from VPN clients is not blocked."
ip6tables -C INPUT -i wg0 -j DROP || fail "IPv6 access from VPN clients to host services is not blocked."

ipv6_forward_first="$(ip6tables -S FORWARD | grep -m1 '^-A FORWARD' || true)"
[[ "$ipv6_forward_first" == "-A FORWARD -i wg0 -j DROP" ]] || fail "IPv6 VPN-client forwarding block is not first in FORWARD."
ipv6_input_first="$(ip6tables -S INPUT | grep -m1 '^-A INPUT' || true)"
[[ "$ipv6_input_first" == "-A INPUT -i wg0 -j DROP" ]] || fail "IPv6 VPN-client host-access block is not first in INPUT."

# The restrictive chain must be the first FORWARD rule so later ACCEPT rules cannot bypass it.
forward_rules="$(iptables -S FORWARD | grep '^-A FORWARD' || true)"
first_forward_rule="$(iptables -S FORWARD | grep -m1 '^-A FORWARD' || true)"
[[ "$first_forward_rule" == "-A FORWARD -j FREEROUTE_FORWARD" ]] || fail "The FreeRoute forwarding chain is not first in FORWARD."
jump_count="$(printf '%s\n' "$forward_rules" | grep -Fc -- '-j FREEROUTE_FORWARD' || true)"
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
-A FREEROUTE_FORWARD -i wg0 -d 192.0.2.0/24 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 192.88.99.0/24 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 192.168.0.0/16 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 198.18.0.0/15 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 198.51.100.0/24 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 203.0.113.0/24 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 224.0.0.0/4 -j DROP
-A FREEROUTE_FORWARD -i wg0 -d 240.0.0.0/4 -j DROP
-A FREEROUTE_FORWARD -i wg0 -o $wan_if -j ACCEPT
-A FREEROUTE_FORWARD -i wg0 ! -o $wan_if -j DROP
-A FREEROUTE_FORWARD -m comment --comment freeroute-managed -j RETURN
EOF
)"
actual_chain_rules="$(iptables -S FREEROUTE_FORWARD | sed 's/"freeroute-managed"/freeroute-managed/g')" || fail "Cannot inspect the FreeRoute forwarding chain."
[[ "$actual_chain_rules" == "$expected_chain_rules" ]] || fail "The FreeRoute forwarding chain differs from the exact approved rule set."

# A VPN client must not be able to reach SSH, DNS or other services running on the VPS itself.
input_rules="$(iptables -S INPUT | grep '^-A INPUT' || true)"
first_input_rule="$(iptables -S INPUT | grep -m1 '^-A INPUT' || true)"
[[ "$first_input_rule" == "-A INPUT -i wg0 -j DROP" ]] || fail "The VPN-client host-access block is not first in INPUT."
input_drop_count="$(printf '%s\n' "$input_rules" | grep -Fc -- '-i wg0 -j DROP' || true)"
[[ "$input_drop_count" == "1" ]] || fail "Expected exactly one VPN-client host-access block."

for name in windows android iphone; do
  case "$name" in windows) octet=2 ;; android) octet=3 ;; iphone) octet=4 ;; esac
  file="/root/wireguard-clients/$name.conf"
  [[ -s "$file" ]] || fail "Missing client profile: $name."
  [[ "$(stat -c '%a' "$file")" == "600" ]] || fail "Client profile $name permissions are not 600."
  grep -Fq 'Endpoint = ' "$file" || fail "Client profile $name has no endpoint."
  ! grep -Fq 'REPLACE_WITH_PUBLIC_SERVER_IP' "$file" || fail "Client profile $name still has a placeholder endpoint."
  grep -Fq "Address = 10.77.0.${octet}/32, fd4b:8d2c:6a91::${octet}/128" "$file" || fail "Client profile $name lacks its IPv6 tunnel address."
  grep -Fq "AllowedIPs = 0.0.0.0/0, ::/0" "$file" || fail "Client profile $name does not route IPv4 and IPv6 defaults through WireGuard."
  grep -Fq "AllowedIPs = 10.77.0.${octet}/32, fd4b:8d2c:6a91::${octet}/128" /etc/wireguard/wg0.conf || fail "Server peer $name lacks its IPv6 tunnel address."
done

peers="$(wg show wg0 peers | wc -l | tr -d ' ')"
nat_rules="$(iptables -t nat -S POSTROUTING | grep -c -- '-s 10.77.0.0/24' || true)"
echo "WireGuard service: active"
echo "Enabled at boot: yes"
echo "Listen port: UDP/$port"
echo "Configured peers: $peers"
echo "NAT rule count matching VPN subnet: $nat_rules"
echo "IPv4 forwarding: enabled"
echo "IPv6 fail-closed: VPN client IPv6 forwarding and host access are blocked."
echo "Private/reserved IPv4 destinations are blocked from VPN clients."
echo "VPN clients cannot forward to other interfaces or access services on the VPN host."
echo "Client profiles: present with mode 600 (private contents not printed)"
echo "Server-side checks passed. External reachability, client handshake, public IP, DNS and IPv6 leaks still require client-side tests."
