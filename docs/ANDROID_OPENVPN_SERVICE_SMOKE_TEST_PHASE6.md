# OpenVPN foreground-service smoke test — phase 6

## What this phase adds

- A separate Activity action: **Test OpenVPN service (without connecting)**.
- The action refuses to run while the WireGuard tunnel is connected or connecting.
- Android 13+ notification permission is requested first; if declined, the app still
  explains that Android may hide the notification from the notification drawer.
- Android VPN consent is requested if it has not already been granted.
- After explicit user action and consent, the Activity starts the OpenVPN foreground
  service using `startForegroundService()` on Android 8.0+.
- The notification's Stop action stops the service.
- The typed `systemExempted` foreground-service start is used only on Android 14+;
  older supported Android versions use the two-argument `startForeground` call.

## This is not an OpenVPN connection

The smoke test deliberately does not:
- create a native OpenVPN session;
- parse or import an `.ovpn` profile;
- request a username or password;
- create a TUN interface;
- start `OpenVPNClient::connect()`;
- claim that traffic is routed through a VPN.

It only tests Android's VPN-consent and foreground-service/notification lifecycle.

## Device test plan

On the Android 13 POCO X4 Pro:
1. Ensure WireGuard is disconnected.
2. Open FreeRoute and tap **Test OpenVPN service (without connecting)**.
3. Grant VPN permission.
4. Grant notification permission if desired.
5. Confirm the persistent FreeRoute OpenVPN notification appears.
6. Tap Stop in the notification and confirm it disappears.
7. Repeat with notification permission denied; confirm the service can still start
   and Android's task manager indicates the foreground service.
8. Revoke VPN permission in Android settings and verify the next start is refused.

The user-facing OpenVPN connection action remains disabled until profile import,
credential handling, native status callbacks, service-owned native teardown, and
an authorized server end-to-end test are complete. WireGuard remains unchanged.
