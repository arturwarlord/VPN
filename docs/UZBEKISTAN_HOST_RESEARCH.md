# Uzbekistan VPS and cloud-provider research

**Last checked:** 30 October 2026  
**Project constraints:** 0 EUR spend, remote WireGuard exit outside Russia (Uzbekistan is acceptable), public/reachable UDP, full IPv4 internet egress, private authenticated use for our own devices, and no automatic paid conversion.

## Executive decision

The Uzbekistan market offers more realistic trial routes than the international free-VPS list, but none is approved for deployment yet.

**Best free-trial lead: UNICON Cloud.** Its VPS catalogue explicitly lists private VPN/proxy networking as a use case, includes a public IPv4 and flexible cloud firewall/routing, and a separate promotion page advertises 30 days of free use without obligations. Before creating an account, support must confirm that the promotion applies to a VPS with public IPv4, does not require a card or paid top-up, has no automatic charge after the trial, and permits a private authenticated WireGuard tunnel.

**Best documented WireGuard + promo-credit lead: ServerPlus.** The provider's own FAQ explicitly mentions WireGuard as a VPS use case. New users are advertised 100,000 UZS of promo balance after identity confirmation. A minimal VPS configuration appears to consume roughly 5,333 UZS/day from the published resource prices (about 18 days of credit), but this is an estimate, not a guaranteed free period. Confirm the credit expiry, included resources, identity-verification requirements, and private-use policy before signup. A promo balance is finite credit, not permanent free hosting.

**Do not use UzCloud for this project without a written policy exception.** Although it offers a 7-day VPS trial without a card and its product page markets VPN/networking, its public offer expressly prohibits using the service as a proxy or VPN server or installing proxy/VPN-related software.

No account has been created, no identity documents have been submitted, no VPS has been created, and no payment method or paid service has been enabled.

## Shortlist

| Provider | Location / published network | Free offer | VPN policy / key risk | Current decision |
|---|---|---|---|---|
| UNICON Cloud | Tashkent; public IPv4; flexible cloud firewall/routing; private VPN networking appears in the product catalogue | Separate promotion advertises 30 days free | AUP bans open anonymous proxies, not clearly private authenticated WireGuard; promotion details need confirmation | **First trial to verify** |
| ServerPlus | Tashkent; public IP; root VPS; cloud security groups support UDP ingress | 100,000 UZS promo balance after identity confirmation | FAQ expressly mentions WireGuard; public offer also restricts web proxies and illegal traffic transfer, so confirm private device-only use | **Best WireGuard-documented credit offer** |
| UzCloud / Uztelecom | Uzbekistan Tier III sites; KVM; root; public IPv4 available as an add-on | 7 days free without a card | Public offer clause 3.1.13 prohibits VPN/proxy server use and related software | **Exclude unless written exception** |
| MyCloud | Tashkent; root VPS; public IP; daily billing | Live VPS page says launch day is not billed; an indexed FAQ copy says there is no free trial for new customers | Balance top-up and automatic daily billing at 00:00; exact zero-cost eligibility is unclear | **Not a safe €0 option** |
| ACDN | Tashkent; KVM; public IPv4; unmetered traffic claim | No free credit/trial found | Paid plan only; WireGuard permission not clearly published | **Paid fallback only** |
| Dicloud | Tashkent; root VPS; public IP | No free trial found | VPN / remote access listed as a use case; monthly price is substantially higher | **Paid fallback only** |
| UZSCINET / Medanta | Tashkent; dedicated IP and routing | No verified free trial | Entry plan is very small; current site labels its service as test mode | **Not suitable for the first build** |
| Airnet.uz | Tashkent; public IP; VPS test access discussed | Pages conflict: “trial by arrangement” versus FAQ saying no free VPS test | No clear WireGuard/UDP permission | **Do not assume a free trial** |
| HOSTIN.UZ | Uzbekistan VPS | 72-hour money-back guarantee | Requires a paid order first; refund is not a zero-cost trial | **Exclude under strict budget** |

