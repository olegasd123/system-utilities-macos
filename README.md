# System Monitor for macOS

Native macOS menu bar app for live system metrics.

The app runs without a Dock icon. It shows compact live metrics in the menu bar
and opens a SwiftUI popover for the full dashboard and preferences.

## Features

- CPU, memory, disk, network, battery, temperature, and fan metrics.
- Single-line and two-line menu bar layouts.
- Daily network totals with a reset button.
- JSON settings stored in Application Support.
- Warning notifications with thresholds, hysteresis, and cooldown.
- Launch at login through `SMAppService`.
- Apple Silicon temperatures through `IOHIDEventSystemClient`.
- Intel temperatures and fan RPM through AppleSMC.

## Run

```bash
swift run SystemMonitor
```

Click the menu bar item to open the dashboard. Right-click it to open the app
menu.

Notification delivery and launch at login need a packaged `.app` bundle. They
are disabled when the app runs as a raw SwiftPM executable.

## Package

Build a local `.app` bundle:

```bash
scripts/build_app.sh
```

This creates an ad-hoc signed app at `dist/System Monitor.app`. Use this build
for local checks only.

Build with a Developer ID certificate:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build_app.sh
```

Create a DMG after the app is built:

```bash
scripts/make_dmg.sh
```

Notarize and staple the DMG:

```bash
NOTARY_PROFILE="profile-name" scripts/notarize_dmg.sh
```

You can also use `APPLE_ID`, `TEAM_ID`, and `APP_SPECIFIC_PASSWORD` instead of
`NOTARY_PROFILE`.

## Release Checks

- Build with a real Developer ID certificate.
- Create and notarize the DMG.
- Install the app on a clean Mac.
- Check that the app starts without a Dock icon.
- Check status item left-click and right-click behavior.
- Check preferences persistence after restart.
- Check warning notifications from a packaged app.
- Check launch at login from a signed app.
- Check Apple Silicon sensors on Apple Silicon hardware.
- Check SMC sensors and fans on Intel hardware.

## Project Files

- `Package.swift`: SwiftPM package definition.
- `Sources/SystemMonitor`: AppKit shell, SwiftUI views, models, and services.
- `Sources/MacSensorBridge`: C bridge for private sensor APIs.
- `Packaging/Info.plist`: App bundle metadata.
- `Packaging/AppIcon.icns`: App icon.
- `scripts/build_app.sh`: Build and sign the `.app`.
- `scripts/make_dmg.sh`: Create the DMG.
- `scripts/notarize_dmg.sh`: Submit and staple notarization.

## Limits

- Detailed sensors use private macOS APIs. This app is for direct distribution,
  not the Mac App Store.
- Sensor availability depends on hardware and macOS changes.
- Release signing and notarization need Apple Developer credentials.
