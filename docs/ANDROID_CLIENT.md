# FreeRoute Android client

FreeRoute is our custom app project. Users install the APK built from this repository; they do not need to install a separate consumer VPN app.

## OpenVPN 3 experimental transport

See [Android OpenVPN 3 Core — phase 1](ANDROID_OPENVPN3_PHASE1.md). The experimental build packages the upstream OpenVPN 3 C++ core for ARM64 and exposes a diagnostic button through JNI. It does **not** connect to OpenVPN servers yet. The existing WireGuard transport remains the only implemented connection path.

## Current MVP

- Native Android interface with connect/disconnect state.
- Distinguishes a locally started tunnel interface from a remote endpoint that has actually answered: after activation, the app checks WireGuard peer statistics for a handshake from the current connection session.
- Shows "Туннель включён · сервер не ответил" instead of claiming a successful connection when no handshake arrives; it continues checking in case the endpoint becomes reachable.
- The exit-country check stays disabled until a handshake has been observed for the current session.
- Imports and validates WireGuard .conf files through Android's document picker.
- Supports multiple local profiles so each device can keep a different selection.
- Uses the input file name as the profile label; the file name is not proof of the server's country.
- Stores profiles only in the app-private internal storage directory.
- Connects and disconnects using Android's VPN permission flow.
- Offers a manual **Проверить страну выхода** action when the tunnel is connected. It displays the public IP and country reported by `ipwho.is`; it does not run automatically or store the result.
- Uses WireGuard's embeddable tunnel engine through its published library API. Our UI and application flow are developed in this repository.
- Does not upload profiles or private keys to GitHub or a remote account service.

## Build

The GitHub Actions workflow named "Build FreeRoute Android APK" builds a debug APK on Android-source changes. Download the `freeroute-android-debug` artifact from a successful workflow run.

The debug APK is unsigned for distribution purposes and intended for personal installation/testing. A release signing setup is not configured yet.

## What is not ready

- There is no working country catalogue or server inventory yet. The country visible to websites is determined by the configured remote VPN endpoint, not by the client UI or profile label.
- A reachable server outside Russia is still required for country switching.
- Country discovery is only a diagnostic of the active connection, not a list of free VPN servers or a country selector.
- A WireGuard handshake confirms that the configured peer answered; it does not prove working internet egress, correct country, DNS safety, or leak protection.
- Full-tunnel IPv6/DNS leak testing and kill-switch behavior must be completed before relying on this app.
- The manual country check sends the current public IP as seen by the IP-geolocation service. If the tunnel drops during the request, that service may see the normal internet connection IP instead.
- Background operation on Xiaomi/POCO devices may require the user to allow background activity and disable battery restrictions. This needs real-device testing on the POCO X4 Pro 5G.

## Security

- Each imported configuration contains a client private key. Never commit .conf profiles, QR codes, or keys into this public repository.
- Profiles are stored inside the app's internal sandbox, which is not directly visible to other ordinary apps. Removing the app removes its local data.
- Android backup is disabled for this app so the local VPN profiles are not included in ordinary app backup.
- This MVP has no account, remote profile service, or telemetry.


## IPv6 behavior in generated FreeRoute profiles

The server generator assigns each device a private ULA IPv6 address and adds `::/0` alongside `0.0.0.0/0`. Until native IPv6 egress is implemented, the server drops forwarded IPv6 packets and blocks IPv6 access to its own services. IPv6-only websites will therefore be unavailable while connected. This is a server-side fail-closed measure, not a device kill switch: behavior after tunnel loss still needs testing on the POCO.
