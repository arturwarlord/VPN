# OpenVPN native event bridge — phase 9

## Added

- The native OpenVPN client resolves the Android service callback `onNativeEvent(String, Boolean, Boolean)` during construction.
- OpenVPN `Event.name`, `Event.error`, and `Event.fatal` are forwarded from the worker thread using the existing JNI attach/detach helper.
- `Event.info`, custom control-channel payloads, and native log text are not forwarded to Android or written to notifications.
- Android maps a small allowlist of event names to generic Russian notification statuses. Unknown names produce a generic status.
- JNI exceptions are cleared and local references released so a callback failure does not leak into OpenVPN's worker thread.

## Safety boundary

This phase only wires the callback path. It does not invoke `start()`, expose an OpenVPN Connect button, request credentials, or establish a TUN. A notification saying that OpenVPN established a connection is deliberately qualified: traffic and exit-country routing remain unverified.

WireGuard is unchanged. Keep this PR draft and do not merge until the callback path and later connection lifecycle are tested on a device with an authorized profile/server.
