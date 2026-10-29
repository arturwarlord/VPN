# FreeRoute Android client

FreeRoute is our app project. Users install the APK built from this repository, not a separate consumer VPN app.

## Current MVP

- Native Android UI.
- Imports and validates a WireGuard .conf profile through Android's file picker.
- Stores the imported profile in the app-private internal storage directory.
- Connects and disconnects using Android's VPN permission flow.
- Uses the embeddable WireGuard tunnel engine through its published library API; the UI and application flow are ours.
- Does not upload profiles or private keys to GitHub.

## Build

The GitHub Actions workflow named "Build FreeRoute Android APK" builds a debug APK on pushes that affect the Android app and on manual dispatch. Download the freeroute-android-debug artifact from the workflow run.

The debug APK is unsigned for distribution purposes and intended for installation/testing on a personal device. A release signing setup is not configured yet.

## What is not ready

- No working country list or server inventory yet. The country shown to websites is determined by the configured remote VPN endpoint, not by the client UI.
- A reachable server outside Russia is still required for country switching.
- Windows and iOS client apps are not implemented yet.
- Full-tunnel IPv6/DNS leak testing and kill-switch behavior must be tested before relying on this app.
- Android background operation on Xiaomi/POCO devices may require the user to allow background activity and disable battery restrictions. This must be tested on the POCO X4 Pro 5G.

## Security

- Imported configuration contains a client private key. Keep it private and never commit .conf profiles into this public repository.
- Profiles are stored only inside the app's internal sandbox. Removing the app removes its local data.
- This MVP does not contact any profile-management service and has no account or telemetry system.
