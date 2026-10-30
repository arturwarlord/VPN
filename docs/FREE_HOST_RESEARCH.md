# Free VPN exit-server research

**Last checked:** 30 October 2026  
**Hard requirement:** EUR 0/month, server outside Russia, WireGuard/root networking support, public reachability and no automatic conversion to a paid plan. A candidate is not approved just because its homepage says "free."

## Decision summary

No candidate below is approved as a dependable, unattended production exit server. switched.cloud has no free VPS/container capacity when the user attempted to provision it, so it is on hold. There are now two conditional leads:
- **FOSSVPS (Frankfurt)** has the strongest published resources and no advertised daily keep-alive, but it is gated by strict LowEndTalk/LowEndSpirit reputation rules, our repository currently has no open-source license file, and inbound UDP/WireGuard permission still needs confirmation.
- **Openworld** is the more accessible next technical prototype: root SSH, systemd containers, NAT IPv4 and public IPv6 are documented, but private personal WireGuard permission, UDP reachability and TUN/CAP_NET_ADMIN must be confirmed. It requires manual renewal once every 24 hours.
TheUltraHost is another conditional option only for verified students; although the provider page explicitly mentions personal VPN over IPv6, the site's free-tier terms remain a non-binding draft and the site itself still says "Demo build". Do not pay, add a card, enable a paid tier or deploy without the relevant checks. NeoHeberg is excluded because its free VPS has no outbound IPv4 NAT.

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

### vyce.cloud VPS-Mini — availability and suitability not confirmed

The official page advertises a free VPS-Mini with 1 CPU, 2 GB RAM, 6 GB storage, root SSH, public IPv6 and 20 ports (one reserved for SSH). It says free slots are limited and servers must be renewed from the dashboard; a stopped instance is deleted after three days. A third-party community listing marked the promotion expired on 27 October 2026 after reports that its queue was not moving. This is not an authoritative provider notice, but do not assume a free slot is obtainable without live confirmation.

The page does not clearly document inbound UDP semantics, IPv4 egress/NAT or whether WireGuard is allowed. Do not rely on this candidate until a free VPS can actually be claimed and its network tested.

Official reference: https://vyce.cloud/
Community availability report: https://bansos.dev/list/vyce-free-vps/

### AlaVPS Free VPS — rejected as a permanent zero-cost host

The current official site advertises root SSH, KVM, a dedicated IPv4 and IPv6, but also states the free instance is a promotional trial, typically **1–3 months**, and asks for a credit card for verification. It is not a long-term guaranteed free exit server under the project's rules, so do not create it for FreeRoute.

Official reference: https://alavps.com/ (FAQ and pricing sections)

### TheUltraHost student VPS — promising network design, but eligibility and legal terms block approval

At the latest check (30 October 2026), the provider page advertised **37 free slots remaining**. The plan is a KVM virtual machine with root access, 1 shared vCPU, 1 GB RAM, 15 GB NVMe and 250 GB/month. It provides an IPv6 /64 plus 20 forwarded NAT IPv4 ports. The provider explicitly lists “a personal VPN over IPv6” as a suitable use, while public proxies are prohibited. It requires student verification and one manual Keep alive click every 30 days; if missed, the VPS pauses after a 7-day reminder window and is deleted after another 14 days paused.

The official free-tier terms page is explicitly labelled **“Draft for legal review · not yet binding”** (effective 1 October 2026), and the provider site still labels itself **“Demo build”** with placeholder prices. Its current marketing claims should not be treated as final binding service terms.

Technical gates:
- FreeRoute supports public IPv6 as the outer WireGuard endpoint, but the VPS must also prove outbound IPv4 egress/NAT for IPv4 internet destinations. The 20 forwarded IPv4 ports are useful for inbound reachability only if UDP forwarding is supported for the selected port.
- The POCO's actual Wi-Fi/mobile networks must be able to reach IPv6.
- Run the read-only FreeRoute preflight after provisioning; although KVM is more compatible than LXC, verify the actual WireGuard service, firewall, IPv4 route and egress.
- Confirm the free plan's binding terms and acceptable-use policy before trusting the statement that personal VPN use is allowed.

Do not create an account unless the user can honestly verify current student status. Do not upload student ID to this project or to ChatGPT. Do not add a payment card or select a paid upgrade.

Official references:
- Plan and requirements: https://theultrahost.com/free-vps
- Student verification: https://theultrahost.com/students
- Free-tier terms (currently marked as a draft): https://theultrahost.com/legal/free-tier-terms

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

### switched.cloud — no capacity available when the user tried to provision

The provider's current Terms of Service (effective 21 October 2026) confirm that switched.cloud runs Linux LXC containers and KVM virtual machines, with the first host on a Scaleway (Dedibox) server in France. It provides root access, one public IPv6 address and five TCP/UDP ports forwarded from a shared public IPv4 address. Crucially, its VPS-specific fair-use rules explicitly state: **“Personal proxies, VPNs, and tunnels are allowed”**, provided they are not used for prohibited activity.

