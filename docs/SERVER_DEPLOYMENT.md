# Server deployment and security

This guide describes what must be in place before using the automated server workflow. **No server is currently deployed**, and this project has not yet confirmed a permanent free host that meets the €0 budget and non-Russia location requirement.

## Requirements

A suitable host needs:
- Ubuntu or Debian with root access (or an SSH user that can run non-interactive sudo).
- A globally routable public IPv4 or IPv6 address outside Russia.
- Permission to receive UDP on the chosen WireGuard port (default 51820) in both the host firewall and the provider/network firewall.
- Enough outbound traffic allowance for your expected use, with no automatic conversion to paid service that would violate the budget.
- Stable availability, kernel support for WireGuard and a way to verify SSH host identity.

A PaaS container or a service that sleeps is not a substitute for a full VPN server. GitHub Actions is a build/deployment runner, not a permanent VPN exit node.

## GitHub Actions secrets

Only set these after the server is selected and its SSH host key is verified:

| Secret | Purpose |
| --- | --- |
| `VPN_HOST` | Hostname or address used for SSH. |
| `VPN_USER` | SSH account with `sudo -n` permission. |
| `VPN_SSH_KEY` | Private SSH key for that account. |
| `VPN_KNOWN_HOSTS` | Known-hosts entry containing the verified server public host key. |

Keep the private SSH key and client profile private. Do not commit them to this public repository or paste them into workflow logs.

### Pin the SSH host key correctly

The deploy workflow intentionally does not use `ssh-keyscan` to establish trust at connection time. A key fetched over the same potentially intercepted connection cannot prove the server's identity.

Obtain the server's SSH host-key fingerprint or public host key from the provider's trusted console or other authenticated channel. Verify the fingerprint, then save a matching known_hosts line as the `VPN_KNOWN_HOSTS` secret. The hostname portion must match `VPN_HOST` as used by SSH. If the line doesn't match, the workflow should fail closed rather than ignore the mismatch.

## Deploy

After the free server and its network firewall are confirmed:
1. Open **Actions → Deploy WireGuard VPN → Run workflow**.
2. Enter the server's public IPv4 or IPv6 address as `endpoint_ip` and the allowed UDP port.
3. Review the run. It first verifies the pinned SSH host key and non-interactive sudo before sending the installer.

