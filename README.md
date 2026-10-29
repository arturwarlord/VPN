# FreeRoute VPN — our own VPN app

We are building a custom VPN product for Android, Windows and iPhone. GitHub hosts our source code and builds the Android APK; GitHub itself is not the VPN exit server.

**Budget target: €0/month.** We will not rely on expiring trial credits or create paid resources without an explicit decision.

## Current status

- [x] Ubuntu/Debian WireGuard server bootstrap script.
- [x] Manual GitHub Actions server-deployment workflow.
- [x] Native Android app source with our own interface.
- [x] Android profile import and connect/disconnect controls.
- [x] GitHub Actions workflow that builds a test APK artifact.
- [ ] Verify the Android APK build and install it on POCO X4 Pro 5G.
- [ ] Find a sustainable, genuinely free VPN exit node outside Russia.
- [ ] Deploy a server and verify public IP, DNS and IPv6 behavior.
- [ ] Implement our own Windows and iOS client apps.
- [ ] Add a country/server selector backed by real endpoints.

The VPN service is **not live yet**. The Android client needs a valid configuration for a reachable VPN server. The country websites see is determined by that server's network location, not by a setting in the app.

## Our Android app

Source is under `app/`. FreeRoute uses a custom native Android UI and imports a WireGuard .conf profile. The tunnel engine is embedded as a library; users do not need to install a separate WireGuard consumer app. Imported profiles are kept in the app's private storage and are not sent to GitHub.

To build:
1. Open the repository's **Actions** tab.
2. Run **Build FreeRoute Android APK** manually, or use the run triggered by a source change.
3. Open a successful workflow run and download the `freeroute-android-debug` artifact.
4. Extract the APK and install it on the Android device for testing.

The current APK is a debug build, not a release-signed public distribution. This first version imports a server profile; a country list will only be meaningful once real endpoints exist. See [Android client details](docs/ANDROID_CLIENT.md).

## Server and €0 constraint

A working VPN exit node must be reachable from the internet and located outside Russia. A phone at home cannot independently make its public IP appear to belong to a different country. A home Android phone without root also is not currently configured as the public WireGuard server in this project.

We have not confirmed a long-term free VPS that meets the budget, region and networking requirements. Oracle Cloud was not suitable in our setup, so we are not treating it as the next step. Until a free server is confirmed, we will not claim that country switching works.

If a suitable Ubuntu/Debian VPS is eventually available, the existing deployment workflow can be used. It requires these repository Action secrets:
- `VPN_HOST` — public IP or DNS name used for SSH.
- `VPN_USER` — SSH account able to run sudo non-interactively.
- `VPN_SSH_KEY` — private SSH key. Never commit it.

The manual workflow is **Actions → Deploy WireGuard VPN → Run workflow**. The server must be reachable over SSH, and its firewall must allow UDP/51820. Do not run the workflow until the host and SSH access have been verified.

## Keep VPN profiles private

The installer stores generated profiles on the server under `/root/wireguard-clients/`. Each profile contains a private key. Never commit a profile, QR code, private key or server credential to this public repository. Use authenticated access to transfer profiles to your own devices.

## Security and testing limitations

- The initial server script is IPv4-focused; IPv6 tunneling and leak prevention are not complete.
- DNS behavior, kill-switch behavior, sleep/resume and battery restrictions must be tested before relying on the client.
- The POCO/Xiaomi background process behavior has not been verified on the user's phone yet.
- A VPN does not guarantee that every website accepts a country: some services also check account region, cookies, payment method or other signals.
- Keep SSH restricted, patch server software, and revoke a lost device by removing its peer from `/etc/wireguard/wg0.conf` and restarting `wg-quick@wg0`.
- Use the system only in accordance with applicable law and network/provider policies.

## Key files

- `app/` — our Android client.
- `docs/ANDROID_CLIENT.md` — Android client scope and limitations.
- `scripts/setup-wireguard.sh` — server bootstrap script.
- `.github/workflows/android-client.yml` — build the Android test APK.
- `.github/workflows/ci.yml` — syntax and secret-material checks.
- `.github/workflows/deploy.yml` — manual server deployment over SSH.
