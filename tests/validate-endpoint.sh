#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/scripts/setup-wireguard.sh"
passed=0
failed=0

expect_valid() {
  local endpoint="$1"
  local port="$2"
  local output
  if output="$(WG_VALIDATE_ONLY=1 WG_ENDPOINT="$endpoint" WG_PORT="$port" bash "$INSTALLER" 2>&1)"; then
    if [[ "$output" == *"no system changes made"* ]]; then
      echo "PASS valid endpoint=$endpoint port=$port"
      ((passed += 1))
    else
      echo "FAIL valid input lacked confirmation: $endpoint:$port" >&2
      echo "$output" >&2
      ((failed += 1))
    fi
  else
    echo "FAIL valid input rejected: $endpoint:$port" >&2
    echo "$output" >&2
    ((failed += 1))
  fi
}

expect_invalid() {
  local endpoint="$1"
  local port="$2"
  local label="$3"
  local output
  if output="$(WG_VALIDATE_ONLY=1 WG_ENDPOINT="$endpoint" WG_PORT="$port" bash "$INSTALLER" 2>&1)"; then
    echo "FAIL invalid input accepted ($label): $endpoint:$port" >&2
    ((failed += 1))
  else
    echo "PASS rejected $label"
    ((passed += 1))
  fi
}

expect_missing_endpoint() {
  local output
  if output="$(env -u WG_ENDPOINT WG_VALIDATE_ONLY=1 WG_PORT=51820 bash "$INSTALLER" 2>&1)"; then
    echo "FAIL missing endpoint was accepted" >&2
    ((failed += 1))
  else
    echo "PASS rejected missing endpoint"
    ((passed += 1))
  fi
}

expect_valid "1.1.1.1" "51820"
expect_valid "8.8.8.8" "1"
expect_valid "1.0.0.1" "65535"

expect_missing_endpoint
expect_invalid "10.0.0.1" "51820" "private IPv4"
expect_invalid "172.16.10.2" "51820" "private IPv4"
expect_invalid "192.168.1.20" "51820" "private IPv4"
expect_invalid "100.64.0.1" "51820" "carrier-grade NAT"
expect_invalid "169.254.1.1" "51820" "link-local IPv4"
expect_invalid "127.0.0.1" "51820" "loopback IPv4"
expect_invalid "0.0.0.0" "51820" "unspecified IPv4"
expect_invalid "224.0.0.1" "51820" "multicast IPv4"
expect_invalid "192.0.0.2" "51820" "special-purpose IPv4"
expect_invalid "192.88.99.1" "51820" "deprecated relay IPv4"
expect_invalid "192.0.2.2" "51820" "documentation IPv4"
expect_invalid "198.51.100.12" "51820" "documentation IPv4"
expect_invalid "203.0.113.9" "51820" "documentation IPv4"
expect_invalid "256.1.2.3" "51820" "out-of-range IPv4"
expect_invalid "1.01.1.1" "51820" "non-canonical IPv4"
expect_invalid "bad-address" "51820" "malformed IPv4"
expect_invalid "1.1.1.1" "0" "zero port"
expect_invalid "1.1.1.1" "65536" "port above 65535"
expect_invalid "1.1.1.1" "abc" "non-numeric port"
expect_invalid "1.1.1.1" "0080" "leading-zero port"

echo "Endpoint validation tests: $passed passed; $failed failed."
(( failed == 0 )) || exit 1
