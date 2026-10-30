# Public Uzbekistan proxy and VPN list assessment

**Checked:** 30 October 2026  
**Project constraints:** €0/month, Uzbekistan or another country outside Russia, our own FreeRoute apps, no untrusted third-party software installation, and no payment/card.

## Executive decision

These websites are useful as **discovery feeds**, not as a production VPN backend.

- **No listed HTTP/HTTPS/SOCKS proxy is a WireGuard endpoint.** It cannot be imported into the current WireGuard client as a `.conf` profile.
- Public HTTP/HTTPS/SOCKS proxies may relay individual application connections. Routing all traffic from Android, Windows or iOS through them would require a separate proxy/tun2socks transport path and leak/DNS/UDP handling. SOCKS5 defines an optional UDP ASSOCIATE operation, but a specific public server must actually implement it. HTTP CONNECT is a TCP tunnel, not a general-purpose WireGuard or UDP tunnel.
- **ProxyFreeOnly is the only supplied link that currently shows a separate free VPN endpoint in its Uzbekistan list.** The page showed one endpoint, with the row last updated four days earlier; its username/password were hidden and the page did not state the protocol. Its own terms say it is an informational list, not the operator of third-party VPN endpoints, and it does not guarantee that an endpoint is accurate, available or secure.
- **ProxyHub is the most useful supplied proxy-list snapshot for further controlled testing:** it showed 14 Uzbekistan entries with a common check time of 30 October 2026 15:35 UTC. The visible list includes HTTP, HTTPS and SOCKS4; some rows are explicitly marked transparent. It is not a trusted, stable VPN service.
- No public endpoint was connected to, no traffic was sent through it, and no profile or credentials were imported during this review.

**Deployment decision: do not add any of these public relays to FreeRoute's production server list.** Keep the UNICON trial as the primary route for a server we control, pending written confirmation of free-trial billing and private WireGuard permission.

## Site-by-site findings

