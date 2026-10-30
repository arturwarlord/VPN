# FreeRoute OpenVPN Android TUN bridge — phase 1

This branch adds the Android-side service boundary for the OpenVPN 3 TUN integration.

## Added

- `OpenVpnVpnService`, a dedicated Android `VpnService` separate from the existing WireGuard service.
- `establishTun(...)`, which translates OpenVPN's interface addresses, routes, DNS servers, MTU and session name into an Android `VpnService.Builder`.
- The TUN file descriptor is detached and returned to the native caller. After `detachFd()`, native code owns the descriptor and must close it during teardown.
- `protectSocketDescriptor(fd)`, which delegates to Android `VpnService.protect(fd)` so the OpenVPN transport socket can bypass the VPN route.
- Manifest registration for the dedicated service.

## Important: not a working OpenVPN connection yet

This is an Android bridge endpoint, not the completed OpenVPN engine integration. The current native library still exposes the generated SWIG ClientAPI helper; it does not yet contain a concrete subclass of `ClientAPI::OpenVPNClient` that calls these service methods.

The next native phase must:

1. Implement all required `OpenVPNClient` callbacks, including `event`, `acc_event`, `log`, `pause_on_connection_timeout` and external-PKI callbacks.
2. Implement the TUN builder callbacks and forward their collected settings to `establishTun`.
3. Forward `socket_protect` to `protectSocketDescriptor`.
4. Run `connect()` on a worker thread and allow `stop()` from the service lifecycle thread.
5. Handle JNI thread attachment, global references, exceptions, descriptor ownership and teardown.
6. Add profile parsing/credentials and test with a real, authorized OpenVPN endpoint.

No OpenVPN connect button is exposed yet. The existing WireGuard implementation and its service are unchanged. Do not interpret the existence of this service as proof that OpenVPN traffic can currently pass through a tunnel.
