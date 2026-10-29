#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

fail() { echo "ERROR: $*" >&2; exit 1; }

validate_inputs() {
  # Require an explicit public IPv4 endpoint. Never create profiles with a placeholder.
  WG_ENDPOINT="${WG_ENDPOINT:-}"
  [[ -n "$WG_ENDPOINT" ]] || fail "Set WG_ENDPOINT to this server's public IPv4 address."
  [[ "$WG_ENDPOINT" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || fail "WG_ENDPOINT must be an IPv4 address."

  IFS='.' read -r -a endpoint_octets <<< "$WG_ENDPOINT"
  for octet in "${endpoint_octets[@]}"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] || fail "WG_ENDPOINT must be an IPv4 address."
    [[ "${#octet}" -eq 1 || "$octet" != 0* ]] || fail "WG_ENDPOINT must use canonical IPv4 notation."
    (( 10#$octet <= 255 )) || fail "WG_ENDPOINT contains an octet above 255."
  done

  a="${endpoint_octets[0]}"
  b="${endpoint_octets[1]}"
  c="${endpoint_octets[2]}"
  if (( a == 0 || a == 10 || a == 127 || a >= 224 )); then
    fail "WG_ENDPOINT must be a globally routable public IPv4 address."
  fi
  if (( a == 100 && b >= 64 && b <= 127 )); then
    fail "WG_ENDPOINT cannot use a carrier-grade NAT address."
  fi
  if (( a == 169 && b == 254 )); then
    fail "WG_ENDPOINT cannot use a link-local address."
  fi
  if (( a == 172 && b >= 16 && b <= 31 )); then
    fail "WG_ENDPOINT cannot use a private IPv4 address."
  fi
  if (( a == 192 && b == 168 )); then
    fail "WG_ENDPOINT cannot use a private IPv4 address."
  fi
  if (( a == 192 && b == 0 && (c == 0 || c == 2) )) || (( a == 192 && b == 88 && c == 99 )); then
    fail "WG_ENDPOINT cannot use a special-purpose or deprecated IPv4 range."
  fi
  if (( a == 198 && b == 51 && c == 100 )) || (( a == 203 && b == 0 && c == 113 )); then
    fail "WG_ENDPOINT cannot use a documentation-only IPv4 address."
  fi
  if (( a == 198 && (b == 18 || b == 19) )); then
    fail "WG_ENDPOINT cannot use a benchmarking-only IPv4 address."
  fi

  PORT="${WG_PORT:-51820}"
  [[ "$PORT" =~ ^[0-9]{1,5}$ ]] || fail "WG_PORT must be an integer from 1 to 65535."
  [[ "$PORT" == "0" || "${PORT:0:1}" != "0" ]] || fail "WG_PORT must not contain leading zeroes."
  (( 10#$PORT >= 1 && 10#$PORT <= 65535 )) || fail "WG_PORT must be an integer from 1 to 65535."
}

# Non-mutating mode used by CI and deploy preflight.
if [[ "${WG_VALIDATE_ONLY:-0}" == "1" ]]; then
  validate_inputs
  echo "WireGuard endpoint and port validated; no system changes made."
  exit 0
fi

validate_inputs
[[ "$(id -u)" -eq 0 ]] || fail "Run as root."
command -v apt-get >/dev/null || fail "Ubuntu/Debian with apt-get required."

CONFIG="/etc/wireguard/wg0.conf"

# Never overwrite an unrelated or custom peer configuration.
if [[ -e "$CONFIG" ]]; then
  if ! grep -Fq '# FreeRoute managed WireGuard configuration' "$CONFIG"; then
    fail "$CONFIG already exists but is not marked as managed by FreeRoute. Back it up and review it manually before replacing it."
  fi

  existing_peer_count="$(grep -cE '^[[:space:]]*\[Peer\][[:space:]]*$' "$CONFIG" || true)"
  if [[ "$existing_peer_count" != "3" ]]; then
    fail "The managed config has $existing_peer_count peers; this installer manages exactly windows/android/iphone. Refusing to drop or rewrite custom peers."
  fi

  for managed_peer in windows android iphone; do
    marker_count="$(grep -Fc "# $managed_peer" "$CONFIG" || true)"
    if [[ "$marker_count" != "1" ]]; then
      fail "The existing config does not contain exactly one '# $managed_peer' marker; refusing to replace a potentially customized peer list."
    fi
  done
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard wireguard-tools iptables iproute2

WAN_IF="$(ip -4 route show default | awk 'NR==1 {print $5}')"
[[ -n "$WAN_IF" ]] || fail "Cannot detect default network interface."

install -d -m 700 /etc/wireguard /etc/wireguard/clients /root/wireguard-clients
if [[ ! -s /etc/wireguard/server_private.key ]]; then
  wg genkey > /etc/wireguard/server_private.key
fi
chmod 600 /etc/wireguard/server_private.key
SERVER_PRIVATE="$(cat /etc/wireguard/server_private.key)"
SERVER_PUBLIC="$(printf '%s' "$SERVER_PRIVATE" | wg pubkey)"

# Build a complete candidate config before replacing the active config.
CONFIG_TMP="$(mktemp /etc/wireguard/wg0.conf.XXXXXX)"
chmod 600 "$CONFIG_TMP"
trap 'if [[ -n "${CONFIG_TMP:-}" ]]; then rm -f "$CONFIG_TMP"; fi' EXIT

cat > "$CONFIG_TMP" <<EOF
# FreeRoute managed WireGuard configuration
[Interface]
Address = 10.77.0.1/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIVATE}
SaveConfig = false
PostUp = iptables -t nat -C POSTROUTING -s 10.77.0.0/24 -o ${WAN_IF} -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.77.0.0/24 -o ${WAN_IF} -j MASQUERADE; if iptables -S FREEROUTE_FORWARD >/dev/null 2>&1; then iptables -S FREEROUTE_FORWARD | grep -Fq 'freeroute-managed' || { echo "Refusing to flush an unrecognized FREEROUTE_FORWARD chain." >&2; exit 1; }; iptables -F FREEROUTE_FORWARD; else iptables -N FREEROUTE_FORWARD; fi; iptables -A FREEROUTE_FORWARD -i ${WAN_IF} -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -A FREEROUTE_FORWARD -o wg0 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 0.0.0.0/8 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 10.0.0.0/8 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 100.64.0.0/10 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 127.0.0.0/8 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 169.254.0.0/16 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 172.16.0.0/12 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 192.0.0.0/24 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 192.0.2.0/24 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 192.88.99.0/24 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 192.168.0.0/16 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 198.18.0.0/15 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 198.51.100.0/24 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 203.0.113.0/24 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 224.0.0.0/4 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -d 240.0.0.0/4 -j DROP; iptables -A FREEROUTE_FORWARD -i wg0 -o ${WAN_IF} -j ACCEPT; iptables -A FREEROUTE_FORWARD -i wg0 ! -o ${WAN_IF} -j DROP; iptables -A FREEROUTE_FORWARD -m comment --comment freeroute-managed -j RETURN; while iptables -C FORWARD -j FREEROUTE_FORWARD 2>/dev/null; do iptables -D FORWARD -j FREEROUTE_FORWARD; done; iptables -I FORWARD 1 -j FREEROUTE_FORWARD; while iptables -C INPUT -i wg0 -j DROP 2>/dev/null; do iptables -D INPUT -i wg0 -j DROP; done; iptables -I INPUT 1 -i wg0 -j DROP
PostDown = while iptables -C INPUT -i wg0 -j DROP 2>/dev/null; do iptables -D INPUT -i wg0 -j DROP; done; while iptables -C FORWARD -j FREEROUTE_FORWARD 2>/dev/null; do iptables -D FORWARD -j FREEROUTE_FORWARD; done; iptables -F FREEROUTE_FORWARD 2>/dev/null || true; iptables -X FREEROUTE_FORWARD 2>/dev/null || true; iptables -t nat -D POSTROUTING -s 10.77.0.0/24 -o ${WAN_IF} -j MASQUERADE 2>/dev/null || true
EOF

# Generate separate device keys on the VPS. Private profiles never enter GitHub.
for spec in "windows:2" "android:3" "iphone:4"; do
  name="${spec%%:*}"
  octet="${spec##*:}"
  priv="/etc/wireguard/clients/${name}.private"
  pub="/etc/wireguard/clients/${name}.public"

  [[ -s "$priv" ]] || wg genkey > "$priv"
  chmod 600 "$priv"
  wg pubkey < "$priv" > "$pub"
  chmod 600 "$pub"

  client_private="$(cat "$priv")"
  client_public="$(cat "$pub")"

  cat >> "$CONFIG_TMP" <<EOF

[Peer]
# ${name}
PublicKey = ${client_public}
AllowedIPs = 10.77.0.${octet}/32
EOF

  client_tmp="$(mktemp "/root/wireguard-clients/${name}.conf.XXXXXX")"
  chmod 600 "$client_tmp"
  cat > "$client_tmp" <<EOF
[Interface]
PrivateKey = ${client_private}
Address = 10.77.0.${octet}/32
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${WG_ENDPOINT}:${PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
  mv -f "$client_tmp" "/root/wireguard-clients/${name}.conf"
  chmod 600 "/root/wireguard-clients/${name}.conf"
done

chmod 600 "$CONFIG_TMP"
BACKUP=""
if [[ -f "$CONFIG" ]]; then
  BACKUP="/etc/wireguard/wg0.conf.backup.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p "$CONFIG" "$BACKUP"
fi
mv -f "$CONFIG_TMP" "$CONFIG"
CONFIG_TMP=""

printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-wireguard-forward.conf
sysctl --system >/dev/null

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow "${PORT}/udp" >/dev/null
fi

if ! systemctl enable wg-quick@wg0 >/dev/null || ! systemctl restart wg-quick@wg0; then
  echo "WireGuard failed to start; attempting to restore the previous config." >&2
  if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
    cp -p "$BACKUP" "$CONFIG"
    systemctl restart wg-quick@wg0 || true
  else
    systemctl stop wg-quick@wg0 || true
    rm -f "$CONFIG"
    systemctl disable wg-quick@wg0 >/dev/null 2>&1 || true
  fi
  fail "WireGuard did not start. Check systemctl status wg-quick@wg0 and journalctl -u wg-quick@wg0."
fi

wg show wg0 >/dev/null
grep -Fq "Endpoint = ${WG_ENDPOINT}:${PORT}" /root/wireguard-clients/windows.conf
for name in windows android iphone; do
  [[ -s "/root/wireguard-clients/${name}.conf" ]] || fail "Missing generated profile for ${name}."
  [[ "$(stat -c '%a' "/root/wireguard-clients/${name}.conf")" == "600" ]] || fail "Unsafe permissions on ${name} profile."
done

echo "WireGuard configured and service is active."
echo "Client profiles were generated on the VPS under /root/wireguard-clients (mode 600); they were not printed or uploaded."
echo "Server public key: ${SERVER_PUBLIC}"
echo "Public endpoint: ${WG_ENDPOINT}:${PORT}/udp"
echo "Note: this setup tunnels IPv4 only. IPv6 is not routed through the tunnel yet, so client devices must treat IPv6 leak prevention as unfinished."
