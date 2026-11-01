# OpenVPN worker lifecycle — phase 4

This phase adds an internal native worker lifecycle.

- start() accepts credentials in memory, checks evaluated profile requirements, calls provide_creds() when username/password authentication is required, then starts connect() on a dedicated native thread.
- stopAndJoin() requests OpenVPN stop and joins the worker before native object destruction.
- Temporary JNI and C++ username/password buffers are overwritten after handoff.
- Credentials are not persisted or logged.
- External PKI and encrypted private-key password profiles are rejected.
- Kotlin exposes internal start/stop methods, but no UI invokes them.

## Remaining safety gates

This is not ready for user-facing connection. Android foreground-service notification and permission handling, VPN consent orchestration, lifecycle event forwarding, connection-state reporting, and end-to-end testing with an authorized .ovpn server are still required. WireGuard remains the only user-facing working tunnel.
