# Native macOS Migration Plan

This plan moves the existing System Monitor from Tauri, React, and Rust to a
macOS-only app built with native Apple tools. The UI and app behavior should
stay close to the current app. The new app can use private sensor APIs for
detailed temperatures and fan RPM, so it is for direct macOS distribution, not
for the Mac App Store.

Source project:

- [Project README](/Users/oleg/Dev/Common/system-utilities/README.md)
- [React app entry](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/App.tsx)
- [Dashboard UI](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/components/Dashboard.tsx)
- [Settings UI](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/components/SettingsView.tsx)
- [TypeScript models](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/lib/types.ts)
- [Tauri app setup](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/lib.rs)
- [Tray and popover logic](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/tray.rs)
- [Metrics loop](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/metrics.rs)
- [Settings store](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/settings.rs)
- [Warnings](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/warnings.rs)
- [Metrics collector](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/lib.rs)
- [Apple Silicon sensors](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/macos_sensors.rs)
- [SMC sensors and fans](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/macos_smc.rs)

## Goals

- Build one macOS-only app named `System Monitor`.
- Keep the menu bar app model: no Dock icon, status item, popover, preferences,
  and quit menu.
- Keep the same dashboard modules: CPU, memory, disk, network, sensors, fans,
  and battery.
- Keep the same settings and warning behavior.
- Keep detailed Apple Silicon temperature readings through
  `IOHIDEventSystemClient`.
- Keep Intel temperature and fan RPM readings through AppleSMC.
- Remove Tauri, React, Vite, Tailwind, Rust workspace, and cross-platform code
  from the new macOS project.
- Use native macOS APIs where they fit.

## Non-goals

- Do not support Windows or Linux in this project.
- Do not target the Mac App Store while detailed private sensors are enabled.
- Do not build Clean Drive in this migration.
- Do not change the main product design unless native controls need small
  changes.

## Main Architecture

Use a small AppKit shell with SwiftUI content.

```text
System Monitor.app
├── AppDelegate
│   ├── NSStatusItem
│   ├── NSMenu
│   ├── NSPopover
│   └── launch / quit lifecycle
├── SwiftUI views
│   ├── DashboardView
│   ├── MetricCardView
│   ├── SettingsView
│   └── ThresholdRowView
├── Models
│   ├── Snapshot
│   ├── Settings
│   ├── WarningThresholds
│   └── NetworkDailyBaseline
├── Services
│   ├── MetricsSampler
│   ├── SettingsStore
│   ├── WarningService
│   ├── LaunchAtLoginService
│   └── NotificationService
└── Collectors
    ├── CpuCollector
    ├── MemoryCollector
    ├── DiskCollector
    ├── NetworkCollector
    ├── BatteryCollector
    ├── HidTemperatureCollector
    └── SmcCollector
```

## Recommended Technology

- Swift 6 or current Xcode Swift version.
- AppKit for status item, popover, app activation policy, and menu.
- SwiftUI for popover and preferences views.
- Combine or Observation for state updates.
- Foundation, Darwin, Mach, IOKit, SystemConfiguration, UserNotifications, and
  ServiceManagement.
- A small C or Objective-C bridge for private sensor functions if Swift import
  is too hard or unsafe.

## Source Behavior To Preserve

The new app should keep this behavior from the source app:

- Start without a normal app window.
- Hide the Dock icon.
- Show a menu bar item with live metrics.
- Left click opens or closes the popover.
- Right click opens a menu with `Preferences...` and `Quit System Monitor`.
- Sample metrics once per second.
- Update the popover and menu bar from the same sampled snapshot.
- Persist settings.
- Track daily network totals with a reset button.
- Send warning notifications only when a threshold is crossed.
- Use hysteresis before a warning can clear.
- Limit repeat notifications to once per 10 minutes per module.

## Data Models

Port the current TypeScript and Rust model shapes into Swift.

Source links:

