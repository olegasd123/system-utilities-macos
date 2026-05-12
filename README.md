# System Utilities for macOS

Native macOS menu bar app for system metrics and safe disk cleanup.

The app runs without a Dock icon. It shows compact live metrics in the menu bar
and opens a SwiftUI popover for the dashboard, Clean Drive, and preferences.

## Requirements

- macOS 14 or newer.
- Swift 6 toolchain.
- Xcode command line tools.
- Apple Developer credentials for signed and notarized releases.

## Features

### System Monitor

- Live CPU, memory, disk, network, battery, temperature, and fan metrics.
- One-second metric refresh.
- Single-line and two-line menu bar layouts.
- Menu bar options for CPU load, CPU temperature, memory use, free disk space,
  battery status, and network speed.
- Network display modes for the greater value, upload and download, upload
  only, download only, or combined traffic.
- Network units in bytes per second or bits per second.
- Daily network totals with a reset button.
- Temperature display in Celsius or Fahrenheit.
- JSON settings stored in Application Support.
- Warning notifications for CPU, memory, disk, battery, and temperature.
- Launch at login through `SMAppService`.
- Apple Silicon temperatures through `IOHIDEventSystemClient`.
- Intel temperatures and fan RPM through AppleSMC.

### Clean Drive

- Reclaimable-space scan in a second popover tab.
- Safe cleanup by default: files move to Trash.
- Optional permanent delete mode with confirmation.
- Preview sheet for files found in each category.
- User caches, logs, Trash, custom folders, Homebrew cache, browser caches,
  Mail downloads, old downloads, old software updates, and Xcode data.
- Xcode cleanup for derived data, old archives, device support, unavailable
  simulators, and simulator caches.
- Full Disk Access callout for protected categories.
- Cleanup reminders when reclaimable space is above the configured threshold.
- Per-category settings, reminder settings, and age thresholds for downloads
  and Xcode archives.

## Run

```bash
swift run SystemMonitor
```

Click the menu bar item to open the popover. Use the tab icons to switch
between System Monitor and Clean Drive. Right-click the menu bar item to open
the app menu.

Notification delivery and launch at login need a packaged `.app` bundle. They
are disabled when the app runs as a raw SwiftPM executable.

## Test

Run the test suite:

```bash
swift test
```

## Build An App Bundle

Build a local `.app` bundle:

```bash
scripts/build_app.sh
```

This creates an ad-hoc signed app at `dist/System Monitor.app`. Use this build
for local checks only.

Build a debug bundle:

```bash
CONFIGURATION=debug scripts/build_app.sh
```

Use another app icon:

```bash
APP_ICON_PATH="/path/to/AppIcon.icns" scripts/build_app.sh
```

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

Use `DMG_PATH` to notarize a DMG at a custom path:

```bash
DMG_PATH="/path/to/System Monitor.dmg" NOTARY_PROFILE="profile-name" scripts/notarize_dmg.sh
```

## Settings

Settings are stored as JSON in:

```text
~/Library/Application Support/dev.oleg-verhoglyad.SystemMonitor/settings.json
```

The current settings format uses `version`, `general`, and `features` keys.
The app can still read older flat settings files.

## Release Checks

- Build with a real Developer ID certificate.
- Create and notarize the DMG.
- Install the app on a clean Mac.
- Check that the app starts without a Dock icon.
- Check status item left-click and right-click behavior.
- Check the two-tab popover with System Monitor and Clean Drive.
- Run a Clean Drive scan and compare key category sizes with `du -sh`.
- Check Clean Drive preview sheets for non-empty categories.
- Check move-to-Trash cleanup with a safe test file or fixture.
- Check permanent delete confirmation, but do not use it on real data.
- Check the Full Disk Access callout for protected categories.
- Check Clean Drive reminder delivery from a packaged app.
- Check preferences persistence after restart.
- Check warning notifications from a packaged app.
- Check launch at login from a signed app.
- Check Apple Silicon sensors on Apple Silicon hardware.
- Check SMC sensors and fans on Intel hardware.

## Project Files

- `Package.swift`: SwiftPM package definition.
- `Sources/App`: App entry point, status item, popover, and app composition.
- `Sources/AppCore`: Shared settings, launch at login, and notification
  runtime helpers.
- `Sources/AppUI`: Shared SwiftUI and AppKit UI components.
- `Sources/CleanDriveCore`: Cleanup categories, scanning, reclaim, settings,
  and reminders.
- `Sources/CleanDriveUI`: Clean Drive popover and settings UI.
- `Sources/SystemMonitorCore`: Metric collection, settings, sampling, and
  warning logic.
- `Sources/SystemMonitorUI`: System Monitor dashboard, settings UI, and menu
  bar formatting.
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
- Apple Silicon and Intel Macs expose different sensor names and values.
- The app uses the main data volume or root volume for the disk card and disk
  warnings.
- Some Clean Drive categories need Full Disk Access to show complete results.
- Clean Drive does not scan cloud-sync roots or system-protected paths.
- Release signing and notarization need Apple Developer credentials.
