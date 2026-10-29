#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ "$(id -u)" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
command -v apt-get >/dev/null || { echo "Ubuntu/Debian with apt-get required." >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard wireguard-tools iptables iproute2
WAN_IF="$(ip -4 route show default | awk 'NR==1 {print $5}')"
[[ -n "$WAN_IF" ]] || { echo "Cannot detect default network interface." >&2; exit 1; }
install -d -m 700 /etc/wireguard /etc/wireguard/clients /root/wireguard-clients
if [[ ! -s /etc/wireguard/server_private.key ]]; then wg genkey > /etc/wireguard/server_private.key; fi
chmod 600 /etc/wireguard/server_private.key
SERVER_PRIVATE="$(cat /etc/wireguard/server_private.key)"
SERVER_PUBLIC="$(printf '%s' "$SERVER_PRIVATE" | wg pubkey)"
PORT="${WG_PORT:-51820}"
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.77.0.1/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIVATE}
SaveConfig = false
PostUp = iptables -t nat -A POSTROUTING -s 10.77.0.0/24 -o ${WAN_IF} -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s 10.77.0.0/24 -o ${WAN_IF} -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT
EOF
chmod 600 /etc/wireguard/wg0.conf
printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-wireguard-forward.conf
sysctl --system >/dev/null
for spec in "windows:2" "android:3" "iphone:4"; do
  name="${spec%%:*}"; octet="${spec##*:}"
  priv="/etc/wireguard/clients/${name}.private"
  pub="/etc/wireguard/clients/${name}.public"
  [[ -s "$priv" ]] || wg genkey > "$priv"
  chmod 600 "$priv"
  wg pubkey < "$priv" > "$pub"
  chmod 600 "$pub"
  client_private="$(cat "$priv")"
  client_public="$(cat "$pub")"
  grep -Fq "# ${name}" /etc/wireguard/wg0.conf || cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# ${name}
PublicKey = ${client_public}
AllowedIPs = 10.77.0.${octet}/32
EOF
  cat > "/root/wireguard-clients/${name}.conf" <<EOF
[Interface]
PrivateKey = ${client_private}
Address = 10.77.0.${octet}/32
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${WG_ENDPOINT:-REPLACE_WITH_PUBLIC_SERVER_IP}:${PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
  chmod 600 "/root/wireguard-clients/${name}.conf"
done
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then ufw allow "${PORT}/udp" >/dev/null; fi
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0
wg show wg0 >/dev/null
echo "WireGuard configured. Client profiles remain on the VPS under /root/wireguard-clients."
echo "Server public key: ${SERVER_PUBLIC}"
echo "UDP port: ${PORT}"
