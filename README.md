# System Monitor for macOS

Native macOS migration of the System Monitor app.

## Status

- Native SwiftPM app skeleton is in place.
- The app runs as an AppKit menu bar utility with a SwiftUI popover.
- Preferences are backed by a Codable settings model and JSON store.
- Menu bar metrics support single-line and two-line layouts.
- CPU, memory, disk, network, and battery metrics are sampled once per second.
- Daily network totals are persisted and can be reset from the dashboard.
- Detailed temperature sensors and fan RPM are implemented through
  `IOHIDEventSystemClient` and AppleSMC. Hardware validation is still needed.
- Warning notifications are implemented with threshold hysteresis and cooldown.
- Launch at login is wired through `SMAppService`. It needs a signed `.app`
  bundle, so the toggle is disabled when the app runs with `swift run`.

## Run

```bash
swift run SystemMonitor
```

The app runs as a menu bar utility with no Dock icon. Click the menu bar item
to open the popover. Right-click it to open the app menu.

Notification delivery is disabled when running as a raw SwiftPM executable.
It is enabled for packaged `.app` builds.

Launch at login also needs a packaged and signed `.app` build.

## Package

Build a local `.app` bundle:

```bash
scripts/build_app.sh
```

By default this creates an ad-hoc signed app at `dist/System Monitor.app`.
Use this build for local checks only.

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

## Limits

- Detailed sensors use private macOS APIs. This build is for direct
  distribution, not the Mac App Store.
- Apple Silicon and Intel sensor paths still need hardware checks.
- The final app icon is still a packaging task.

## Source

The migration plan is in [MIGRATION_PLAN.md](MIGRATION_PLAN.md).
