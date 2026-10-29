# FreeRoute Windows client

The Windows project under `windows/` is our own WinForms interface. It supports local WireGuard profile import, selection, connection and disconnection. The official WireGuard Windows engine is bundled into the build package and used as a tunnel service engine; the user does not need to install a separate consumer VPN application.

## Build

GitHub Actions workflow **Build FreeRoute Windows package** builds a self-contained Windows x64 package, verifies the official engine MSI signature, extracts the required engine files, and uploads a ZIP artifact named `freeroute-windows-x64`.

The executable requests administrator permissions because Windows VPN network adapters and services require elevation. Imported configuration files are stored in the current Windows user's LocalAppData folder. Never commit .conf profiles or private keys to this public repository.

## Status and limits

- Profile names are labels only; the actual exit country is determined by the configured remote endpoint.
- When a WireGuard tunnel is running, the client can manually query `ipwho.is` to display the current public IP and its estimated country. The query is opt-in and the result is not saved.
- A warning is shown if the profile lacks an IPv6 default route. This is not a guarantee that IPv6 is leak-free; the server-side route still requires testing.
- No live country list or server inventory is available until a reachable remote server has been provisioned.
- Windows package compilation does not itself prove a VPN connection works end-to-end. An actual server profile and an endpoint reachability test are still required.
- The country check sends the current public IP to the geolocation service. If the tunnel fails during the request, it may observe the normal connection IP; the result is only an estimate.

See [third-party notices](../windows/THIRD_PARTY_NOTICES.txt) for engine attribution and licensing.
