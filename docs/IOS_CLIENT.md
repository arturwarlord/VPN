# FreeRoute iOS client

The iOS client lives under `ios/` and consists of a SwiftUI host app plus a Network Extension Packet Tunnel provider. The user-facing interface, local profile list, importer and connection flow are developed in this repository.

## Current implementation

- Imports WireGuard-style `.conf` files using the iOS document picker.
- Keeps copies of imported profiles in the app's local Documents/Profiles directory.
- Allows selecting a local profile and requesting VPN connect/disconnect.
- Runs the embedded WireGuardKit engine through the Packet Tunnel extension.
- Shows a warning if the profile lacks the IPv6 default route `::/0`.
- Includes third-party license notices.

## Build validation

The GitHub Actions workflow **Build FreeRoute iOS app** uses macOS/Xcode to generate the Xcode project and compile an unsigned app plus Packet Tunnel extension. The unsigned artifact, when the workflow succeeds, is for inspection only.

An unsigned app cannot be installed as a functional VPN app on a personal iPhone. Installation and use require:
- An Apple development team and valid signing setup.
- The Network Extension capability/Packet Tunnel entitlement enabled for the app's App ID and provisioning profile.
- The extension bundled with the app and correctly signed.
- On-device testing of profile import, approval prompts, reconnect behavior and network routes.

## Current limitations

- There is not yet a verified live VPN endpoint, so a successful app build cannot prove that traffic exits in the selected country.
- Profile filenames are labels, not validated geolocation metadata.
- IPv6 routing and DNS leak prevention must be tested end-to-end; a displayed route is not proof that the server forwards that protocol.
- The build workflow patches a temporary CI checkout of the upstream WireGuardKit package for current Swift tooling and SDK compatibility. It does not modify the upstream repository.
- Signing identities and provisioning credentials are not stored in this public repository. Do not commit certificates, private keys, profile files or device-specific provisioning material.

The embedded tunnel engine is WireGuardKit, licensed under MIT. See `ios/Resources/THIRD_PARTY_NOTICES.txt`.
