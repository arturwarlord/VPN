# Android OpenVPN profile import — phase 7

## Added

- A separate Android document-picker action for OpenVPN `.ovpn` profiles. The existing WireGuard `.conf` import path remains separate.
- Imported profiles are stored under the app-private `filesDir/openvpn-profiles` directory.
- The importer requires the `.ovpn` extension, rejects empty/binary/non-UTF-8 input, and enforces a 256 KiB application-level size limit while streaming the selected file.
- Duplicate display names receive a numeric suffix; file contents are never included in logs or UI messages.
- The UI reports only the number of locally stored OpenVPN profiles.

## Explicit limitations

This phase does **not**:
- evaluate the profile with OpenVPN 3 Core;
- import or resolve external referenced files;
- request or store credentials;
- start the native OpenVPN worker;
- establish a TUN interface, change routes, or connect to a server.

The status message explicitly says that syntax and connectivity have not yet been checked. The existing WireGuard profile list, parser, and connection controls remain unchanged.

## Next phase

Connect the selected private profile file to a short-lived native profile-evaluation operation, returning only a success/failure result. Keep credential collection and actual connection disabled until service ownership, native callbacks, TUN lifecycle, and an authorized test endpoint are ready.