- [TypeScript models](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/lib/types.ts)
- [Rust settings](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/settings.rs)
- [Rust snapshot](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/lib.rs)

Swift model names:

- `CpuSample`
- `MemorySample`
- `DiskSample`
- `NetworkSample`
- `BatterySample`
- `TemperatureSample`
- `FanSample`
- `Snapshot`
- `Settings`
- `MenuBarSettings`
- `WarningThresholds`
- `TemperatureUnit`
- `NetworkUnits`
- `NetworkDisplay`
- `BatteryState`

Keep JSON keys close to the existing names:

- `usage_percent`
- `core_count`
- `temperature_c`
- `used_bytes`
- `total_bytes`
- `rx_bytes_per_sec`
- `tx_bytes_per_sec`
- `total_rx_bytes`
- `total_tx_bytes`
- `charge_percent`
- `time_to_full_secs`
- `time_to_empty_secs`
- `cycle_count`

This makes settings and snapshot test fixtures easy to compare with the old
app.

## Settings Storage

Use a JSON settings file for easy migration and debugging.

Target path:

```text
~/Library/Application Support/dev.olegoleg.system-monitor/settings.json
```

Keep the same defaults as the source app:

- Show network speed: on
- Show CPU load: on
- Show memory usage: off
- Show disk free: off
- Show battery: on
- Show temperature: off
- Temperature unit: Celsius
- Network units: bytes per second
- Network display: upload and download
- Warnings: on
- Launch at login: off

Implementation notes:

- Use `Codable`.
- Load settings on app start.
- If the file is missing or invalid, use defaults.
- Save immediately when settings change.
- Keep unknown old fields harmless by ignoring them.

## Menu Bar Item

Source link:

- [Tray code](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/tray.rs)

Native plan:

- Use `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)`.
- Use a custom `NSView` for the status item instead of plain title text.
- Render two rows of compact metric text, like the current image renderer.
- Use SF Mono or system monospaced digits.
- Keep the same menu bar modules:
  - CPU
  - TEMP
  - RAM
  - DISK
  - BAT
  - network upload and download
- Keep the same display rules:
  - Do not show disabled modules.
  - Use compact units.
  - Show battery power marker when charging or full.
  - Support bytes per second and bits per second.
  - Support upload/download display modes.
- Add a menu bar display mode preference:
  - Single-line mode remains available.
  - Two-line mode is added as an option.
  - The user can switch between them in Preferences.

Reason for custom view:

- It gives stable layout and native drawing.
- It avoids running an image renderer for every update.
- It keeps two-line menu bar metrics possible.

## Popover

Source links:

- [Tray popover](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/tray.rs)
- [Native Tauri popover bridge](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/macos_popover.rs)

Native plan:

- Use `NSPopover`.
- Use `NSHostingController(rootView:)` for SwiftUI content.
- Preferred size: `450 x 620`.
- Behavior: transient.
- Show relative to the status item button bounds.
- Activate app only when needed for focus.

The native app should no longer need the hidden anchor window workaround used by
the Tauri version.

## Dashboard UI

Source links:

- [Dashboard](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/components/Dashboard.tsx)
- [Metric card](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/components/MetricCard.tsx)
- [Formatters](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/lib/utils.ts)

SwiftUI plan:

- Create `DashboardView`.
- Use a two-column grid.
- Use native SF Symbols:
  - CPU: `cpu`
  - Memory: `memorychip`
  - Disk: `internaldrive`
  - Network: `network`
  - Sensors: `thermometer`
  - Fans: `fan`
  - Battery: `battery.100` and `battery.100.bolt`
  - Settings: `gearshape`
  - Reset: `arrow.counterclockwise`
- Recreate `MetricCardView` with:
  - icon
  - label
  - value
  - subtitle
  - optional progress bar
  - optional warning state
  - optional child content
- Match the same content rules:
  - Show primary disk if present.
  - Show network daily down/up totals and reset button.
  - Show up to 4 temperature sensors.
  - Show up to 4 fans.
  - Show battery card only when a battery exists.
  - If no temperature data exists, let the fan card span two columns.

