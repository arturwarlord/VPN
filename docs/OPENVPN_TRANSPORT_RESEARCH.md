# OpenVPN transport feasibility and public endpoint research

**Checked:** 30 October 2026  
**FreeRoute requirement:** custom clients for Android, Windows and iPhone; €0 budget; any exit country except Russia is acceptable; WireGuard remains the preferred protocol for a server we control.

## Executive decision

OpenVPN is technically feasible as a **second transport** for FreeRoute, and currently active volunteer OpenVPN servers exist outside Russia. It is not a shortcut to an Uzbek server: the live sources checked today do **not** corroborate a working OpenVPN endpoint in Uzbekistan.

**Best current non-Russian smoke-test candidate:** Armenia, endpoint 45.146.241.113:995/TCP. Hunt VPN reported a successful OpenVPN connection test 13 minutes before retrieval, 100% quick and full checks over 24 hours, 100% over seven days, and a quality score of 98/100. This is a volunteer-run endpoint; the directory explicitly says it cannot vouch for the operator. The quality score measures availability/latency, not trustworthiness.

**Alternative near Uzbekistan:** Azerbaijan has two currently answering OpenVPN endpoints, one TCP and one UDP; its directory reported about 49% average probe reliability over seven days. Georgia has one TCP endpoint with 54% seven-day reliability. These are less stable than the Armenian candidate in this snapshot.

No endpoint was connected to by FreeRoute, no configuration was downloaded/imported, and no personal traffic or credentials were sent through any volunteer server.

## Uzbekistan OpenVPN availability