**Current availability blocker:** the user reached the provider panel but could not create a VPS because no containers were available. Do not ask the user to keep retrying the same full panel or treat advertised plan limits as free capacity. Revisit only after the provider announces capacity again.

The free operation model is the main limitation:
- A new account receives three days of Runtime.
- A VPS consumes one hour of Runtime per hour that exists, even when shut down.
- Cloud Tokens are earned through Linkvertise links; one token adds one day of Runtime, or two days with switched.cloud Plus.
- When Runtime runs out, the VPS stops. Renew it within three days or it is deleted.
- There are no VPS backups, resources/placement can change, outbound bandwidth is capped, and the provider gives no uptime guarantee.

Network-wise this is materially better documented than most free-host leads: UDP is explicitly listed for the forwarded ports, and the public IPv6 address is reachable directly on every port. The shared IPv4 port mapping is potentially useful for IPv4-only client networks; the direct IPv6 endpoint is another option. The first advertised host location is France, outside Russia. The exact host address, exit IP country and inbound UDP path still need live verification.

**Current blocker before deployment:** the free plan supplies LXC containers as well as KVM VMs. Our existing installer expects a normal Ubuntu/Debian host with systemd, WireGuard kernel/tunnel support, iptables/ip6tables, forwarding control and permission to manage host networking. The public documentation does not confirm that an LXC container has /dev/net/tun, CAP_NET_ADMIN, working firewall/NAT operations or the permissions required by wg-quick. A container that merely grants root inside its namespace may still fail these checks. Test those capabilities in a disposable instance first; do not run the production installer until they pass. A KVM VM is more compatible but requires switched.cloud Plus and sufficient earned Cloud Tokens; do not buy tokens or resources with money.

**Decision:** keep switched.cloud on hold until the provider releases capacity. It remains a possible short prototype only; do not purchase Runtime, Plus or resources. It is not a dependable permanently free endpoint and must not be presented as production-ready. Never automate Linkvertise completions or bypass its token system.

Official references:
- Network, Runtime, LXC/KVM and fair-use summary: https://switched.cloud/
- Current Terms of Service and explicit personal VPN permission (version 2026-10-21): https://noprofit.space/terms

### FOSSVPS — best published specs, but strict community and project eligibility

FOSSVPS is a community-donated VPS project for developers of their own free/open-source software. Its current website lists:
- 2 vCPU, 4 GiB RAM and 64 GiB disk;
- Debian, Ubuntu or Alpine;
- dual-stack NAT plus IPv6 (/128 or /96 depending on location);
- a Frankfurt, Germany node (de11) currently listed as donated by ST-Hosting until 1 February 2028.

The project's published rules say: free/open-source software developers only, white-hat use, non-commercial use, no SLA and no excessive CPU/disk/bandwidth consumption. It has direct node-to-VM port mappings for non-HTTP protocols (example: node port to the same VM port), but the public description does **not** explicitly confirm UDP forwarding or WireGuard. Get written confirmation from the administrator that a private WireGuard test tunnel on the Frankfurt node is acceptable and that the port mapping supports inbound UDP before applying or deploying.

**Strict eligibility gate from the administrator's 27 May 2026 update:** applicants must be their own open-source software developers (merely using open-source software does not qualify), be active members of LowEndTalk (LET) or LowEndSpirit (LES), have a good non-spammy reputation, quality posts and thanks, and have held the forum membership for at least three months. New/empty forum accounts are explicitly not accepted. Registration via a VPN is blocked; disposable email addresses are blocked; registration from Russia, China and North Korea is blocked. Do not create duplicate accounts, fabricate forum activity, use a VPN to evade the registration block, or try to bypass eligibility.

**Additional FreeRoute blocker:** this repository is public but currently has no LICENSE or COPYING file. A public GitHub repository without an explicit license cannot safely be presented as an open-source-licensed project. The FOSSVPS form asks for a Git/web project URL, forum and username, location, OS and a project description. The project would need the user to choose and add an open-source license to the repo before claiming an open-source license. Do not select a legal license or submit personal name/email/forum details on the user's behalf.

If the user already meets the three-month LET/LES reputation requirement and is willing to choose an appropriate project license, this is worth asking the FOSSVPS administrator about. It is not yet an approved WireGuard host because the UDP/VPN-use policy is unconfirmed. The published Frankfurt node and resources are attractive, and the page does not list a daily/weekly renewal requirement, but there is no SLA and capacity is not guaranteed.

Official/provider references:
- FOSSVPS specifications and Frankfurt node: https://fossvps.org/
- Current eligibility and port-forwarding discussion (LowEndTalk): https://lowendtalk.com/discussion/217664/welcome-to-fossvps-and-goodbye-to-nodeseek
- Service and network details (LowEndTalk): https://lowendtalk.com/discussion/215848/fossvps-updates-free-server-for-open-source-developers-from-alexhost-hosteroid-and-st-hosting
- Application form: https://fossvps.org/dev/form1.html

### Openworld — next conditional candidate for a one-device prototype

