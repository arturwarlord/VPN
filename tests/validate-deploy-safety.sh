#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/deploy.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

[[ -s "$WORKFLOW" ]] || fail "deployment workflow is missing or empty"

# Deployments must never run automatically on pushes or pull requests.
grep -Eq '^  workflow_dispatch:' "$WORKFLOW" || fail "manual workflow_dispatch trigger is required"
if grep -Eq '^  (push|pull_request):' "$WORKFLOW"; then
  fail "deployment must not run automatically on push or pull_request"
fi
pass "deployment is manual-only"

# Host identity must be pinned; never learn a key from the network during deployment.
grep -Fq 'StrictHostKeyChecking=yes' "$WORKFLOW" || fail "strict SSH host-key checking is required"
grep -Fq 'UserKnownHostsFile="$RUNNER_TEMP/vpn_known_hosts"' "$WORKFLOW" || fail "pinned known_hosts file is required"
grep -Fq 'GlobalKnownHostsFile=/dev/null' "$WORKFLOW" || fail "unexpected global known_hosts must be disabled"
if grep -Fq 'ssh-keyscan' "$WORKFLOW"; then
  fail "ssh-keyscan must not be used to establish trust"
fi
pass "SSH host identity is pinned"

# Require all credentials explicitly and never enable shell tracing in the deploy workflow.
for secret in VPN_HOST VPN_USER VPN_SSH_KEY VPN_KNOWN_HOSTS; do
  grep -Fq "secrets.$secret" "$WORKFLOW" || fail "required secret reference missing: $secret"
done
if grep -Eq '^[[:space:]]*set -[a-zA-Z]*x' "$WORKFLOW"; then
  fail "shell tracing could expose secret-derived commands"
fi
pass "required secrets are referenced without shell tracing"

# Validate endpoint syntax and country before any SSH action can mutate a server.
validate_line="$(grep -nF 'name: Validate inputs and secrets' "$WORKFLOW" | cut -d: -f1)"
country_line="$(grep -nF 'name: Verify endpoint country is not Russia' "$WORKFLOW" | cut -d: -f1)"
ssh_line="$(grep -nF 'name: Verify SSH access and non-interactive sudo' "$WORKFLOW" | cut -d: -f1)"
install_line="$(grep -nF 'name: Install VPN server over SSH' "$WORKFLOW" | cut -d: -f1)"
[[ "$validate_line" -lt "$country_line" && "$country_line" -lt "$ssh_line" && "$ssh_line" -lt "$install_line" ]] ||
  fail "expected order: input validation, country check, SSH preflight, installation"
grep -Fq 'WG_VALIDATE_ONLY=1 WG_ENDPOINT="$ENDPOINT_IP" WG_PORT="$WG_PORT" bash scripts/setup-wireguard.sh' "$WORKFLOW" ||
  fail "non-mutating installer validation is required before SSH"
grep -Fq 'ipaddress.ip_address(sys.argv[1])' "$WORKFLOW" || fail "deployment must parse IPv4 and IPv6 addresses"
grep -Fq 'if not endpoint.is_global:' "$WORKFLOW" || fail "deployment must reject non-global endpoint addresses"
grep -Fq 'if response_ip != requested_ip:' "$WORKFLOW" || fail "geolocation must compare normalized IP addresses"
pass "endpoint and country checks precede remote changes"

# Temporary private SSH files must be removed on success and failure.
grep -Fq 'if: always()' "$WORKFLOW" || fail "SSH cleanup must run with if: always()"
grep -Fq 'rm -f "$RUNNER_TEMP/vpn_key" "$RUNNER_TEMP/vpn_known_hosts"' "$WORKFLOW" ||
  fail "temporary SSH material cleanup is missing"
pass "temporary SSH material has unconditional cleanup"

echo "Deployment safety regression tests: all passed."
