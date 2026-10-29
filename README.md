# FreeRoute VPN — our own VPN app

We are building a custom VPN product for Android, Windows and iPhone. GitHub hosts our source code and build workflows; GitHub itself is not the VPN exit server.

**Budget target: €0/month.** We will not rely on expiring trial credits or create paid resources without an explicit decision.

## Current status

- [x] Ubuntu/Debian WireGuard server bootstrap script.
- [x] Manual GitHub Actions server-deployment workflow.
- [x] Native Android client with local multi-profile management, connect/disconnect controls and an IPv6-route warning.
- [x] Android debug APK built successfully by GitHub Actions.
- [x] Custom Windows client source and successful Windows x64 package build.
- [x] iOS SwiftUI app and Packet Tunnel extension source scaffolded.
- [ ] Complete and verify the iOS build in GitHub Actions.
- [ ] Install/test Android and Windows clients on real devices with a valid server profile.
- [ ] Sign the iOS app with an Apple developer team that has the required Network Extension entitlement.
- [ ] Find a sustainable, genuinely free VPN exit node outside Russia.
- [ ] Deploy a server and verify public IP, DNS and IPv6 behavior.
- [ ] Verify end-to-end country switching on all clients.

The VPN service is **not live yet**. No server has been provisioned or deployed. The country websites see is determined by the remote server's network location, not by a label in the app.

## Android client

Source: `app/`. FreeRoute has its own native UI, local profile picker, profile import, connect/disconnect flow, and an IPv6-route warning. It embeds WireGuard's tunnel engine as a library; it does not require the user to install a separate WireGuard consumer app. Imported profiles stay in the app's private storage and are not uploaded to GitHub.

To obtain the test APK:
1. Open [Build FreeRoute Android APK](https://github.com/arturwarlord/VPN/actions/workflows/android-client.yml).
2. Open the latest successful run and download the `freeroute-android-debug` artifact.
3. Extract the file named `app-debug.apk` from the artifact and install it for personal testing.

This is a debug build, not a release-signed public distribution. The app cannot connect until a valid profile for a reachable server is available. On POCO/Xiaomi, background and battery-restriction behavior still needs real-device testing.

Details: [Android client notes](docs/ANDROID_CLIENT.md).

## Windows client

Source: `windows/`. The Windows client provides its own profile list, import, connection and disconnection controls. The build workflow checks the Authenticode signature of the official WireGuard Windows MSI before extracting the tunnel engine into the FreeRoute package. The engine is bundled, so a user should not need to install a separate VPN consumer app.

The first x64 package build completed successfully:
[Open the Windows build run](https://github.com/arturwarlord/VPN/actions/runs/40946493537)

To obtain the package, open that run and download the `freeroute-windows-x64` artifact. It is a development package and still needs a real endpoint/profile connection test. The app requests administrator privileges because Windows tunnel services and networking drivers require elevation.

Details: [Windows client notes](docs/WINDOWS_CLIENT.md).

## iPhone client

Source: `ios/`. The SwiftUI app and Network Extension Packet Tunnel provider use the embeddable WireGuardKit engine. The workflow compiles an unsigned build for inspection:
[Open the iOS build workflow](https://github.com/arturwarlord/VPN/actions/workflows/ios-client.yml)

An unsigned CI build cannot be installed as a working VPN on a personal iPhone. Installation and operation require signing with an Apple developer team and provisioning the Packet Tunnel Network Extension entitlement. The actual tunnel must also be tested against a reachable endpoint.

Details: [iOS client notes](docs/IOS_CLIENT.md).

## Server and €0 constraint

A working VPN exit node must be reachable from the internet and located outside Russia. A home phone cannot independently make its public IP appear to belong to a different country. The POCO runs Android 13 without root, and this project does not currently configure it as an internet-facing server.

We have not confirmed a long-term free VPS that meets the budget, region and networking requirements. Oracle Cloud was not suitable in our setup, so it is not the next step. Until a free server is confirmed, we will not claim that country switching works.

If a suitable Ubuntu/Debian VPS is eventually available, the existing deployment workflow can be used. It requires these repository Action secrets:
- `VPN_HOST` — public IP or DNS name used for SSH.
- `VPN_USER` — SSH account able to run sudo non-interactively.
- `VPN_SSH_KEY` — private SSH key. Never commit it.

The manual workflow is **Actions → Deploy WireGuard VPN → Run workflow**. The server must be reachable over SSH, and its firewall must allow UDP/51820. Do not run the workflow until the host and SSH access have been verified.

## Keep VPN profiles private

The installer stores generated profiles on the server under `/root/wireguard-clients/`. Each profile contains a private key. Never commit a profile, QR code, private key or server credential to this public repository. Use authenticated access to transfer profiles to your own devices.

## Security and testing limitations

- The initial server script is IPv4-focused; full IPv6 tunneling and leak prevention are not complete.
- A warning about a missing IPv6 default route is not a guarantee against leaks. Server-side IPv6 routing, DNS behavior and kill-switch behavior still need testing.
- No country selector backed by real servers exists yet. Imported profile names are labels only.
- Android sleep/resume and POCO battery restrictions have not been verified on the user's phone.
- A VPN does not guarantee that every website accepts a country: some services also check account region, cookies, payment method or other signals.
- Keep SSH restricted, patch server software, and revoke a lost device by removing its peer from `/etc/wireguard/wg0.conf` and restarting `wg-quick@wg0`.
- Use the system only in accordance with applicable law and network/provider policies.

## Key files

- `app/` — Android client.
- `windows/` — Windows client.
- `ios/` — iOS app and Packet Tunnel extension.
- `docs/ANDROID_CLIENT.md` — Android client notes.
- `docs/WINDOWS_CLIENT.md` — Windows client notes.
- `docs/IOS_CLIENT.md` — iOS client notes.
- `scripts/setup-wireguard.sh` — server bootstrap script.
- `.github/workflows/android-client.yml` — Android debug APK build.
- `.github/workflows/windows-client.yml` — Windows package build.
- `.github/workflows/ios-client.yml` — unsigned iOS build.
- `.github/workflows/ci.yml` — syntax, required-file and secret-material checks.
- `.github/workflows/deploy.yml` — manual server deployment over SSH.