The current official FAQ documents no-card free access, NAT IPv4, a dedicated public IPv6 address, root SSH access, and containers with full systemd access. Free VPS periods last seven days and can be renewed once every 24 hours; an unrenewed VPS is suspended. The main page reports three nodes and 145 VPS instances in total, but those aggregate counts do not prove that a free slot is available.

The terms prohibit open proxies or VPNs for malicious purposes; they do not explicitly ban a private VPN for the owner's own devices. Still, get written confirmation that a private, non-public WireGuard tunnel is permitted and that UDP listening on the dedicated IPv6 address is supported.

**Technical gate:** full systemd access does not prove that a container has /dev/net/tun, effective CAP_NET_ADMIN, WireGuard kernel support, iptables/ip6tables permissions or host-network forwarding. Run the read-only FreeRoute preflight before installation. FreeRoute would use public IPv6 for the outer WireGuard UDP endpoint and NAT IPv4 for ordinary IPv4 internet egress. The client networks must also have working IPv6. Check this on the POCO's actual Wi-Fi and mobile networks. Confirm UDP reachability and exit-IP geolocation before generating client profiles.

The daily renewal requirement is not unattended. Treat this only as a short, non-sensitive prototype unless a stable no-cost renewal process can be used with the provider's permission. Do not bypass provider controls or use paid upgrades.

Official references:
- FAQ: https://openworld.eu.org/faq
- Terms of Service (last updated 25 July 2026): https://openworld.eu.org/tos
- Main page and aggregate VPS counts: https://openworld.eu.org/



### vpsFree.cz — not free

The community/nonprofit VPS requires membership dues of 300 CZK per month (36 EUR for three months); the published plan is not a permanent zero-cost service. It offers good VPS capabilities and public IPv4 but violates the budget requirement. Official references: https://vpsfree.cz/ and https://kb.vpsfree.cz/informace/platby

### Route64 — tunnel service, not a compute host

Route64 offers a free IPv6 tunnelbroker that can route an IPv6 subnet through its network, but it does not provide the Linux VM or dedicated WireGuard exit server this project needs. Its static-IP tunnels are described as supporter's services. A home/VPS endpoint is still needed, and an IPv6-only tunnel does not carry IPv4 full-tunnel traffic. Reference: https://www.route64.org/en

### NeoHeberg VPS Free — excluded: no outbound IPv4 on the free plan

NeoHeberg advertises a €0/month VPS with no credit card, 512 MB RAM, 5 GB SSD, 25% of one vCPU, 250 GB/month, root access and public IPv6. Its services are hosted in Paris, France, and its help center says VPSs are deployed on Proxmox.

The current pricing page explicitly states that all VPS plans are IPv6-only and have no outbound IPv4 NAT. A dedicated IPv4 costs an additional €1.50/month, which violates the hard budget. Our current FreeRoute server design depends on IPv4 egress/NAT so clients can reach ordinary IPv4 internet destinations. The help-center article contains an older conflicting statement about IPv4 NAT; follow the newer explicit pricing/network specification and do not provision the free plan for this project.

The terms do not explicitly mention or permit private WireGuard use, and say services are subject to available resources and fair-use rules. Although the free plan has root access and one automatic backup, the lack of outbound IPv4 makes it unsuitable for the current full-tunnel target without a separate IPv4-translation design and another trustworthy NAT64/transit provider.

Official references:
- Current pricing and IPv6-only/no-outbound-IPv4 notice: https://neoheberg.fr/en/prices
- Account, France location and no-card details: https://neoheberg.fr/en/help/compte-facturation
- Terms (updated 9 October 2026): https://neoheberg.fr/en/conditions
- VPS creation via Proxmox: https://neoheberg.fr/help/vps/?article=creer-premier-vps-neoheberg&type=offre_vps

### OpenClaw Cloud free computer — trial period only

OpenClaw Cloud advertises a public IP and SSH access, but its own page states the free compute period is seven days; after that the VM is powered off unless additional free time is received or a paid plan is selected. It is not a permanent always-on endpoint. Reference: https://open.claw.cloud/

## Acceptance checklist for any future host

Before deploying, verify all of the following using provider documentation or an actual disposable test:
1. Explicitly permitted private personal VPN / WireGuard use.
2. Stable public endpoint outside Russia, reachable from Windows, Android and iPhone networks.
3. Root privileges and working WireGuard kernel/tunnel support; for LXC, explicitly verify /dev/net/tun, CAP_NET_ADMIN, systemd, forwarding and firewall permissions before attempting installation.
4. Inbound UDP forwarding (or a dedicated public IP) and the ability to retain the port after a restart.
5. Sufficient monthly outbound traffic for actual use.
6. Clearly bounded costs: no expiring credits, paid-only conversion, unbounded billing, or unrequested upgrades.
7. A provider identity and reputation credible enough for traffic that will pass through the server.
8. Understand the operator's access, automated abuse scanning, retention and backup policies; do not route sensitive traffic through an experimental host.

Until a candidate passes the checklist, keep the service marked **not live**, don't create a server, and don't claim that country switching works.
