# FreeRoute OpenVPN 3 Android TUN builder — phase 2

## Implemented in this draft branch

The native `FreeRouteOpenVpnClient` now overrides the pinned OpenVPN 3
`TunBuilderBase` callbacks and collects interface configuration until
`tun_builder_establish()`. At that point it calls the Android service's
`establishTun(...)` JNI method. The service creates a `VpnService.Builder`,
adds the accepted addresses/routes/plain DNS servers, and returns a detached
file descriptor to native code.

Supported in this phase:

- Layer 3 TUN only.
- IPv4 and IPv6 interface addresses with valid prefix lengths.
- IPv4/IPv6 routes and plain default-gateway rerouting when no redirect flags
  are requested.
- Plain DNS server IP addresses on the standard DNS port (53) or unspecified
  port.
- MTU in the accepted Android range; IPv6 interfaces require MTU >= 1280.
- Session name and Android transport-socket protection.

## Explicit fail-closed cases

The bridge returns failure instead of silently dropping settings it cannot
represent with the current Android service contract:

- Route exclusions.
- Redirect-gateway flags (including emulated exclusions).
- Route metrics where OpenVPN supplies a non-negative metric.
- Non-empty per-address gateways and net30 topology.
- DNS-over-HTTPS, DNS-over-TLS, non-standard DNS ports, DNSSEC policy,
  split-DNS domains, search domains, and DNS SNI.
- WINS and all proxy callbacks.
- Requests to allow an address family or local DNS to bypass the VPN.

These restrictions are intentional. They mean some valid OpenVPN profiles will
be rejected at TUN setup until the corresponding Android semantics are
implemented and tested. Do not work around them by dropping the settings.

## Lifecycle and limitations

This phase only adds callback translation and TUN establishment. It does not
yet:

- import or evaluate a profile with `eval_config()`;
- provide username/password or private-key credentials;
- call `connect()` on a worker thread;
- implement asynchronous stop/join and callback-quiescence rules;
- expose a user-facing OpenVPN connect action;
- implement Android foreground-service notification and permission flow;
- prove end-to-end connectivity with an authorized OpenVPN server.

The descriptor returned by `VpnService.Builder.establish()` is detached from
the Kotlin `ParcelFileDescriptor`; ownership transfers to OpenVPN native code.
The OpenVPN core is responsible for closing it during teardown.

## Validation required

CI must compile the ARM64 native library and debug APK. Before enabling this
path, add callback-level tests for invalid prefixes, unsupported route/DNS
semantics, JNI exceptions, descriptor ownership, and teardown. Then test on
Android 13 with a valid profile/server and verify egress IP, IPv4/IPv6 routing,
DNS behavior, and absence of traffic leaks.

WireGuard remains unchanged and is still the supported working connection path.