| Source | What the page showed on 30 Oct 2026 | Assessment |
|---|---|---|
| [Geonix Uzbekistan](https://free.geonix.com/ru/uzbekistan/) | A dynamic page whose visible rows in the retrieved snapshot were labelled Russia, Indonesia, China and Thailand, despite the Uzbekistan page title. Its summary counts varied between crawls and did not establish a reliable UZ-only feed. | **Not verified.** Do not ingest its rows as Uzbekistan endpoints without independently checking country and protocol. |
| [SPYS.one UZ](https://spys.one/proxys/UZ/) | Around 79 entries. The visible recent records are mostly HTTP/HTTPS; reported uptime for several recent entries was roughly 12–41%. The visible SOCKS5 row had a last-check date of 10 June 2026, so it is stale for this assessment. | **Poor reliability.** A large count is not a count of currently working, stable endpoints. |
| [Proxy5 Uzbekistan](https://proxy5.net/ru/free-proxy/uzbekistan) | The page says its list is checked every 30 minutes, but it showed **0 proxies online** at retrieval. | **No current candidate** in this snapshot. |
| [Free-Proxy.cz UZ](http://free-proxy.cz/ru/proxylist/country/UZ/all/ping/all) | The page could not be retrieved by the research browser because the request timed out. | **Unverified**, not evidence that the service itself is offline. |
| [Best-Proxies UZ](https://best-proxies.ru/proxylist/free/uz/) | The page could not be retrieved by the research browser because the request timed out. | **Unverified**, not evidence that the service itself is offline. |
| [ProxyHub UZ](https://proxyhub.me/ru/uz-free-proxy-list.html) | 14 rows were shown, checked at 15:35 UTC on 30 October. The listed types included HTTP, HTTPS and SOCKS4. Some rows were marked transparent. | **Useful discovery feed only.** Not a server we control; do not use for accounts, payments or sensitive traffic. |
| [ProxyFreeOnly UZ VPN list](https://proxyfreeonly.com/ru/free-vpn-list/uzbekistan) | The page showed 1 online VPN entry: hostname `vpn584074918.opengw.net`, public address `84.54.72.10`; credentials were masked and the entry's own “updated” value was four days. The page offered JSON/TXT/CSV output and said its list refreshes every three minutes. | **Interesting but unverified third-party VPN.** The page does not identify the protocol for this row or prove the endpoint operator's identity/permission. Do not trust it with private traffic. |

### Cross-check of the VPN listing

A separate directory, [VPNHub's Uzbekistan VPN list](https://vpnhub.me/ru/uz-free-vpn.html), showed dozens of purported endpoints and labels the supported families as SSL, L2TP/IPsec, SSTP and OpenVPN. Its configuration download flow asks the visitor to share the page before unlocking a configuration. It does **not** list WireGuard. This is not independent proof that every listed server works or that the endpoint on ProxyFreeOnly is the same service operator.

## Why a proxy list is not a FreeRoute WireGuard server

The current FreeRoute clients embed the WireGuard engine and expect a WireGuard peer configuration. A public HTTP proxy, HTTPS CONNECT proxy, SOCKS4/5 relay or OpenVPN endpoint uses a different protocol and cannot be converted into a WireGuard peer just by copying its IP address and port.

- HTTP CONNECT establishes a tunnel to a specific destination through an HTTP proxy. The standard describes this as a tunnel to the requested origin; it is not a general UDP-capable device tunnel. See [RFC 9110, section 9.3.6](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.6).
- SOCKS5 has a defined UDP ASSOCIATE command, but support is optional in real deployments and must be tested for each server. See [RFC 1928](https://www.rfc-editor.org/rfc/rfc1928).
- OpenVPN, L2TP/IPsec and SSTP are separate VPN protocols. An `.ovpn` configuration cannot be imported by the current WireGuard engine.

A whole-device proxy mode would be a separate feature: a local TUN/VPN interface, a tun2socks or equivalent transport, DNS policy, UDP behavior, IPv6 leak protection, reconnection handling and a clear per-device proxy profile. That is not implemented in this repository today. It should not be silently substituted for the current WireGuard design.

## Security and privacy gate

ProxyFreeOnly's own terms say it publishes informational lists and does not operate the referenced third-party proxy/VPN servers unless explicitly stated. They also disclaim guarantees for endpoint availability, accuracy, security and privacy. Its privacy policy says the directory itself collects technical data such as IP address, browser/device details, visited pages and approximate location. The endpoint operator is a separate party whose practices the directory says it does not control.

For any public relay, the operator can observe the connecting IP, destination metadata and timing/volume. Plain HTTP content can be read or altered by the relay. Properly validated HTTPS/TLS protects the content from an ordinary forward proxy, but it does not make an unknown relay trustworthy or hide all destination metadata. Never send credentials, banking sessions, account recovery flows or private files through an unknown free proxy/VPN.

A page's “anonymous” label or successful ping does not verify the operator's consent, privacy practices, country of the actual exit IP, DNS path, or absence of traffic manipulation.

## Safe next step

1. Keep these pages as **discovery sources only**; do not auto-import their endpoints into the release app.
2. If we later decide to prototype a non-WireGuard mode, first add a separately labelled experimental transport and a strict allowlist/profile consent flow. Do not change the production WireGuard path.
3. Test only non-sensitive traffic, verify the actual public exit country independently, and check DNS/IPv6 leaks. Stop immediately if the relay's operator or terms cannot be established.
4. Continue pursuing a free VPS where we control the OS, firewall, WireGuard keys and endpoint, starting with UNICON's advertised 30-day trial after written confirmation.

## Sources reviewed

- Geonix: https://free.geonix.com/ru/uzbekistan/
- SPYS.one: https://spys.one/proxys/UZ/
- Proxy5: https://proxy5.net/ru/free-proxy/uzbekistan
- Free-Proxy.cz: http://free-proxy.cz/ru/proxylist/country/UZ/all/ping/all
- Best-Proxies: https://best-proxies.ru/proxylist/free/uz/
- ProxyHub: https://proxyhub.me/ru/uz-free-proxy-list.html
- ProxyFreeOnly list, About, Terms and Privacy: https://proxyfreeonly.com/ru/free-vpn-list/uzbekistan ; https://proxyfreeonly.com/ru/about ; https://proxyfreeonly.com/terms ; https://proxyfreeonly.com/privacy-policy
- VPNHub cross-check: https://vpnhub.me/ru/uz-free-vpn.html
- Protocol standards: https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.6 ; https://www.rfc-editor.org/rfc/rfc1928

**Status:** research only. No public proxy/VPN endpoint was contacted or used. No credentials, payment method, provider account, server or client configuration was created.
