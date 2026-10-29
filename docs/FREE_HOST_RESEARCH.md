# Free VPN exit-server research

**Last checked:** 29 October 2026  
**Hard requirement:** EUR 0/month, server outside Russia, WireGuard/root networking support, public reachability and no automatic conversion to a paid plan. A candidate is not approved just because its homepage says "free."

## Decision summary

No candidate below is currently approved as a dependable long-term exit server for personal traffic. The server scripts and clients may continue to be developed without provisioning any host. Do not enter payment details, enable a paid plan, or create billable resources as part of this project unless the user explicitly changes the €0 constraint.

## Candidates reviewed

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

### switched.cloud and Openworld — not approved

- switched.cloud advertises a shared IPv4 with a limited number of forwarded TCP/UDP ports and a dedicated IPv6 address. A VM consumes twice the base allocation, and reliable access for IPv4-only client networks has not been established. This needs further verification before use: https://switched.cloud/
- Openworld's free tier must be renewed every seven days and is automatically suspended if not renewed. That conflicts with a fully automatic, always-on service requirement: https://openworld.eu.org/faq

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
