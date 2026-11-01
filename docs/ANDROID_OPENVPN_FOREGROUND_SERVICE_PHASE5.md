# FreeRoute OpenVPN foreground service — phase 5

## Added in this draft

- The dedicated OpenVPN `VpnService` now has an explicit foreground lifecycle.
- The service accepts only internal start-foreground and stop actions.
- Start is refused unless Android VPN consent has already been granted.
- A low-importance notification channel and ongoing notification are created.
- The notification opens FreeRoute and provides a Stop action.
- The manifest declares the foreground-service permissions, notification permission,
  and the `systemExempted` foreground-service type used by a VPN service.
- The existing WireGuard service declaration and WireGuard connection flow are unchanged.

## Important scope boundary

This phase does **not** start the native OpenVPN worker, import an `.ovpn` profile,
collect credentials, or claim that a tunnel is connected. The notification text
explicitly says that the service is active but the connection has not started.

The Activity does not yet invoke these service actions. That is intentional:
VPN consent UI, profile selection/import, credential handling, native state
callbacks, and a real authorized server test must be integrated before adding
a user-facing OpenVPN Connect action.

## Android behavior

- The Activity must call `VpnService.prepare(activity)` and receive the user's
  approval before starting this service.
- Start the service while the Activity is visible, using
  `startForegroundService()` on Android 8.0+.
- The service immediately enters foreground state and posts its persistent
  notification.
- Android 13+ notification permission should be requested by the Activity for
  normal notification-drawer visibility. Denial does not authorize the app to
  omit the foreground notification.
- The VPN service is not sticky. Android process recreation must not silently
  restart a VPN session without a fresh, explicit user action.
- Stop action removes the notification and stops the service. Native worker
  teardown will be connected in the next lifecycle integration phase.

## Validation still required

1. Build and inspect the APK/manifest on CI.
2. Test consent granted, denied, and revoked on Android 13.
3. Test notification permission granted and denied.
4. Test start/stop repeatedly and verify notification removal.
5. Integrate native worker ownership and event forwarding.
6. Test an authorized OpenVPN endpoint and verify egress country, IPv4/IPv6,
   DNS behavior, and absence of traffic leaks before exposing OpenVPN in UI.

WireGuard remains the only supported user-facing working tunnel.