## Provider notes

### 1. UNICON Cloud — first option to ask about

Official VPS catalogue: https://cloud.unicon.uz/vps  
Promotion page: https://pro.unicon.uz/  
Cloud portal: https://mycloud.unicon.uz/  
Official VPS regulation: https://api2.unicon.uz/media/serviceadditionalinfo/vps-uz-ru.pdf

The product page lists Ubuntu/Debian and other OS images, one external IPv4 address, flexible firewall and routing, and private network/VPN/proxy scenarios. It advertises 10 Mbps Internet and up to 100 Mbps TAS-IX/UZ-IX, subject to the product's traffic rules. The entry VPS-1 is shown at 153,000 UZS/month (1 vCPU, 2 GB RAM, 40 GB NVMe, one public IPv4).

A separate UNICON promotion page advertises 30 days of free access to VPS/VPC, colocation and bare-metal services “without obligations”. It is not yet clear whether:
- the offer is still active and available to new individual customers;
- the 30 days apply to a complete VPS with public IPv4, rather than only a demo or limited platform access;
- a bank card, payment balance or identity verification is required;
- the VPS is stopped automatically at the end, or whether a paid subscription/auto-charge is activated;
- private authenticated WireGuard for the owner's devices is allowed under the current agreement.

The official VPS regulation prohibits **open anonymous proxy servers that do not require authorization**. That wording is narrower than a blanket ban on all VPNs and appears consistent with a private authenticated tunnel, but support should explicitly confirm WireGuard before deployment. Do not create an open proxy or public VPN service.

**Decision:** contact sales/support first. Only use the trial if the provider confirms in writing: 30 free days for VPS, no card/top-up/auto-charge, public IPv4, outbound IPv4 Internet, inbound UDP allowed, and private device-only WireGuard allowed.

### 2. ServerPlus — best documented WireGuard scenario

Official VPS product: https://serverplus.uz/en/products/cloud-vds-vps-servers  
Cloud control panel: https://cloud.serverplus.uz/  
Registration: https://auth.serverplus.uz/  
Official public offer: https://serverplus.uz/en/company/publick-offer

The VPS is physically located in Tashkent. The provider documents full root/admin access, public IP, cloud firewall/security groups, and 100 Mbps Internet/TAS-IX/UZ-IX connectivity. The FAQ explicitly says a VPS can be used for a VPN and names WireGuard. The security-group documentation supports UDP ingress; inbound traffic is denied by default, so a specific UDP rule must be added for the chosen port.

The advertised new-user offer is 100,000 UZS of promo balance after identity confirmation. Published Universal Lite resource pricing works out to approximately:
- 1 vCPU: 1,500 UZS/day;
- 2 GB RAM: 1,000 UZS/day;
- 40 GB standard SSD: 2,000 UZS/day;
- one public IP: 833 UZS/day.

That totals about 5,333 UZS/day, or around 18.7 days for 100,000 UZS if those components can be ordered separately at the listed rates. The packaged monthly Universal Lite price is advertised at 160,000 UZS/month. Actual charging, taxes, promo restrictions, billing granularity and credit expiry may differ; ask support for a written quote before using any credit.

The public offer has restrictions on web proxies and illegal international traffic transfer. The product FAQ's explicit WireGuard example is encouraging, but we should ask for written confirmation that a **private, authenticated tunnel limited to the user's own devices** is permitted. Do not offer a public VPN/proxy or resell the service.

**Billing/contract check (official public offer reviewed 30 October 2026):** The offer is addressed to individuals. It describes services as prepaid: charges are deducted from the customer's account balance, not explicitly billed as post-paid usage. When the balance reaches zero, access is automatically suspended; VM data is retained for no more than 30 days, after which the contract can terminate and VM/configuration data is permanently deleted. The reviewed offer does not describe an automatic card charge or post-paid debt at zero balance. This does **not** prove that the advertised 100,000 UZS promotional credit can be activated without a card/top-up, or that no separate bonus rules apply. Confirm those points before registration or activating any service. Never add a card or personal funds under the €0 constraint.

