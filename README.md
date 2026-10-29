# Personal VPN — WireGuard

Goal: a personal VPN for Windows, Android and iPhone with a target cost of €0/month. GitHub stores and deploys the code; it is not the VPN server.

## Status

- [x] Initial project files and GitHub Actions validation
- [x] Ubuntu/Debian WireGuard bootstrap
- [x] Manually triggered deployment workflow
- [ ] Provision a genuinely free VPS outside Russia
- [ ] Deploy and verify on a real server
- [ ] Securely transfer/import profiles for each device
- [ ] Test public IP, DNS and IPv6 leaks

The VPN is not live yet: no server has been provisioned or deployed.

## Free VPS choice

First check [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/) and [official Always Free limits](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm). Eligible compute can remain free within published limits, but signup verification, regional capacity and resource selection matter. A payment card may be required for verification. Prefer an available European home region outside Russia, such as Frankfurt or Amsterdam, if offered. Select only resources explicitly marked Always Free; do not accept paid resources or rely on expiring trial credits. If no eligible VM is available, stop rather than incur charges.

## GitHub setup

In repository Settings → Secrets and variables → Actions, create these repository secrets:

- VPN_HOST — VPS public IP or DNS name for SSH.
- VPN_USER — SSH account able to run sudo without an interactive password for this workflow.
- VPN_SSH_KEY — private SSH key for that account. Never commit it.

The workflow is manual only. Open Actions → Deploy WireGuard VPN → Run workflow, enter the public IPv4 of your VPS as endpoint_ip and port 51820. The VM must be Ubuntu 22.04/24.04 or compatible Debian, with SSH reachable and sudo available. In the provider firewall, allow SSH TCP/22 from your own IP where possible and UDP/51820 for WireGuard.

## Client profiles — keep private

The installer creates root-only files on the VPS:

- /root/wireguard-clients/windows.conf
- /root/wireguard-clients/android.conf
- /root/wireguard-clients/iphone.conf

They contain private keys. The workflow deliberately does not upload them as artifacts or print them in logs because this repository is public. Retrieve them only through authenticated SSH or the provider's authenticated browser console, and store them privately. Install the official [WireGuard clients](https://www.wireguard.com/install/) on Windows, Android and iOS, then import each matching profile. Never share a profile or QR code.

## Security limitations

- The initial version tunnels IPv4 only. IPv6 is not tunneled yet and may bypass the VPN depending on the device/network. Test IPv6 leaks before relying on it; IPv6 support and leak prevention are next implementation steps.
- A VPN does not guarantee access to every service: sites may also check account country, payment method, cookies or other signals.
- Keep SSH restricted, patch the OS, and revoke a lost device by removing its peer from /etc/wireguard/wg0.conf and restarting wg-quick@wg0.
- Use only in accordance with applicable law and the provider's acceptable-use policy.

## Files

- scripts/setup-wireguard.sh — server bootstrap and starter profiles.
- .github/workflows/ci.yml — syntax and secret-material checks.
- .github/workflows/deploy.yml — manual deployment over SSH.
