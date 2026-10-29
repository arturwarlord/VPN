# Free VPN exit-server research

**Last checked:** 30 October 2026  
**Hard requirement:** EUR 0/month, server outside Russia, WireGuard/root networking support, public reachability and no automatic conversion to a paid plan. A candidate is not approved just because its homepage says "free."

## Decision summary

No candidate below is currently approved as a dependable long-term exit server for personal traffic. The server scripts and clients may continue to be developed without provisioning any host. Do not enter payment details, enable a paid plan, or create billable resources as part of this project unless the user explicitly changes the €0 constraint. TheUltraHost is the closest newly found conditional lab candidate, but it requires student verification, periodic manual keep-alive, and an IPv6 endpoint path that FreeRoute does not yet implement; it is not approved for deployment.

## Candidates reviewed

## Zero-cost fallback: an existing home computer (not yet configured)

An already-owned computer in a location outside Russia can serve as a WireGuard exit node without paying a VPS provider, provided that the machine remains powered on, has enough existing internet bandwidth, and the ISP/router permit inbound UDP forwarding. The Windows WireGuard engine supports persistent tunnel services, and Windows has built-in NAT features; however, routing and firewall behavior must be configured and tested on the specific host.

This is **not yet implemented as an automated FreeRoute server mode**, and the current location of the user's home network and whether it has public inbound reachability are unknown. A router port-forward does not work through carrier-grade NAT unless the ISP provides a public address or another tunnel is used. The exit country is the home ISP's location, not a selectable foreign data-center country. Exposing a residential computer also adds security risk and may violate ISP terms.

Do not change router/firewall settings blindly. This is a possible next route only after a read-only check confirms: location outside Russia; always-on host; public IPv4 or usable IPv6; inbound UDP reachability; no conflicting Windows NAT/Hyper-V setup; and ISP permission.

References:
- WireGuard for Windows tunnel service: https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md
- Microsoft NAT overview: https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/setup-nat-network

### Oracle Cloud Always Free — excluded by user

Oracle was already attempted and did not work in this setup. Do not retry or suggest it as the next step.

Official documentation describes free compute offers, but the user's signup/setup path was unsuccessful. That practical blocker is sufficient to exclude it from the current plan.

Official reference: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

### Google Cloud Free Tier — technically possible, too little traffic

Google's official Free Tier includes one non-preemptible e2-micro VM in one of three US regions, 30 GB-months of standard persistent disk, and only 1 GB of qualifying outbound transfer per month. The VM can remain within the always-free offer only if the project stays within all applicable limits; additional egress or other resources can cost money when on a paid billing account.

The 1 GB/month outbound allowance is unsuitable as a regular full-tunnel VPN for multiple personal devices. Do not use the $300/90-day trial credits as a substitute for a permanent free host.

Official reference: https://docs.cloud.google.com/free/docs/free-cloud-features

### AWS Free Plan — expires

AWS documents a Free Plan with up to $200 in credits and a plan period of up to six months, ending sooner if credits are exhausted. AWS says the account and resources are suspended/closed when that free plan expires unless the account is upgraded. That does not satisfy a permanent €0/month server requirement.

Official references:
- https://aws.amazon.com/free/
- https://aws.amazon.com/free/free-tier-faqs/

### vyce.cloud VPS-Mini — interesting, but not an approved endpoint yet

The provider currently advertises a $0 VPS-Mini with 1 CPU, 2 GB RAM, 6 GB storage, root SSH access, a public IPv6 address, and 20 ports (one reserved for SSH). Free capacity is limited, and the account needs a GitHub account at least 30 days old. The dashboard requires renewal; a stopped instance is deleted after three days if not renewed.

The important gap is network compatibility: the published summary does not clearly confirm that an inbound UDP port can be reached over IPv4, while the current FreeRoute deployment workflow accepts only a public IPv4 endpoint. An IPv6-only server would require a separate, audited IPv6-endpoint deployment path and testing from all target networks. Do not provision or send traffic to it yet; first establish the exact UDP port-forwarding behavior, acceptable-use terms for a private personal WireGuard server, and reliable no-cost renewal.

Official reference: https://vyce.cloud/

### AlaVPS Free VPS — rejected as a permanent zero-cost host

