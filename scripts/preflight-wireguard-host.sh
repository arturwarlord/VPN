#!/usr/bin/env bash
# Read-only compatibility probe for a FreeRoute WireGuard host.
# It never installs packages, changes sysctls/firewall rules, or creates interfaces.
set -Eeuo pipefail

failures=0
warnings=0

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; failures=$((failures + 1)); }

printf '%s\n' 'FreeRoute host preflight (read-only)' '-----------------------------------'

if [[ "$(id -u)" == "0" ]]; then
  pass "SSH session has root privileges"
else
  fail "SSH session is not root; use root SSH or configure non-interactive sudo"
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) pass "Supported Linux distribution: ${PRETTY_NAME:-$ID}" ;;
    *) fail "Unsupported distribution '${ID:-unknown}'; installer supports Ubuntu/Debian" ;;
  esac
else
  fail "/etc/os-release is unavailable"
fi

pid1="$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]' || true)"
if command -v systemctl >/dev/null 2>&1 && [[ "$pid1" == "systemd" ]]; then
  pass "systemd is PID 1"
else
  fail "systemd is not PID 1; current server installer needs systemd/wg-quick service management"
fi

for tool in apt-get python3 ip sysctl; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "Required command available: $tool"
  else
    fail "Required command missing: $tool"
  fi
done

for tool in iptables ip6tables; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "Firewall command available: $tool"
  else
    warn "Firewall command $tool is not installed yet; APT installation and container firewall permissions must be verified before deployment"
  fi
done

if [[ -c /dev/net/tun && -r /dev/net/tun && -w /dev/net/tun ]]; then
  pass "/dev/net/tun exists and is readable/writable"
else
  fail "/dev/net/tun is missing or not accessible; WireGuard tunnel interface cannot be created"
fi

if command -v python3 >/dev/null 2>&1; then
  cap_net_admin="$(python3 - <<'PY'
from pathlib import Path
line = next((line for line in Path("/proc/self/status").read_text().splitlines()
             if line.startswith("CapEff:")), None)
if line is None:
    raise SystemExit(2)
effective = int(line.split()[1], 16)
print("yes" if effective & (1 << 12) else "no")
PY
  )" || cap_net_admin="unknown"
  if [[ "$cap_net_admin" == "yes" ]]; then
    pass "CAP_NET_ADMIN is effective in this process"
  else
    fail "CAP_NET_ADMIN is not effective; LXC container cannot manage tunnel/firewall networking"
  fi
fi

if [[ -d /sys/module/wireguard ]]; then
  pass "WireGuard kernel module is currently available"
elif command -v modinfo >/dev/null 2>&1 && modinfo wireguard >/dev/null 2>&1; then
  warn "WireGuard module exists on disk but is not loaded; a container may be unable to load host kernel modules"
else
  fail "WireGuard kernel module is not visible; current installer needs a WireGuard-capable host kernel"
fi

if command -v wg >/dev/null 2>&1 && command -v wg-quick >/dev/null 2>&1; then
  pass "wg and wg-quick tools are already installed"
else
  warn "wg/wg-quick tools are not installed yet; installer would need to add them through APT"
fi

if command -v iptables >/dev/null 2>&1; then
  if iptables -S >/dev/null 2>&1 && iptables -t nat -S >/dev/null 2>&1; then
    pass "iptables filter and NAT tables can be inspected"
  else
    fail "iptables filter/NAT access is denied; container likely lacks required network capabilities"
  fi
fi

if command -v ip6tables >/dev/null 2>&1; then
  if ip6tables -S >/dev/null 2>&1; then
    pass "ip6tables rules can be inspected"
  else
    fail "ip6tables access is denied; IPv6 fail-closed rules cannot be managed"
  fi
fi

if [[ -r /proc/sys/net/ipv4/ip_forward ]]; then
  forward_value="$(cat /proc/sys/net/ipv4/ip_forward)"
  if [[ "$forward_value" == "1" ]]; then
    pass "IPv4 forwarding is already enabled"
  elif [[ -w /proc/sys/net/ipv4/ip_forward ]]; then
    warn "IPv4 forwarding is disabled but the sysctl appears writable; installer may enable it"
  else
    fail "IPv4 forwarding is disabled and its sysctl is not writable from this environment"
  fi
else
  fail "Cannot read net.ipv4.ip_forward"
fi

if command -v ip >/dev/null 2>&1 && ip -4 route show default 2>/dev/null | grep -q .; then
  pass "IPv4 default route exists"
else
  fail "No IPv4 default route; internet egress/NAT for VPN clients cannot work"
fi

if command -v python3 >/dev/null 2>&1 && python3 - <<'PY'
import ipaddress
import urllib.request

with urllib.request.urlopen("https://api.ipify.org", timeout=8) as response:
    address = response.read().decode("ascii").strip()
ipaddress.ip_address(address)
PY
then
  pass "Outbound IPv4 HTTPS connectivity verified (public IP value not logged)"
else
  fail "Outbound IPv4 HTTPS connectivity check failed"
fi

printf '%s\n' '-----------------------------------'
printf 'Warnings: %s | Failures: %s\n' "$warnings" "$failures"
if (( failures > 0 )); then
  echo "Preflight FAILED. Do not run Deploy WireGuard VPN on this host."
  exit 1
fi

echo "Preflight PASSED. This is only a capability check; external UDP reachability, actual deployment, WireGuard handshake, exit-country and DNS/IPv6 leak tests are still unverified."