Before SSH deployment, the workflow queries the free HTTPS geolocation endpoint `ipwho.is` for the provided public endpoint and refuses deployment if the reported country is Russia or the API cannot return a valid matching IP/country. This is a best-effort database lookup, not cryptographic proof of the server's location. Cross-check the provider's region and verify the actual exit IP from a connected client. This lookup sends the already-public endpoint IP to that third-party API; see [its documentation](https://ipwhois.io/ru/documentation).

The installer:
- Refuses to proceed without a valid explicit public IPv4 or IPv6 endpoint and valid port.
- Refuses to overwrite an existing `/etc/wireguard/wg0.conf` unless it carries the FreeRoute managed marker and contains exactly the three managed `windows`, `android` and `iphone` peers. It refuses to replace a managed config containing custom peers.
- Generates the WireGuard server key and client keys on the server.
- Stores client profiles in `/root/wireguard-clients/` with mode 600.
- Writes the candidate configuration atomically, backs up an existing FreeRoute-managed config before replacement, and attempts to restore the backup if WireGuard fails to start.
- Enables and starts `wg-quick@wg0`, and confirms the interface is active.

The outer WireGuard endpoint may now be a globally routable IPv4 or IPv6 literal. IPv6 literals are normalized and bracketed in generated profiles (for example, `Endpoint = [2606:4700:4700::1111]:51820`). The server still requires a working IPv4 default route and NAT for IPv4 internet egress. The installer enables IPv4 forwarding/NAT and generates client profiles with `AllowedIPs = 0.0.0.0/0, ::/0`. It installs a dedicated `FREEROUTE_FORWARD` chain at the top of the host `FORWARD` chain: only public-internet traffic from `wg0` to the detected WAN interface is accepted; client traffic to private, loopback, link-local, carrier-grade NAT, documentation, benchmarking, multicast and reserved IPv4 ranges is dropped; forwarding to every other interface and unsolicited traffic into `wg0` is dropped. A separate first-position `INPUT` rule blocks VPN clients from reaching services on the VPN host itself. The installer refuses to flush an existing chain unless its FreeRoute ownership marker is present.

This server-side isolation is not a full client kill switch. Generated profiles route IPv4 and IPv6 defaults through WireGuard; until native IPv6 egress is implemented, the server deliberately blocks IPv6 forwarding and VPN-client access to server services. IPv6-only sites will therefore be unavailable while connected. This does not prevent traffic from returning to the normal network if the tunnel drops; DNS behavior, provider firewall reachability and on-device routing still require end-to-end tests. Do not use it for sensitive traffic until those tests have passed.

## Diagnose

Open **Actions → Diagnose WireGuard server → Run workflow** after deployment. It checks:
- `wg-quick@wg0` is active and enabled at boot.
- The managed config is present with permissions 600.
- IPv4 forwarding is enabled.
- The NAT rule is present, the exact approved `FREEROUTE_FORWARD` rules are present in the expected order, and its jump is the first `FORWARD` rule.
- The first `INPUT` rule drops all traffic arriving from `wg0`, preventing VPN clients from reaching services on the VPS itself.
- The chain blocks known private and special-purpose IPv4 destinations and forwards client traffic only out through the detected WAN interface.
- Windows, Android and iPhone profiles exist with permissions 600 and no placeholder endpoint.

It prints counts and status only; it does not print any private keys or client profile contents. The check cannot verify the provider's external firewall, whether the client has connected, or whether a public-IP/geolocation lookup returns the expected country.

## Test from a client

After transferring one profile through an authenticated private channel:
1. Import the `.conf` into FreeRoute.
2. Connect and confirm the app reports a connected tunnel.
3. Visit a reputable public-IP check from that device and verify the observed IP belongs to the expected server region.
4. Run DNS leak and IPv6 leak tests. A successful handshake alone does not establish that all traffic is routed through the tunnel.
5. Repeat on a second network (for example Wi-Fi and mobile data) and after the phone resumes from sleep.

The outer transport can use IPv6 when the server has a reachable public IPv6 address and its firewall allows the configured UDP port. Inner IPv6 internet egress remains intentionally blocked until a separate, tested native IPv6 egress policy is implemented. An IPv6 endpoint alone does not provide IPv4 egress; the server must still have working IPv4 routing/NAT for IPv4 websites.

## Rollback and recovery

If deployment fails, inspect the Actions logs for the public, non-secret error message. On the host, check:
- `sudo systemctl status wg-quick@wg0`
- `sudo journalctl -u wg-quick@wg0 --no-pager -n 100`
- `sudo wg show wg0`

The installer saves a timestamped copy of an existing FreeRoute-managed config before replacing it. Do not publish that config: it contains the server private key and peer public keys, and backups of client profiles contain client private keys.


## IPv6 fail-closed policy

Generated client profiles assign a private ULA IPv6 address and route both `0.0.0.0/0` and `::/0` into WireGuard. The server currently does **not** provide IPv6 internet egress. Instead, its `ip6tables` rules put a drop rule first in both `FORWARD` and `INPUT` for traffic arriving on `wg0`. This prevents VPN clients from sending IPv6 traffic out through the host's unrelated network interface or reaching services on the host over the tunnel.

Consequences:
- IPv4 internet access is the only intended working internet path.
- IPv6-only destinations will not load while connected until a separately designed and tested IPv6 egress path is deployed.
- This server-side policy does not implement a device-level kill switch. When a tunnel disconnects, the operating system may resume using its normal network; real-device leak and reconnect tests remain mandatory.
- The read-only diagnostic workflow verifies the IPv6 drop rules and the IPv4/IPv6 routes in each generated profile. It does not prove external reachability or zero leakage on a client.