Identity confirmation is required to receive the promotional balance. The public offer and account process involve personal identity information. Never send passport, PINFL, SMS codes, passwords or account tokens to ChatGPT or this repository; enter documents only on the provider's verified official portal after deciding to proceed.

**Decision:** strongest backup if UNICON's 30-day offer fails. Treat the 100,000 UZS as temporary promo credit, not ongoing free hosting.

### 3. UzCloud / Uztelecom — 7-day no-card trial, but policy conflict

Official VPS page: https://uzcloud.uz/en/solutions/vps-vds  
Public offer: https://uzcloud.uz/en/oferta

UzCloud advertises a 7-day VPS trial without a payment card, KVM virtualization, root access and Tier III infrastructure in Uzbekistan. Public IPv4 is an additional option. This initially looks attractive.

However, clause 3.1.13 of its public offer explicitly prohibits using the hosting service as a proxy or VPN server and installing proxy/VPN-related software. The product marketing page's generic mention of VPN/networking does not override the contract.

**Decision:** do not create a FreeRoute VPS there unless UzCloud provides a written exception or updates the applicable offer. Do not rely on the free trial to bypass the restriction.

### 4. MyCloud — one free day, then daily charges

Official VPS page: https://mycloud.uz/vps-servers  
Account guide: https://mycloud.uz/

The live VPS page lists a Start configuration at 4,000 UZS/day (1 vCPU, 1 GB RAM, 20 GB SSD, one IP) with Ubuntu/Debian, root access and Internet/TAS-IX/UZ-IX. Its current FAQ says the launch day is not billed and the first charge occurs at the nearest 00:00. The same page says the customer tops up a balance, charges are taken daily at 00:00, and a server automatically renews while funds remain. An indexed FAQ copy for the same URL says there is no free test for new customers, so the public descriptions are not fully consistent. Even taking the launch-day statement at face value, it is not a safe €0 offer unless MyCloud confirms that provisioning requires no paid balance/top-up and that the account cannot incur any charge. The page also says service is suspended at zero balance and VM data is deleted after 7 days.

The provider's terms do not give us sufficient certainty about a private WireGuard endpoint and the exact public UDP path. Do not create a VM or add funds under our strict €0 constraint. A one-day non-billed launch window is not the same as a zero-cost VPS trial.

**Decision:** not the first option under the strict €0 rule.

### 5. Paid-only or weaker alternatives

- **ACDN:** Tashkent KVM VPS, public IPv4, 100 Mbps external and higher local TAS-IX connectivity; published promotional entry pricing starts at $4.80/month for the first three months and rises to $6/month. No free credit identified. https://acdn.uz/
- **Dicloud:** Tashkent VPS with full admin access, daily backups and VPN/remote access among the listed scenarios; a Start configuration is advertised at about 286,000 UZS/month. No free trial identified. https://dicloud.uz/
- **UZSCINET / Medanta:** VDS entry pricing from about 54,000 UZS/month, but the listed smallest configuration is very limited (around 750 MHz CPU, 384 MB RAM and 10 GB disk), and the current site is in test mode. https://uzscinet.uz/
- **Airnet.uz:** advertises trial access by arrangement, but its FAQ says there is no free VPS test. Confirm directly rather than assume a free offer. https://airnet.uz/
- **HOSTIN.UZ:** a 72-hour money-back period requires paying for the order first. This is not a €0 trial. https://hostin.uz/
- **SkyCloud.uz:** its VPS FAQ explicitly says free VPS testing is not available; it offers only paid minimum-period or hourly configurations. No zero-cost route found. https://skycloud.uz/cloud/vps-vds/
- **SurkhanDC.uz:** the provider markets VPS with root access, but its own page says servers are in Germany and only says account registration is free. Free registration is not free compute; no free VPS trial or credit was identified. https://surkhandc.uz/ru
- **Uztelecom “Test service”:** the page lists monthly CPU/RAM prices rather than a free allocation, and does not establish a free VPN-eligible VPS trial. Treat the word “test” in the product title as no proof of free hosting. https://uztelecom.uz/ru/chastnym-licam/oblachnye-servisy/testovyy-servis/

