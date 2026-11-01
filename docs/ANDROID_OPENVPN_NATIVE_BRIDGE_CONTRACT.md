# FreeRoute OpenVPN 3 native bridge — implementation contract

This document records the verified API contract for the pinned OpenVPN 3 Core revision
`0abc8313b8fe5f63dbebc10d53094952957845d9`. It is an implementation plan, not a claim
that the OpenVPN tunnel is already operational.

## Verified upstream API

The pinned `client/ovpncli.hpp` defines `openvpn::ClientAPI::OpenVPNClient` as a
concrete API base class with required application callbacks. A native implementation
must subclass it and implement:

- `event(const ClientAPI::Event&)`
- `acc_event(const ClientAPI::AppCustomControlMessageEvent&)`
- `log(const ClientAPI::LogInfo&)`
- `pause_on_connection_timeout()`
- `external_pki_cert_request(ClientAPI::ExternalPKICertRequest&)`
- `external_pki_sign_request(ClientAPI::ExternalPKISignRequest&)`
- `socket_protect(openvpn_io::detail::socket_type, std::string, bool)`

The client lifecycle is explicit in the same header:

- `eval_config(const Config&)` parses and validates a profile.
- `provide_creds(const ProvideCreds&)` supplies credentials before connection when required.
- `connect()` is blocking and must run on a worker thread.
- `stop()` is documented as callable asynchronously while `connect()` is running.
- `connection_info()` is meaningful after the `CONNECTED` event.

## TUN builder callback contract

The pinned `openvpn/tun/builder/base.hpp` defines the callbacks below. The Android
implementation must collect settings first and create the Android TUN only in
`tun_builder_establish()`, which is the final builder callback.

| OpenVPN callback | Android handling |
| --- | --- |
| `tun_builder_new()` | Clear per-session builder state |
| `tun_builder_set_layer(3)` | Accept TUN; reject unsupported TAP layer |
| `tun_builder_set_remote_address(...)` | Retain for diagnostics; do not add as a TUN address |
| `tun_builder_add_address(...)` | Collect address and prefix |
| `tun_builder_set_route_metric_default(...)` | Retain metric metadata |
| `tun_builder_reroute_gw(ipv4, ipv6, ...)` | Add default route(s) to the collected route set |
| `tun_builder_add_route(...)` | Collect route and prefix |
| `tun_builder_exclude_route(...)` | Must be handled through verified Android route-emulation behavior or fail closed |
| `tun_builder_set_dns_options(...)` | Collect plain DNS server IPs; reject unsupported DoH/DoT semantics rather than silently downgrading |
| `tun_builder_set_mtu(...)` | Validate and collect MTU |
| `tun_builder_set_session_name(...)` | Collect display name |
| `tun_builder_set_allow_family(...)` | Apply only when supported by the device API; otherwise enforce a safe route policy |
| `tun_builder_establish()` | Synchronously call Android `establishTun(...)`; return the detached TUN fd or -1 |
| `tun_builder_teardown(...)` | Clear builder state; respect native ownership of the established fd |

The current Kotlin `OpenVpnVpnService.establishTun(...)` accepts paired address/prefix
and route/prefix arrays, DNS server IPs, MTU, and session name. It returns a detached
file descriptor. Native code becomes responsible for closing that descriptor after
the OpenVPN core has stopped using it.

Android's `VpnService.Builder` does not provide a direct equivalent for every OpenVPN
feature. Proxy directives, DNS-over-HTTPS/TLS policy, and route exclusions must not be
silently treated as successfully applied. The implementation must either support them
explicitly or reject the configuration with a clear error.

## JNI and threading requirements

1. Store `JavaVM*` at `JNI_OnLoad`; never retain a thread-local `JNIEnv*`.
2. Each OpenVPN callback obtains a valid `JNIEnv*` by checking/attaching the current
   native thread, and detaches only threads attached by the bridge.
3. Hold a global reference to the live service/controller while native callbacks may
   occur. Release it only after `stop()`, worker completion, and callback quiescence.
4. Check for Java exceptions after every callback. Clear/report them and fail the
   operation instead of continuing with a partially configured tunnel.
5. Forward `socket_protect` to `OpenVpnVpnService.protectSocketDescriptor(fd)`.
   A failed protect operation must fail the transport setup; it must not be ignored.
6. Run `connect()` on a dedicated worker. Expose an idempotent asynchronous stop
   operation and join/release native state only after the worker exits.
7. Never call UI methods directly from native callbacks. Forward immutable event/log
   data to a Kotlin controller, which posts UI updates on the main thread.
