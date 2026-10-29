# FreeRoute VPN — our own VPN app

We are building a custom VPN product for Android, Windows and iPhone. GitHub hosts our source code and build workflows; GitHub itself is not the VPN exit server.

**Budget target: €0/month.** We will not rely on expiring trial credits or create paid resources without an explicit decision.

## Current status

- [x] Ubuntu/Debian WireGuard server bootstrap script with explicit endpoint validation, safe permissions and rollback if service startup fails.
- [x] 24 automated endpoint-validation tests for malformed, private, local, special-purpose and otherwise non-public addresses/ports.
- [x] Manual GitHub Actions server-deployment workflow with verified SSH host-key pinning.
- [x] Read-only server diagnostics that do not print private client profiles.
- [x] Native Android client with local multi-profile management, connect/disconnect controls and an IPv6-route warning.
- [x] Android debug APK built successfully by GitHub Actions.
- [x] Custom Windows client source and successful Windows x64 package build.
- [x] iOS SwiftUI app and Packet Tunnel extension compile successfully as an unsigned build in GitHub Actions.
- [x] CI checks Bash syntax in workflow steps, checks that private key material is not committed, and runs the 24 endpoint-validation tests.
- [x] iOS tunnel configuration is stored in a shared Keychain group; VPN preferences retain only a Keychain reference. The app avoids overwriting unrelated VPN profiles.
- [ ] Install/test Android and Windows clients on real devices with a valid server profile.
- [ ] Sign and install the iOS app with an Apple developer team that has the required Network Extension entitlement.
- [ ] Find a sustainable, genuinely free VPN exit node outside Russia.
- [ ] Deploy a server and verify public IP, DNS and IPv6 behavior.
- [ ] Verify end-to-end country switching on all clients.

The VPN service is **not live yet**. No server has been provisioned or deployed. The country websites see is determined by the remote server's network location, not by a label in the app.

