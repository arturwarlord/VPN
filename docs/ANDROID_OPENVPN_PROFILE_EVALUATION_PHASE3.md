# FreeRoute OpenVPN profile evaluation — phase 3

## Added

The native `FreeRouteOpenVpnClient` now exposes a profile-evaluation entry point to Kotlin:

- Accepts profile text from the Android side.
- Enforces the pinned OpenVPN Core maximum profile size before parsing.
- Creates `ClientAPI::Config` and evaluates it using the same `OpenVPNClient` instance that owns the Android callbacks.
- Returns only a success/failure result to Kotlin; parser diagnostics and profile contents are not written to logcat.
- Releases JNI string resources on every completed evaluation path.
- Serializes evaluation against close in the Kotlin owner.

## Security and scope

- The profile is passed in memory and is not written by this API.
- This phase does not request or store username/password credentials.
- It does not call `provide_creds()` or `connect()`.
- It does not create a TUN device or start a foreground service.
- External file references are not merged by this entry point; profiles that depend on external files may be rejected and need a future explicit import/merge flow.
- A successful evaluation means only that OpenVPN Core accepted the profile syntax/configuration. It does not prove server reachability, authentication, country of egress, or a functioning VPN tunnel.

WireGuard remains unchanged and remains the working VPN path.