## Preferences UI

Source links:

- [Settings view](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/components/SettingsView.tsx)
- [Toggle](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/components/Toggle.tsx)

SwiftUI plan:

- Create `SettingsView`.
- Keep the same sections:
  - Show in the menu bar
  - Temperature unit
  - Notifications
  - Startup
- Keep the same toggles:
  - CPU load
  - CPU temperature
  - Memory usage
  - Free disk space
  - Battery status
  - Network speed
- Keep the same warning threshold rows:
  - CPU
  - Temperature
  - Memory
  - Disk free below
  - Battery below
- Keep the warning when too many menu bar modules are enabled.
- Use native `Toggle`, `Picker`, and numeric `TextField` or `Stepper`.

## Metrics Loop

Source link:

- [Metrics loop](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/metrics.rs)

Native plan:

- Create `MetricsSampler`.
- Use one timer that fires every second.
- The timer runs on a background queue.
- Collect all metrics once into one `Snapshot`.
- Publish the snapshot on the main actor.
- Update:
  - dashboard state
  - menu bar view
  - warning service
  - network daily totals

Important rule:

- Do not let the menu bar and popover collect metrics separately.

## CPU Collector

Native APIs:

- `host_processor_info`
- `processor_cpu_load_info`
- `sysctl` for CPU count fallback if needed

Plan:

- Store previous CPU tick totals.
- On each sample, calculate active and total delta.
- Return global CPU usage percent.
- Return logical core count.
- Add CPU temperature from the sensor collector when available.

Acceptance:

- CPU percent should be close to Activity Monitor for normal use.
- First sample may be zero or estimated; later samples should be stable.

## Memory Collector

Source link:

- [macOS memory code](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/macos_memory.rs)

Native APIs:

- `host_statistics64`
- `sysconf(_SC_PAGESIZE)`
- `ProcessInfo.processInfo.physicalMemory`

Plan:

- Keep the current Activity Monitor-style formula:
  - app memory = internal pages minus purgeable pages
  - used memory = app memory + wired memory + compressed memory
- Clamp used memory to total physical memory.
- Return used bytes, total bytes, and used percent.

Acceptance:

- Memory percent should be close to Activity Monitor.

## Disk Collector

Source link:

- [Disk collector](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/disk.rs)

Native APIs:

- `FileManager.mountedVolumeURLs`
- volume resource keys:
  - `.volumeNameKey`
  - `.volumeTotalCapacityKey`
  - `.volumeAvailableCapacityForImportantUsageKey`
  - `.volumeIsRemovableKey`

Plan:

- Collect all mounted volumes with total capacity greater than zero.
- Calculate used bytes and used percent.
- Keep the same primary disk choice:
  - `/System/Volumes/Data`
  - `/`
  - first non-removable disk
  - first disk

Acceptance:

- The disk card should show the same main disk as the source app.

## Network Collector

Source links:

- [Network collector](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/network.rs)
- [Network daily totals](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/lib/networkTotals.ts)

Native APIs:

- `getifaddrs`
- `if_data`
- `SystemConfiguration` for service names, if needed

Plan:

- Ignore loopback interfaces.
- Sum receive and transmit byte counters.
- Store previous total counters.
- Calculate per-second rates from deltas.
- Choose the primary interface by highest total activity.
- Resolve connection label:
  - Wi-Fi
  - Ethernet
  - Thunderbolt
  - Bridge
  - VPN
  - fallback interface name
- Keep daily baseline:
  - date
  - received bytes
  - transmitted bytes
- Reset daily baseline when:
  - date changes
  - counters reset
  - user clicks reset

Acceptance:

- Network rates should be close to the old app.
- Daily totals should survive app restart.

## Battery Collector

Source link:

- [Battery collector](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/battery.rs)

Native APIs:

