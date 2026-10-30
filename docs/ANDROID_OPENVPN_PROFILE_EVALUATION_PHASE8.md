# OpenVPN profile evaluation — phase 8

## User flow

1. Import a text `.ovpn` file through the dedicated OpenVPN picker.
2. The app stores it in its private `filesDir/openvpn-profiles` directory with a 256 KiB cap.
3. The user is asked whether to evaluate the profile now.
4. After Android VPN consent and foreground-service startup, the service reads the file from its private directory and passes its text to OpenVPN 3 Core `eval_config`.
5. The service updates its persistent notification with a generic accepted/rejected result.

## Security and lifecycle boundaries

- The service accepts only a canonical file whose direct parent is the app-private OpenVPN profile directory.
- The reader enforces the same 256 KiB limit and strict UTF-8 decoding.
- Profile contents and parser-provided details are not logged or shown.
- The native session is closed after evaluation.
- Evaluation runs on a background thread; no native `connect()` call is made.
- No username/password is requested or persisted.
- No TUN is established, no routes or DNS are changed, and no server/network reachability is tested.
- The notification explicitly distinguishes local parser acceptance from a verified server connection.

## Known limitations

This is a syntax/configuration evaluation step, not a guarantee that a profile can connect. Profiles that depend on external files, unsupported options, external PKI, or encrypted private-key handling may be rejected or require future support. The app does not resolve arbitrary external file paths.

## Next phase

Before enabling a real connection, implement and test native event/state callbacks, credential prompting and secure handoff, robust TUN file-descriptor ownership/teardown, service cancellation, and an authorized test server/profile. Only then add an explicit connect control and verify traffic, IPv4/IPv6, DNS, and exit-country behavior.
