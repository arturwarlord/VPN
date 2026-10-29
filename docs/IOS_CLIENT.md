# FreeRoute iOS client

The iOS client lives under `ios/` and consists of a SwiftUI host app plus a Network Extension Packet Tunnel provider. The user-facing interface, local profile list, importer and connection flow are developed in this repository.

## Current implementation

- Imports WireGuard-style `.conf` files using the iOS document picker.
- Keeps imported profile files in the app's local Documents/Profiles directory, with file protection and exclusion from ordinary device backups.
- Stores the active tunnel configuration, including its private key, in the shared Keychain group; VPN preferences hold only a persistent Keychain reference rather than the config text.
- Uses the same App Group in the host app and Packet Tunnel extension so the extension can retrieve the config.
- Allows selecting a local profile and requesting VPN connect/disconnect.
- Runs the embedded WireGuardKit engine through the Packet Tunnel extension.
- Shows a warning if the profile lacks the IPv6 default route `::/0`.
- Offers a manual exit-country check while the app reports the VPN as connected. It displays the public IP and estimated country returned by `ipwho.is` and does not save the result.
- Includes third-party license notices.

## Build validation

The GitHub Actions workflow **Build FreeRoute iOS app** uses macOS/Xcode to generate the Xcode project and compile an unsigned app plus Packet Tunnel extension. The unsigned artifact, when the workflow succeeds, is for inspection only.

An unsigned app cannot be installed as a functional VPN app on a personal iPhone. Installation and use require:
- An Apple development team and valid signing setup.
- The Network Extension capability/Packet Tunnel entitlement enabled for the app's App ID and provisioning profile.
- The App Group `group.com.arturwarlord.freeroute` enabled for both the host app and extension IDs and included in their provisioning profiles.
- The extension bundled with the app and correctly signed.
- On-device testing of profile import, approval prompts, reconnect behavior and network routes.

## Current limitations

- Keychain/App Group access needs real-device validation after signing. An unsigned CI build cannot prove that the iOS entitlement permits the shared-Keychain read/write.
- There is not yet a verified live VPN endpoint, so a successful app build cannot prove that traffic exits in the selected country.
- Profile filenames are labels, not validated geolocation metadata. The manual exit-country check uses an IP-geolocation API and is not absolute proof of location.
- IPv6 routing and DNS leak prevention must be tested end-to-end; a displayed route is not proof that the server forwards that protocol.
- The country-check request sends the current public IP to the geolocation service. If the tunnel drops during the request, it may see the normal connection IP.
- The build workflow patches a temporary CI checkout of the upstream WireGuardKit package for current Swift tooling and SDK compatibility. It does not modify the upstream repository.
- Signing identities and provisioning credentials are not stored in this public repository. Do not commit certificates, private keys, profile files or device-specific provisioning material.
- Imported `.conf` files still exist locally in the app's protected sandbox; the app excludes the Profiles directory from ordinary backup, but users should delete profiles when they no longer need them.

The embedded tunnel engine is WireGuardKit, licensed under MIT. See `ios/Resources/THIRD_PARTY_NOTICES.txt`.