## Questions to send providers before account creation

Ask UNICON and ServerPlus to answer all of these in writing:
1. Is a private WireGuard VPN for the customer's own phone and computers allowed (not a public proxy and not resold)?
2. Is inbound UDP available on a public IPv4 address, and can we choose/listen on UDP 51820 or another fixed UDP port?
3. Is outbound IPv4 Internet available for full-tunnel client traffic?
4. Is the trial/bonus valid for a Linux VPS with root access, and does it require a payment card or wallet top-up?
5. What exactly happens when the trial/bonus reaches zero? Confirm that there is no debt, card charge or automatic paid conversion. For ServerPlus, specifically confirm that its public-offer zero-balance suspension rule also applies to promotional credit.
6. What is the exact credit/trial expiry and the minimum configuration cost?

## Technical acceptance test before deployment

Once a provider grants a zero-cost trial or credit and confirms the policy:
1. Create only the smallest eligible Ubuntu/Debian KVM VPS in Uzbekistan, with no card/paid upgrade unless strictly unnecessary and explicitly authorized.
2. Record the public endpoint and SSH port; independently verify the SSH host-key fingerprint in the provider console.
3. Add the four repository secrets only after host identity is verified: `VPN_HOST`, `VPN_USER`, `VPN_SSH_KEY`, `VPN_KNOWN_HOSTS`.
4. Run **Actions → Preflight WireGuard host** with the provider's SSH port. This is read-only and checks root/sudo, TUN, CAP_NET_ADMIN, WireGuard kernel visibility, firewall access, IPv4 forwarding and IPv4 egress.
5. Separately verify provider firewall inbound UDP, country of the endpoint, and client-network IPv6 reachability. Do not run server deployment unless all checks pass.
6. Deploy the FreeRoute installer only after a clean preflight, explicit provider permission and a confirmed zero-cost allowance. Then test a WireGuard handshake, public exit IP, DNS and IPv6 leak behavior from the POCO.

A provider's local data-centre location does not prove that an IP-geolocation database will classify the endpoint as Uzbekistan. Check the actual endpoint IP from a connected device. The current FreeRoute server only provides IPv4 Internet egress and intentionally blocks inner IPv6 forwarding, so IPv6-only websites remain unavailable while connected.

## Sources and evidence

Provider pages and contract sources reviewed:
- UNICON VPS catalogue and 30-day promotion: https://cloud.unicon.uz/vps and https://pro.unicon.uz/
- UNICON VPS regulation (open anonymous proxy restriction): https://api2.unicon.uz/media/serviceadditionalinfo/vps-uz-ru.pdf
- ServerPlus VPS, WireGuard FAQ, network/firewall docs and new-user promo: https://serverplus.uz/en/products/cloud-vds-vps-servers
- ServerPlus public offer: https://serverplus.uz/en/company/publick-offer
- UzCloud VPS and public offer: https://uzcloud.uz/en/solutions/vps-vds and https://uzcloud.uz/en/oferta
- MyCloud VPS and billing details: https://mycloud.uz/vps-servers
- ACDN, Dicloud, UZSCINET, Airnet and HOSTIN: https://acdn.uz/ ; https://dicloud.uz/ ; https://uzscinet.uz/ ; https://airnet.uz/ ; https://hostin.uz/
- SkyCloud VPS / free-trial FAQ: https://skycloud.uz/cloud/vps-vds/
- SurkhanDC VPS location and offer: https://surkhandc.uz/ru
- Uztelecom test-service tariffs: https://uztelecom.uz/ru/chastnym-licam/oblachnye-servisy/testovyy-servis/

**Status:** research only. No provider account, VPS, payment, remote SSH connection or deployment has been created.