The current official site advertises root SSH, KVM, a dedicated IPv4 and IPv6, but also states the free instance is a promotional trial, typically **1–3 months**, and asks for a credit card for verification. It is not a long-term guaranteed free exit server under the project's rules, so do not create it for FreeRoute.

Official reference: https://alavps.com/ (FAQ and pricing sections)

### TheUltraHost student VPS — conditional lab candidate, not a permanent endpoint

The official free plan advertises a KVM VPS with root access, 1 shared vCPU, 1 GB RAM, 15 GB NVMe, 250 GB/month, an IPv6 /64 and 20 NAT IPv4 forwarded ports. The provider explicitly describes a personal VPN over IPv6 as a possible use, but says public proxies are not allowed. Eligibility requires current student verification, and the server must be manually kept alive once every 30 days; otherwise it pauses after a further grace period.

This is the most relevant newly found candidate for a **short controlled prototype** if the account qualifies: a WireGuard endpoint might be reachable over native IPv6, and the forwarded IPv4 ports may be useful for client networks. However:
- The current FreeRoute deploy workflow accepts only global IPv4 endpoints; it does not support an IPv6 endpoint yet.
- The exact forwarded-port protocol options and IPv4 egress behavior still need verification before relying on it.
- The 30-day manual keep-alive means it is not a fully unattended always-on endpoint.
- Student eligibility is not assumed. Do not create an account or send profile/private-key material until eligibility, allowed personal VPN use, and actual UDP reachability are confirmed.

Official references:
- Plan and requirements: https://theultrahost.com/free-vps
- Student verification: https://theultrahost.com/students

### VPSWala Starter — not suitable without further verification

The provider's current homepage advertises an always-free ARM64 VPS with root SSH, 2 GB RAM, 10 GB/month bandwidth and only 500 MB NVMe storage. Another VPSWala page describes different resources and a 30-day free trial, so the exact plan and IP/network terms are not consistent across current public descriptions. The pages do not establish a reliable, externally reachable UDP endpoint with sufficient disk/traffic for a regular full-tunnel VPN.

Do not use it for a personal exit server unless the provider confirms the exact zero-cost plan, public address and inbound UDP path in writing. A short-lived trial is not a substitute for a permanent €0 host.

Official references:
- Current homepage: https://vpswala.org/
- Plan details: https://vpswala.org/free-vps.html

### EUserv VS2-free — possible lab, not a dependable exit node

The official plan describes a Linux container, 1 vCPU at 1 GHz, 1 GB RAM, 10 GB HDD, one IPv6 address and no included IPv4. The contract term is one month with manual renewal; the provider's forum support confirmed that renewal cannot be automated and the server goes down if it is missed. That conflicts with unattended availability. Container networking and WireGuard/iptables behavior would also need a disposable compatibility test before it could even be considered for temporary use.

Official references:
- Plan: https://www.euserv.com/en/virtual-private-server/root-vserver/v2/vs2-free.php
- Renewal support answer: https://forum.euserv.com/index.php?topic=10932.0

### Zendevz — rejected for this project

The official site says the service is Bangladesh-only and in open beta/early alpha, and explicitly advises against business-critical production workloads. Its public-subdomain/HTTPS routing is not proof that a raw inbound WireGuard UDP endpoint can be mapped. Do not route personal traffic through a provider that is not production-ready and has not confirmed UDP behavior.

Official reference: https://www.zendevz.com/

### GAP Cloud free MicroVM — short-lived test environment only

The official free MicroVM page offers a one-hour build window and a 24-hour claim window, after which the trial VM/disk is removed if it is not claimed. Its documentation also says outbound access is limited to approved package registries and arbitrary internet access is blocked. This makes it unsuitable as an internet exit server.

Official references:
- https://gap.geta.team/free-vm
- https://gap.geta.team/docs

### GratisVPS.net — rejected for sensitive VPN traffic

The site advertises free KVM VPS resources, but its own Terms of Service call the service an "As-Is Beta", say the provider may suspend or terminate any aspect at any time without notice, and disclaim service/security/uptime warranties. Its free plan also advertises a shared IPv4 and a dedicated IPv6 rather than a dedicated IPv4.

Independent feedback is strongly negative: the Trustpilot page currently shows 1.9/5 from 17 reviews, with most shown reviews being one star. Reviews are not proof of fraud, but combined with the provider's terms they are enough reason not to route personal VPN traffic through it.

Do not register, install the server there, or send it private keys as part of this project.