- `IOPSCopyPowerSourcesInfo`
- `IOPSCopyPowerSourcesList`
- `IOPSGetPowerSourceDescription`
- IORegistry for cycle count if it is not in the power source dictionary

Plan:

- Return `nil` when the Mac has no battery.
- Return:
  - charge percent
  - charging, discharging, empty, full, or unknown state
  - time to full
  - time to empty
  - cycle count
- Use Apple constants when available.

Acceptance:

- Battery card should match the macOS menu bar battery value.

## Temperature And Fan Collectors

Source links:

- [Temperature collector](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/temperature.rs)
- [Apple Silicon HID sensors](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/macos_sensors.rs)
- [SMC sensors and fans](/Users/oleg/Dev/Common/system-utilities/crates/sysmetrics/src/macos_smc.rs)

Decision:

- Keep `IOHIDEventSystemClient` for Apple Silicon detailed temperatures.
- Keep AppleSMC access for Intel temperatures and fan RPM.
- Mark this app as direct distribution only while these features are enabled.

Apple Silicon HID plan:

- Create a small bridge around:
  - `IOHIDEventSystemClientCreate`
  - `IOHIDEventSystemClientSetMatching`
  - `IOHIDEventSystemClientCopyServices`
  - `IOHIDServiceClientCopyEvent`
  - `IOHIDServiceClientCopyProperty`
  - `IOHIDEventGetFloatValue`
- Match:
  - usage page `0xff00`
  - usage `0x0005`
- Read event type `15`.
- Read temperature field `15 << 16`.
- Keep one long-lived client and service list.
- Group raw labels like the source app:
  - Performance Cores
  - Efficiency Cores
  - Graphics
  - Main Chip
  - Power System
  - Storage

SMC plan:

- Use `IOServiceMatching("AppleSMC")`.
- Open the service with `IOServiceOpen`.
- Read key info and data using `IOConnectCallStructMethod`.
- Keep the same temperature keys:
  - `TC0P`: CPU Proximity
  - `TC0D`: CPU Die
  - `TC0E`: CPU PECI
  - `TC0F`: CPU Core
  - `TC0H`: CPU Heatsink
  - `TG0P`: GPU Proximity
  - `TG0D`: GPU Die
- Keep fan keys:
  - `FNum`
  - `F{index}Ac`
  - `F{index}ID`
- Keep the same parsers:
  - `sp78`
  - `fpe2`
  - `flt `
  - `ui8 `
  - `ui16`
  - `ui32`

CPU temperature choice:

- Prefer Apple Silicon Performance/Efficiency core average.
- Fall back to Main Chip.
- On SMC, prefer CPU Die, then CPU Proximity.
- Fall back to hottest sensor.

Acceptance:

- Apple Silicon machines should show grouped sensors.
- Intel machines should show SMC CPU/GPU sensors and fans when available.
- The app should still work when no detailed sensor data is available.

## Warning Service

Source link:

- [Warnings](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src-tauri/src/warnings.rs)

Native APIs:

- `UserNotifications`

Plan:

- Ask notification permission at a clear moment, likely when warnings are
  enabled.
- Keep per-module state:
  - CPU
  - memory
  - disk
  - battery
  - temperature
- Keep warning conditions:
  - CPU >= threshold
  - memory >= threshold
  - disk free <= threshold
  - battery <= threshold while discharging, empty, or unknown
  - temperature >= threshold
- Keep recovery hysteresis:
  - CPU and memory: threshold minus 5
  - temperature: threshold minus 3
  - disk and battery: threshold plus 5
- Keep repeat notification cooldown: 10 minutes.

Notification text should stay simple:

- `CPU warning`
- `Memory warning`
- `Disk warning`
- `Battery warning`
- `Temperature warning`

## Launch At Login

Native API:

- `ServiceManagement.SMAppService`

Plan:

- Add `LaunchAtLoginService`.
- Read current registration state on settings load.
- Register when enabled.
- Unregister when disabled.
- Show a clear disabled state if the API fails.