| Source | Current result | Decision |
|---|---|---|
| [Hunt VPN — Uzbekistan](https://huntvpn.dev/vpn/uzbekistan) | 0 alive of 1 tracked; the live page says it probes every five minutes | No active endpoint |
| [PublicVPNList country index](https://publicvpnlist.com/countries/) | 47 countries with live OpenVPN endpoints; Uzbekistan is absent | No current Uzbek OpenVPN listing |
| [VPN Gate official CSV API](https://www.vpngate.net/api/iphone/) | The API includes country codes and Base64 OpenVPN configuration data; no Uzbekistan record appears in the current snapshot | No current official VPN Gate Uzbek relay |
| [ProxyFreeOnly — Uzbekistan](https://proxyfreeonly.com/ru/free-vpn-list/uzbekistan) | One row is shown (84.54.72.10), but the row says it was updated four days ago, credentials are masked, and no protocol or OpenVPN profile is exposed | Unverified |
| [FreeVPNNode — Uzbekistan](https://www.freevpnnode.com/free-vpn-for-uzbekistan/) | Dozens of IP/host rows are shown, but the header says SSR/V2Ray/Clash while the rows have no protocol field or downloadable OpenVPN profile; some timestamps are stale | Do not treat as an OpenVPN feed |

One FreeVPNNode row, 213.230.86.11, maps in a separate IP-intelligence lookup to Uzbektelekom in Tashkent. The same vendor's security data labels it a residential proxy and not a known VPN. This classification is only a warning signal; it does not prove what software is running on that IP. A country geolocation record alone does not prove the existence of a working VPN server.

**Uzbekistan decision: NO-GO for an Uzbek OpenVPN transport test until a current OpenVPN profile is available and the server passes an independent connection check.** Do not infer protocol from an IP address or from an opengw.net hostname.

## Working non-Russian OpenVPN candidates

Hunt VPN's country directory currently lists 41 countries with at least one OpenVPN server answering. It runs handshake checks every five minutes and full connection checks every fifteen minutes, but it does not operate the endpoints and cannot vouch for their owners.

| Country | Live result at retrieval | Endpoint details | Reliability notes |
|---|---|---|---|
| Armenia | 2/2 alive | 45.146.241.113:995/TCP and a second TCP/995 endpoint | Best row: score 98/100; 100% checks over 24h and 7d; median latency 243 ms |
| Azerbaijan | 2/3 alive | 89.219.190.192:1856/TCP; 37.114.179.55:1691/UDP | About 49% average seven-day probe reliability; volunteer fleet |
| Georgia | 1/1 alive | 188.129.231.14:1849/TCP | 68% checks over 24h and 54% over 7d; site labels it unstable |

The latency values come from the directory's own fixed probe location and are not a promise of latency from the user's network. A successful OpenVPN handshake proves a server responds, not that its operator is trustworthy or that its own internet uplink works reliably.

For a controlled non-sensitive proof of concept, Armenia is currently the best availability candidate. Azerbaijan is a useful protocol comparison because both TCP and UDP are represented. Neither should be used for banking, account recovery, passwords, private files, or other sensitive activity.

## Can FreeRoute embed OpenVPN?

Yes, but this is a separate engine integration — an OpenVPN profile importer alone is not enough.

### OpenVPN 3 Core

The upstream [OpenVPN 3 project](https://github.com/OpenVPN/openvpn3) is a C++ client library, protocol-compatible with OpenVPN 2.x. It is used as the core of official OpenVPN Connect clients on Android, iOS, Windows, macOS and Linux. It is **client-only**; it does not create VPN servers.

The core exposes an OpenVPN client API and a TunBuilderBase abstraction intended to connect the engine to an operating-system VPN/TUN interface. The upstream licensing page describes dual licensing under **AGPLv3 or MPL 2.0**. Before including or modifying it, FreeRoute needs an explicit project licensing decision and the correct third-party notices/source-compliance path.

The FreeRoute repository currently has no LICENSE, LICENSE.md or COPYING file. Do not vendor OpenVPN source or copy a wrapper into the project until that licensing decision is made.

### Platform integration scope

| Platform | Required native integration | Main work |
|---|---|---|
| Android 13 / POCO | Android VpnService plus OpenVPN 3 Core through JNI/native libraries | Build ABI libraries, implement a TUN packet bridge, profile parsing, credential prompts, reconnect/status handling and secure storage |
| iPhone | Existing NEPacketTunnelProvider plus an OpenVPN 3 Core adapter | Add a separate OpenVPN packet-flow bridge, profile/keychain handling and extension events; real installation still requires Apple signing and Network Extension entitlement |
| Windows x64 | Native OpenVPN core plus a TUN adapter/driver and privileged service lifecycle | Bundle and validate the engine/driver, manage elevation, process/service lifecycle, DNS/routes, logs and disconnect cleanup |

The current FreeRoute clients are WireGuard-only: Android uses the WireGuard backend, Windows launches the WireGuard engine, and iOS uses WireGuardKit inside its Packet Tunnel extension. A second OpenVPN engine must therefore be implemented and tested separately on each platform; it cannot reuse WireGuard's config parser or engine.

### Existing wrappers reviewed

- [OpenVPN 3 Core](https://github.com/OpenVPN/openvpn3): active upstream C++ client core; best foundation if FreeRoute accepts one of its licenses.
- [OpenVPNAdapter (older iOS wrapper)](https://github.com/ss-abramchuk/openvpnadapter): archived in March 2022; do not base a new integration on an unmaintained wrapper without reviewing and maintaining its fork.
- [Windscribe iOSOpenVPNAdapter](https://github.com/Windscribe/iOSOpenVPNAdapter): a more recent iOS-specific adapter over OpenVPN 3 Core, but its published components include AGPLv3 and it does not solve Android/Windows integration.
- [ics-openvpn](https://github.com/schwabe/ics-openvpn): Android client under GPLv2; its maintainer explicitly says it is an application, not a library intended for embedding, and requires source publication for derivative apps. Avoid treating it as a drop-in SDK.

## Safe profile handling requirements

Public OpenVPN files are untrusted input. Before a profile can be imported or launched, FreeRoute must:

1. Parse and validate remote host/port/protocol, certificate and authentication options.
2. Reject script/plugin directives such as up, down, plugin, route-up, ipchange, and other arbitrary command execution.
3. Reject or carefully handle external config/include references and remote file paths; prefer self-contained profiles.
4. Never log credentials, private keys, inline certificates or full profile contents.
5. Store usernames/passwords and imported profile data in platform-protected storage.
6. Verify the actual public exit country and test DNS, IPv6, route leaks, reconnect and kill-switch behavior before calling the tunnel connected.

A public volunteer VPN is suitable only for a disposable, non-sensitive transport smoke test. It is not a dependable replacement for a FreeRoute-controlled server.

## Next implementation gate

Do not modify the current WireGuard transport. A separate OpenVPN branch should begin only after:

- a specific current OpenVPN profile has been retrieved from a source that publishes it;
- the profile has passed static safety inspection (no scripts, plugins, or unexplained remote includes);
- the selected volunteer endpoint is still reported as live;
- FreeRoute's project license and the OpenVPN core license path have been decided.

**Preferred sequence:** first a minimal Android proof of concept on the POCO using the Armenian TCP/995 candidate and non-sensitive traffic; then Windows; then iPhone. Keep OpenVPN marked experimental until all three builds pass and real-device leak/route tests are complete.

## Sources

- Hunt VPN live country index and country detail pages: https://huntvpn.dev/countries ; https://huntvpn.dev/vpn/uzbekistan ; https://huntvpn.dev/vpn/armenia ; https://huntvpn.dev/vpn/azerbaijan ; https://huntvpn.dev/vpn/georgia
- PublicVPNList country index: https://publicvpnlist.com/countries/
- VPN Gate official live page and CSV API: https://www.vpngate.net/en/ ; https://www.vpngate.net/api/iphone/
- FreeVPNNode and ProxyFreeOnly Uzbekistan pages: https://www.freevpnnode.com/free-vpn-for-uzbekistan/ ; https://proxyfreeonly.com/ru/free-vpn-list/uzbekistan
- IP-intelligence cross-check (one sample address): https://ipgeolocation.io/browse/ip/213.230.86.11
- OpenVPN 3 Core, its API and license: https://github.com/OpenVPN/openvpn3 ; https://openvpn.github.io/openvpn3/ ; https://openvpn.github.io/openvpn3/md_LICENSE.html
- Existing wrappers: https://github.com/ss-abramchuk/openvpnadapter ; https://github.com/Windscribe/iOSOpenVPNAdapter ; https://github.com/schwabe/ics-openvpn

**Status:** research only. No OpenVPN library, public endpoint, profile, credentials or client configuration has been added or used.