Latest repository validation (including all 24 endpoint tests): [GitHub Actions CI run](https://github.com/arturwarlord/VPN/actions/runs/40953439683).

## Android client

Source: `app/`. FreeRoute has its own native UI, local profile picker, profile import, connect/disconnect flow, and an IPv6-route warning. It embeds WireGuard's tunnel engine as a library; it does not require the user to install a separate WireGuard consumer app. Imported profiles stay in the app's private storage and are not uploaded to GitHub.

A debug APK has been built successfully. You can download it from [this verified build artifact](https://github.com/arturwarlord/VPN/actions/runs/40945904848) or use [Build FreeRoute Android APK](https://github.com/arturwarlord/VPN/actions/workflows/android-client.yml).

This is a debug build, not a release-signed public distribution. The app cannot connect until a valid profile for a reachable server is available. On POCO/Xiaomi, background and battery-restriction behavior still needs real-device testing.

Details: [Android client notes](docs/ANDROID_CLIENT.md).

For a temporary real-tunnel smoke test before our own server exists, see [Client smoke test](docs/CLIENT_SMOKE_TEST.md). This uses a third-party provider endpoint and does not count as a FreeRoute server.

## Windows client

Source: `windows/`. The Windows client provides its own profile list, import, connection and disconnection controls. The build workflow checks the Authenticode signature of the official WireGuard Windows MSI before extracting the tunnel engine into the FreeRoute package. The engine is bundled, so a user should not need to install a separate VPN consumer app.

The first x64 package build completed successfully:
[Open the Windows build run](https://github.com/arturwarlord/VPN/actions/runs/40946493537)

To obtain the package, open that run and download the `freeroute-windows-x64` artifact. It is a development package and still needs a real endpoint/profile connection test. The app requests administrator privileges because Windows tunnel services and networking drivers require elevation.

Details: [Windows client notes](docs/WINDOWS_CLIENT.md).

## iPhone client

Source: `ios/`. The SwiftUI app and Network Extension Packet Tunnel provider use the embeddable WireGuardKit engine. The latest unsigned app build and Packet Tunnel extension compile, pass bundle-metadata checks and are packaged by GitHub Actions:
[Open the successful iOS build](https://github.com/arturwarlord/VPN/actions/runs/40951584935)

Active tunnel configuration is saved in Keychain using the shared App Group `group.com.arturwarlord.freeroute`; the system VPN preferences store a persistent reference rather than the client private key text. Imported `.conf` files remain inside the protected local app sandbox and are excluded from ordinary backup.

An unsigned CI build cannot be installed as a working VPN on a personal iPhone. Installation and operation require signing with an Apple developer team, enabling the Packet Tunnel Network Extension entitlement, and registering the App Group for both the app and extension in the provisioning profiles. The actual tunnel and Keychain access must still be tested on a real iPhone against a reachable endpoint.

Details: [iOS client notes](docs/IOS_CLIENT.md).

## Server and €0 constraint

A working VPN exit node must be reachable from the internet and located outside Russia. A home phone cannot independently make its public IP appear to belong to a different country. The POCO runs Android 13 without root, and this project does not currently configure it as an internet-facing server.

We have not confirmed a long-term free VPS that meets the budget, region and networking requirements. Oracle Cloud was not suitable in our setup, so it is not the next step. Until a free server is confirmed, we will not claim that country switching works.

### Prepare deployment only after a suitable free server is confirmed

The manual workflow is **Actions → Deploy WireGuard VPN → Run workflow**. It requires these repository Action secrets:
- `VPN_HOST` — server hostname or IP used for SSH.
- `VPN_USER` — SSH account allowed to run `sudo -n`.
- `VPN_SSH_KEY` — SSH private key. Never commit it.
- `VPN_KNOWN_HOSTS` — the server's known_hosts line, with its public host key verified independently through the provider's console or trusted documentation.

The deploy workflow deliberately does **not** trust a fresh `ssh-keyscan` result as proof of identity: that would accept a potential man-in-the-middle key. Verify the server host-key fingerprint out-of-band, then save the matching known_hosts line as `VPN_KNOWN_HOSTS`.

The workflow validates the endpoint as a globally routable IPv4 address, checks non-interactive SSH sudo access, and installs WireGuard. The server's provider firewall must allow the configured UDP port (default 51820). Do not run the workflow before the host, SSH access and firewall have been verified.

After deployment, use **Actions → Diagnose WireGuard server → Run workflow**. The read-only workflow checks service status, boot enablement, forwarding, config permissions and the three generated client profiles. It intentionally does not print profile contents or private keys. A successful server diagnostic still cannot prove the UDP port is reachable from every network or that a client has completed a handshake.

See [server deployment and security notes](docs/SERVER_DEPLOYMENT.md).

## Keep VPN profiles private

The installer stores generated profiles on the server under `/root/wireguard-clients/`. Each profile contains a private key. Never commit a profile, QR code, private key or server credential to this public repository. Use authenticated access to transfer profiles to your own devices.

## Security and testing limitations

- The server setup currently tunnels IPv4 only; full IPv6 tunneling is not configured. Client apps warn when a profile has no IPv6 default route, but that warning is not a complete leak-prevention mechanism.
- DNS behavior, server routing and kill-switch behavior still need end-to-end testing.
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
- `docs/SERVER_DEPLOYMENT.md` — deployment requirements and SSH pinning.
- `docs/FREE_HOST_RESEARCH.md` — free-server candidates reviewed and reasons none is approved yet.
- `docs/CLIENT_SMOKE_TEST.md` — safe temporary third-party WireGuard profile test before our own server exists.
- `scripts/setup-wireguard.sh` — server bootstrap script.
- `.github/workflows/android-client.yml` — Android debug APK build.
- `.github/workflows/windows-client.yml` — Windows package build.
- `.github/workflows/ios-client.yml` — unsigned iOS build.
- `.github/workflows/ci.yml` — syntax, required-file, shell-step, endpoint-validation and secret-material checks.
- `.github/workflows/deploy.yml` — manual server deployment over pinned SSH.
- `.github/workflows/diagnose-server.yml` — read-only server diagnosis.
