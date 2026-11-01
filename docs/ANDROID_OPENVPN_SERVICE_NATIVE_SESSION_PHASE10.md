# FreeRoute OpenVPN service-owned native session — phase 10

## Added

- Added an internal `ACTION_CONNECT_PROFILE` service action, guarded by the same Android VPN-consent and foreground-service checks as the existing service.
- The service reads only a canonical profile from app-private storage, evaluates it with OpenVPN 3 Core, and starts the existing native worker on its dedicated thread.
- The service retains one native session for the duration of the worker and serializes profile evaluation/start against stop and destruction.
- Stop, Android VPN revocation, and service destruction request native stop and close the session before releasing the JNI owner.
- The existing sanitized native event callback updates generic service notification states.

## Deliberate limits

- The action is internal to the non-exported Android service and is not exposed as a user-facing Connect button.
- This phase starts only profiles that do not require username/password. Profiles requiring credentials fail closed; no credentials are accepted through an Intent or persisted.
- External PKI, encrypted private-key passwords, unsupported TUN/DNS/proxy directives, and unsupported profile references remain unsupported.
- A native worker start or OpenVPN `CONNECTED` event is not proof that user traffic, DNS, IPv6, or exit-country routing works.
- No server endpoint or credentials are bundled. No server connection is claimed as tested.
- WireGuard source and its existing connection path are unchanged.

## Validation required

- GitHub Actions repository validation.
- ARM64 OpenVPN 3 native build and Android debug APK build.
- Later device test with a user-authorized, autologin `.ovpn` profile and explicit verification of public IPv4, IPv6, DNS, and leak behavior before any claim of a working VPN.