8. Do not expose a Connect action until Android VPN permission has been granted and
   the service lifecycle/foreground-notification behavior is implemented.

## Profile, credentials, and error policy

- Treat profile text as untrusted input; enforce the upstream maximum profile size.
- Run `eval_config()` before `connect()`; surface parse errors without starting a tunnel.
- Request username/password or private-key credentials only when the evaluated profile
  requires them. Do not log credentials or private-key material.
- External-PKI callbacks must return an explicit unsupported/error result until a
  secure Android Keystore implementation exists.
- Preserve TLS certificate verification. Do not add insecure verification overrides,
  arbitrary public proxy endpoints, or embedded third-party credentials.
- On disconnect, stop the core, close native-owned descriptors, clear global JNI refs,
  and stop the Android service cleanly.

## Required validation before enabling OpenVPN in the UI

1. Compile the native subclass against the exact pinned Core commit for ARM64.
2. Add native tests for callback ordering, invalid TUN settings, unsupported DNS/proxy
   features, socket-protection failure, stop-before-connect, and repeated stop.
3. Build the APK and inspect its manifest and ARM64 shared library.
4. Test VPN permission grant/revoke, app backgrounding, screen lock, network changes,
   and service destruction on Android 13.
5. Test only with a server/profile the user is authorized to access. Verify assigned
   interface addresses, routes, DNS, public egress IP, and absence of DNS/IP leakage.
6. Keep WireGuard regression tests green. Do not merge or enable OpenVPN based solely
   on a successful APK build.

## Current status

The Android TUN service and SWIG ClientAPI binding are present. The current draft PR
contains a concrete `OpenVPNClient` subclass and an initial JNI ownership/protection
bridge:

- `JNI_OnLoad` stores the process `JavaVM*`.
- Kotlin `OpenVpn3NativeSession` owns a native client handle and releases it idempotently.
- The client retains a global reference to the live `OpenVpnVpnService`.
- `socket_protect` calls `protectSocketDescriptor(fd)` on the Android service and
  fails closed on a missing callback, Java exception, or failed protection.
- Native callbacks do not yet start a worker or invoke `connect()`.

This is still not a working OpenVPN connection. TUN-builder callback translation,
profile evaluation/import, credential handling, worker-thread connect/stop lifecycle,
foreground-service behavior, and end-to-end server tests remain outstanding.
WireGuard remains the working VPN path.


## Exact callback signature details (verified against pinned headers)

The implementation must use the exact signatures from
`openvpn/tun/builder/base.hpp`, not simplified parameter lists:

- `tun_builder_add_address(address, prefix_length, gateway, ipv6, net30)`
  — the optional gateway and `net30` topology flag must be evaluated, not discarded.
- `tun_builder_reroute_gw(ipv4, ipv6, flags)`
  — preserve and interpret redirect-gateway flags; do not reduce this to unconditional
  default routes.
- `tun_builder_add_route(address, prefix_length, metric, ipv6)`
  and `tun_builder_exclude_route(address, prefix_length, metric, ipv6)`
  — preserve family and metric, and reject unsupported exclusion semantics.
- `tun_builder_set_dns_options(const DnsOptions&)`
  — this is the OpenVPN 3 DNS-options structure from
  `openvpn/client/dns_options.hpp`, not a plain string list. The Android bridge must
  inspect each server's transport and associated domains/search policy before deciding
  whether it can represent the configuration.
- `tun_builder_set_allow_family(af, allow)` and
  `tun_builder_set_allow_local_dns(allow)`
  — both affect leak prevention and must be implemented or cause a fail-closed result.
- `tun_builder_add_wins_server(address)`,
  `tun_builder_add_proxy_bypass(host)`,
  `tun_builder_set_proxy_auto_config_url(url)`,
  `tun_builder_set_proxy_http(host, port)`, and
  `tun_builder_set_proxy_https(host, port)`
  — these are distinct callbacks. Android support cannot be assumed; unsupported
  profile/server-pushed settings must be rejected explicitly.

The Android service's current `establishTun(...)` signature does not yet carry the
gateway/net30 metadata, redirect-gateway flags, route metrics, address-family policy,
local-DNS policy, DNS transport/domain metadata, WINS, or proxy settings. Therefore it
is not yet a complete implementation target. The native bridge must either extend the
service contract to represent supported settings or fail closed before calling
`VpnService.Builder.establish()`. It must never silently drop any of these settings.

The `OpenVPNClient` API also distinguishes `eval_config(const Config&)` on the client
from `OpenVPNClientHelper::eval_config(const Config&)` on the helper. The native
session object should use the client instance's method so the evaluated state belongs
to the same client that will later receive credentials and execute `connect()`.
