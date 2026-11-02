# FreeRoute OpenVPN native exit cleanup — phase 11

## Added

- JNI native events are marshalled onto Android's main looper before updating service notifications.
- A fatal native event or terminal `EXITING` event schedules cleanup on a separate thread.
- Cleanup removes the service-owned session under the lifecycle lock, requests native stop/join, then closes the JNI session.
- The native callback thread never attempts to join itself.
- Once a native worker exits, the foreground notification reports that OpenVPN stopped and allows a later retry.

## Limits

- This does not expose a user-facing OpenVPN Connect button.
- A `CONNECTED` event is still not proof that traffic, DNS, IPv6, or exit-country routing works.
- No server profile or credentials are included; no real server connection is claimed as tested.
- WireGuard is unchanged.