Acceptance:

- The `Open when Mac starts` toggle changes real launch-at-login state.

## Formatting

Source link:

- [Formatters](/Users/oleg/Dev/Common/system-utilities/apps/system-monitor/src/lib/utils.ts)

Port these functions:

- `formatBytes`
- `formatRate`
- `formatTemperature`
- `formatDuration`
- compact menu bar byte rate formatting
- compact bit rate formatting
- compact disk size formatting

Rules:

- Keep binary units for bytes.
- Keep `KB`, `MB`, `GB`, and `TB` labels.
- Keep Celsius/Fahrenheit support.
- Keep short menu bar values.

## New Project Layout

Recommended root layout:

```text
system-utilities-macos/
├── MIGRATION_PLAN.md
├── README.md
├── SystemMonitor.xcodeproj
├── SystemMonitor/
│   ├── App/
│   │   ├── SystemMonitorApp.swift
│   │   ├── AppDelegate.swift
│   │   └── Info.plist
│   ├── Models/
│   ├── Services/
│   ├── Collectors/
│   ├── Views/
│   ├── Support/
│   └── Resources/
└── SystemMonitorTests/
```

If Swift Package Manager is preferred:

```text
system-utilities-macos/
├── Package.swift
├── Sources/
│   ├── SystemMonitorApp/
│   └── SystemMonitorCore/
└── Tests/
```

For a menu bar app with signing and packaging, an Xcode project is simpler.

## Build And Distribution

Build outputs:

- Debug `.app`
- Release `.app`
- Signed `.app`
- Notarized `.dmg`

Important build setting:

- The app uses private sensor APIs. Keep distribution outside the Mac App Store.

Packaging plan:

- Set bundle identifier: `dev.olegoleg.system-monitor`.
- Set app category: Utilities.
- Add `LSUIElement` or use accessory activation policy.
- Sign with Developer ID.
- Notarize release builds.
- Staple notarization ticket.

## Testing Plan

Unit tests:

- Settings defaults and JSON load/save.
- Formatter output.
- Menu bar column collection.
- Warning threshold and hysteresis logic.
- Network daily baseline reset.
- SMC parsers:
  - `sp78`
  - `fpe2`
  - `flt `
  - `ui8 `
  - `ui16`
  - `ui32`
- Sensor grouping labels.

Manual tests:

- App starts without Dock icon.
- Status item appears.
- Left click toggles popover.
- Right click opens menu.
- Preferences open from menu.
- Settings persist after restart.
- Each menu bar toggle changes menu bar content.
- Dashboard updates every second.
- Network reset button resets totals.
- Warning notification sends once when threshold is crossed.
- Warning does not repeat before cooldown.
- Launch at login toggle works.
- App quits from menu.

Device tests:

- Apple Silicon Mac:
  - HID temperatures show grouped sensors.
  - CPU temperature uses core groups or Main Chip.
- Intel Mac:
  - SMC temperatures show when keys exist.
  - Fan RPM shows when keys exist.
- Desktop Mac without battery:
  - Battery card is hidden.
- MacBook:
  - Battery card is shown.

## Migration Phases

### Phase 1: Project Skeleton

Status: Done.

Deliverables:

- Xcode project or Swift package app.
- `System Monitor` app target.
- App icon placeholder.
- Hidden Dock icon.
- Empty `NSStatusItem`.
- Empty `NSPopover` with SwiftUI root view.

Acceptance:

- App launches.
- App has no Dock icon.
- Menu bar item appears.
- Popover opens and closes.
- App quits cleanly.

### Phase 2: Models And Settings

Status: Done.

Deliverables:

- Swift models for snapshot and settings.
- `SettingsStore`.
- Defaults copied from source app.
- Settings save and load.
- Preferences view with working controls.

Acceptance:

- Changing a setting updates app state.
- Restart keeps changed settings.

### Phase 3: Static UI Parity

Status: First pass done. Final visual parity still needs screenshot review.

