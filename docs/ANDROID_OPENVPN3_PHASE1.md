# Android OpenVPN 3 Core — phase 1

**Status:** native-core integration and diagnostic only. This is not yet a working OpenVPN tunnel.

## License scope

FreeRoute selects the **Mozilla Public License 2.0 (MPL 2.0)** option offered by upstream OpenVPN 3 for the OpenVPN 3 Core component only. Upstream also offers AGPL-3.0-only, but this build chooses MPL 2.0 for this component.

This selection does not relicense FreeRoute, change the WireGuard Tunnel Library's Apache-2.0 license, or place unrelated Kotlin/C#/Swift code under MPL. Any future modifications to covered OpenVPN Core source files must retain their MPL notices and comply with the MPL. The build fetches the exact upstream source commit below.

- Upstream: https://github.com/OpenVPN/openvpn3
- Pinned commit: `0abc8313b8fe5f63dbebc10d53094952957845d9`
- Component license: MPL 2.0, included in `app/src/main/assets/OpenVPN3-MPL-2.0.txt`
- Upstream license statement: https://github.com/OpenVPN/openvpn3/blob/0abc8313b8fe5f63dbebc10d53094952957845d9/LICENSE.md
- Pinned source: https://github.com/OpenVPN/openvpn3/tree/0abc8313b8fe5f63dbebc10d53094952957845d9

## What is implemented

- GitHub Actions fetches the exact pinned OpenVPN 3 Core commit.
- vcpkg 2026.10.16 builds the Android ARM64 dependencies from source: Asio 1.32.0, fmt 12.2.0, LZ4 1.10.0 and OpenSSL 3.6.5. Their full licenses are included in APK assets and in the in-app **О лицензиях** screen.
- CMake builds `client/ovpncli.cpp` and a small JNI bridge into `libfreeroute_openvpn3.so`; the NDK strips debug sections before packaging.
- A post-build CI step extracts the `.so` from the APK and verifies that it is an ARM64/AArch64 ELF with the expected JNI entry point.
- Gradle packages the library for `arm64-v8a`, the architecture used by POCO X4 Pro 5G.
- The app's **Диагностика OpenVPN Core** button calls upstream `ClientAPI::OpenVPNClientHelper::platform()` through JNI.
- The existing WireGuard code path, profile storage and connection controls remain separate and unchanged.

## What is not implemented yet

The diagnostic does **not** start an OpenVPN connection, parse/import `.ovpn` profiles, request Android VPN permission, create a TUN interface, add routes or DNS, protect the external transport socket, or manage reconnection. It does not make the app a working OpenVPN client by itself.

The next stage is a dedicated Android `VpnService` and native `OpenVPNClient` subclass implementing `TunBuilderBase`, forwarding `socket_protect()` to Android's `VpnService.protect(fd)`, returning the established TUN descriptor, applying routes/DNS/MTU, and owning connect/stop lifecycle. The app will not report OpenVPN connected until native connection success and route/DNS/exit-IP tests pass.

## Build

Run **Actions → Build FreeRoute Android APK**. The workflow installs Android NDK 27.2.12479018, checks out the pinned OpenVPN Core source, builds dependencies with vcpkg, builds the JNI library and packages the debug APK.

The phase-one APK is ARM64-only. This is a build test; real-device validation on POCO X4 Pro 5G is still required. GitHub-hosted build capacity is used; no VPS or paid hosting is provisioned.
