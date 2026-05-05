# System Monitor for macOS

Native macOS migration of the System Monitor app.

## Status

- Native SwiftPM app skeleton is in place.
- The app runs as an AppKit menu bar utility with a SwiftUI popover.
- Preferences are backed by a Codable settings model and JSON store.
- CPU, memory, disk, network, and battery metrics are sampled once per second.
- Daily network totals are persisted and can be reset from the dashboard.
- Detailed sensors, fan RPM, notifications, and launch at login are not ported
  yet.

## Run

```bash
swift run SystemMonitor
```

The app runs as a menu bar utility with no Dock icon. Click the menu bar item
to open the popover. Right-click it to open the app menu.

## Source

The migration plan is in [MIGRATION_PLAN.md](MIGRATION_PLAN.md).