References:
- Provider home: https://gratisvps.net/
- Provider Terms: https://gratisvps.net/terms.html
- Trustpilot reviews: https://www.trustpilot.com/review/gratisvps.net

### FreeVPS.org — eligibility and usage restrictions

The community offer advertises a free NAT KVM VPS and a 250 GB/month standard allocation, with forwarded NAT IPv4 ports and a dedicated IPv6 subnet. However, applicants must have a forum account at least three months old, 50 substantive posts and 25 received thanks. Its policy explicitly says there is no SLA, instances may be reclaimed, and public VPNs are prohibited. Whether the private personal VPN use case is acceptable is not conclusively established by the short rule, so this is not an approved host.

It is not a practical immediate option unless eligibility is already met and the provider confirms personal private WireGuard use is permitted.

References:
- Allocation and policy: https://www.freevps.org/
- Sponsor directory: https://www.freevps.org/sponsors.html

### switched.cloud — can run briefly for testing, not an unattended server

The provider offers root access, five forwarded TCP/UDP ports on a shared IPv4, and one directly reachable IPv6 address. However, the account starts with only three days of Runtime. Each VPS consumes an hour of Runtime per hour it exists, and a Cloud Token adds one day (two days with Plus). Runtime is obtained through completed link/referral actions; when Runtime runs out, instances stop and are deleted if not topped up within three days. There are no backups, and allocations can change.

That does not satisfy a permanently online service without manual renewal or a sustained allowance of tokens, and the no-backup policy is undesirable for a VPN configuration. Do not use it for ongoing personal traffic. It could only be considered for a disposable short-lived build/port-forwarding experiment, after separately confirming the fair-use rules permit a private WireGuard endpoint.

Official reference: https://switched.cloud/

### Openworld — not approved for unattended service

The current official FAQ confirms NAT IPv4 plus a dedicated public IPv6 address, but free VPS periods last seven days and must be renewed once every 24 hours to reset their countdown. Its current terms prohibit operating open proxies or VPNs for malicious purposes; they do not clearly say that a private personal VPN is categorically banned. Even so, renewal requirements conflict with the project's fully unattended objective, and the endpoint's IPv6-/NAT-based networking still needs a verified UDP reachability test.

Official references: https://openworld.eu.org/faq and https://openworld.eu.org/tos



The free plan includes NAT IPv4 and a dedicated public IPv6 address, but instances must be renewed every seven days and automatically suspend when the renewal is missed. That conflicts with fully automated always-on operation. https://openworld.eu.org/faq

### vpsFree.cz — not free

The community/nonprofit VPS requires membership dues of 300 CZK per month (36 EUR for three months); the published plan is not a permanent zero-cost service. It offers good VPS capabilities and public IPv4 but violates the budget requirement. Official references: https://vpsfree.cz/ and https://kb.vpsfree.cz/informace/platby

### Route64 — tunnel service, not a compute host

Route64 offers a free IPv6 tunnelbroker that can route an IPv6 subnet through its network, but it does not provide the Linux VM or dedicated WireGuard exit server this project needs. Its static-IP tunnels are described as supporter's services. A home/VPS endpoint is still needed, and an IPv6-only tunnel does not carry IPv4 full-tunnel traffic. Reference: https://www.route64.org/en

### OpenClaw Cloud free computer — trial period only

OpenClaw Cloud advertises a public IP and SSH access, but its own page states the free compute period is seven days; after that the VM is powered off unless additional free time is received or a paid plan is selected. It is not a permanent always-on endpoint. Reference: https://open.claw.cloud/

## Acceptance checklist for any future host

Before deploying, verify all of the following using provider documentation or an actual disposable test:
1. Explicitly permitted private personal VPN / WireGuard use.
2. Stable public endpoint outside Russia, reachable from Windows, Android and iPhone networks.
3. Root privileges and working WireGuard kernel/tunnel support.
4. Inbound UDP forwarding (or a dedicated public IP) and the ability to retain the port after a restart.
5. Sufficient monthly outbound traffic for actual use.
6. Clearly bounded costs: no expiring credits, paid-only conversion, unbounded billing, or unrequested upgrades.
7. A provider identity and reputation credible enough for traffic that will pass through the server.

Until a candidate passes the checklist, keep the service marked **not live**, don't create a server, and don't claim that country switching works.
