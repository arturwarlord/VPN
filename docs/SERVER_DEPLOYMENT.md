# Server deployment and security

This guide describes what must be in place before using the automated server workflow. **No server is currently deployed**, and this project has not yet confirmed a permanent free host that meets the €0 budget and non-Russia location requirement.

## Requirements

A suitable host needs:
- Ubuntu or Debian with root access (or an SSH user that can run non-interactive sudo).
- A globally routable public IPv4 address outside Russia.
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
2. Enter the server's public IPv4 address as `endpoint_ip` and the allowed UDP port.
3. Review the run. It first verifies the pinned SSH host key and non-interactive sudo before sending the installer.

The installer:
- Refuses to proceed without a valid explicit public IPv4 endpoint and valid port.
- Refuses to overwrite an existing `/etc/wireguard/wg0.conf` unless it carries the FreeRoute managed marker.
- Generates the WireGuard server key and client keys on the server.
- Stores client profiles in `/root/wireguard-clients/` with mode 600.
- Writes the candidate configuration atomically, backs up an existing FreeRoute-managed config before replacement, and attempts to restore the backup if WireGuard fails to start.
- Enables and starts `wg-quick@wg0`, and confirms the interface is active.

This setup currently enables IPv4 forwarding/NAT and generates client profiles with `AllowedIPs = 0.0.0.0/0`. It does not set up server-side IPv6 routing. Client apps warn if the profile lacks an IPv6 default route; this is not a full kill switch. Do not use it for sensitive traffic until leak and DNS behavior have been tested.

## Diagnose

Open **Actions → Diagnose WireGuard server → Run workflow** after deployment. It checks:
- `wg-quick@wg0` is active and enabled at boot.
- The managed config is present with permissions 600.
- IPv4 forwarding is enabled.
- Windows, Android and iPhone profiles exist with permissions 600 and no placeholder endpoint.

It prints counts and status only; it does not print any private keys or client profile contents. The check cannot verify the provider's external firewall, whether the client has connected, or whether a public-IP/geolocation lookup returns the expected country.

## Test from a client

After transferring one profile through an authenticated private channel:
1. Import the `.conf` into FreeRoute.
2. Connect and confirm the app reports a connected tunnel.
3. Visit a reputable public-IP check from that device and verify the observed IP belongs to the expected server region.
4. Run DNS leak and IPv6 leak tests. A successful handshake alone does not establish that all traffic is routed through the tunnel.
5. Repeat on a second network (for example Wi-Fi and mobile data) and after the phone resumes from sleep.

The initial server config is IPv4-only. Until IPv6 routing or a verified client-side fail-closed policy exists, never describe IPv6 leak protection as complete.

## Rollback and recovery

If deployment fails, inspect the Actions logs for the public, non-secret error message. On the host, check:
- `sudo systemctl status wg-quick@wg0`
- `sudo journalctl -u wg-quick@wg0 --no-pager -n 100`
- `sudo wg show wg0`

The installer saves a timestamped copy of an existing FreeRoute-managed config before replacing it. Do not publish that config: it contains the server private key and peer public keys, and backups of client profiles contain client private keys.
