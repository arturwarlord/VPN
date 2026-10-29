# Client smoke test before a FreeRoute-owned server exists

This guide is for checking that our app can import a standard WireGuard profile and bring up a real tunnel **before FreeRoute has its own exit server**.

A third-party profile is only a temporary connectivity test. It does not mean FreeRoute owns the VPN endpoint, and the observed country is determined by the provider's server.

## Optional test profile through Proton VPN Free

Proton's official documentation describes creating a WireGuard configuration from the Proton account's Downloads → WireGuard configuration page. Its instructions say a Free-plan configuration only exposes the VPN Accelerator option, and the user can choose a server from the list or accept the recommended server.

Official guide: https://protonvpn.com/support/wireguard-configurations

1. Create/sign in to your own Proton VPN account in your browser. Do not give FreeRoute or ChatGPT your Proton login credentials.
2. In Proton's official configuration generator, select WireGuard and a server allowed by your plan. Keep the default compatible settings unless you know what you are changing.
3. Download the generated `.conf` directly to the device where you will test the client.
4. In FreeRoute, choose **Добавить профиль** and import that file.
5. Connect and verify the public IP from the same device. The location should correspond to the selected Proton endpoint; server load and the provider's free-plan limits still apply.
6. Disconnect, then remove the temporary profile from the device when the test is finished.

## Security rules for the test

- A WireGuard `.conf` file contains a client private key. Keep it local and private.
- Do not commit the downloaded file to this public GitHub repository, add it to a GitHub issue, attach it to a public release, or paste its contents into chat.
- Do not put it in GitHub Actions artifacts. The current project workflows are designed to build the app, not distribute user VPN credentials.
- A profile named “Netherlands” or “US” is just a label. Use an external IP/geolocation check after connecting to verify the actual exit location.
- If the profile is missing an IPv6 default route `::/0`, FreeRoute warns that IPv6 may bypass the tunnel. Do not treat that warning as leak protection; run separate DNS and IPv6 leak checks, and avoid relying on the test for sensitive traffic until the route is verified.
- Provider free plans can restrict server selection, feature options or connection behavior. This test does not promise unrestricted country switching.

## What this test proves — and what it does not

If the client connects and public IP changes, it validates the client import/tunnel path against that third-party provider. It does **not** validate the FreeRoute VPS installer, our future server's firewall/NAT, our future server's country, or whether we can operate at €0/month.

For the finished product, FreeRoute still needs its own approved, reachable, outside-Russia endpoint or an explicitly accepted alternative hosting arrangement.