Deliverables:

- `DashboardView`.
- `MetricCardView`.
- `SettingsView`.
- Light and dark mode styling.
- Placeholder sample data.

Acceptance:

- Dashboard looks close to the source app.
- Text fits at `450 x 620`.
- Preferences view has all current controls.

### Phase 4: Core Metrics

Status: Done.

Deliverables:

- CPU collector.
- Memory collector.
- Disk collector.
- Network collector.
- One-second `MetricsSampler`.
- Menu bar text updates.

Acceptance:

- CPU, memory, disk, and network update every second.
- Menu bar and dashboard use the same snapshot.

### Phase 5: Battery, Network Totals, And Formatters

Status: Done.

Deliverables:

- Battery collector.
- Daily network baseline store.
- Reset totals action.
- Full formatter parity.

Acceptance:

- Battery card works on MacBook.
- Network daily totals persist.
- Rates and sizes match source app style.

### Phase 6: Detailed Sensors

Status: Implemented. Needs hardware validation on Apple Silicon and Intel Macs.

Deliverables:

- HID temperature bridge.
- SMC bridge.
- Sensor grouping.
- Fan RPM collector.
- CPU temperature selection.

Acceptance:

- Apple Silicon sensors appear when available.
- Intel SMC sensors and fans appear when available.
- App stays stable when sensor APIs return no data.

### Phase 7: Warnings And Notifications

Status: Done.

Deliverables:

- `WarningService`.
- Notification permission flow.
- Warning state and cooldown.
- Warning UI state on metric cards.

Acceptance:

- Warning cards highlight correctly.
- Notifications follow threshold, hysteresis, and cooldown rules.

### Phase 8: Launch At Login

Deliverables:

- `LaunchAtLoginService`.
- Settings toggle wired to `SMAppService`.

Acceptance:

- Toggle changes real login item state.
- App can start after login.

### Phase 9: Polish And Packaging

Deliverables:

- Final icon.
- Signed app.
- Notarized DMG.
- README with run and build steps.
- Known limitations section.

Acceptance:

- Release app can be installed and launched on a clean Mac.
- Notarization passes for direct distribution.

## Main Risks

### Private sensor APIs

`IOHIDEventSystemClient` is private. Apple can change it, and App Store review
is likely to reject it.

Mitigation:

- Keep the bridge small.
- Keep fallback behavior when sensors are missing.
- Document direct distribution only.
- Consider a compile-time flag for a public-only build later.

### SMC differences

SMC keys vary by machine.

Mitigation:

- Treat all sensors as optional.
- Keep key parsing tested.
- Keep labels stable when keys exist.

### Menu bar width

Too many modules can overflow the menu bar.

Mitigation:

- Keep the existing warning when many modules are enabled.
- Keep compact text.
- Consider truncating the least important columns later.

### Energy use

One-second sampling can cost CPU and energy.

Mitigation:

- Use one sampler only.
- Avoid shell commands.
- Cache sensor service lists.
- Do work on a background queue.

## Parity Checklist

- [x] No Dock icon.
- [x] Menu bar status item.
- [ ] Two-line live menu bar metrics.
- [x] Left click popover toggle.
- [x] Right click menu.
- [x] Preferences view.
- [x] CPU card.
- [x] Memory card.
- [x] Disk card.
- [x] Network card.
- [x] Network daily totals.
- [x] Network reset button.
- [x] Temperature sensors card.
- [x] Fan RPM card.
- [x] Battery card.
- [x] Warning thresholds.
- [x] Warning notifications.
- [ ] Launch at login.
- [x] Light mode.
- [x] Dark mode.
- [x] Settings persistence.
- [ ] Signed release build.
- [ ] Notarized release build.

## Suggested First Commit

Create the native app skeleton only:

- Xcode project.
- App delegate.
- Status item.
- Popover.
- Empty SwiftUI dashboard.
- README with local run steps.

Do not port metrics in the first commit. Keep the first change easy to review.
