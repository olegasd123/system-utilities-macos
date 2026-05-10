# Clean Drive — Implementation Plan

A second utility alongside System Monitor. Scans the user's Mac for reclaimable
space, groups results by category, and lets the user reclaim space safely
(default: move to Trash, not hard-delete). Optionally reminds when reclaimable
space crosses a threshold.

The plan is written so it can be executed top-to-bottom without further
research. Section headers map to milestones; each milestone leaves the app in a
runnable state.

---

## 1. Goals & non-goals

### Goals
- Land Clean Drive as a peer feature next to System Monitor, sharing the
  existing app shell, settings store, notification runtime, and launch-at-login
  plumbing.
- Surface reclaimable space across categories that actually return non-zero
  numbers on a modern macOS install.
- Default to **safe** reclamation: items go to `~/.Trash` so the user can
  restore. Hard-deletion is opt-in.
- Reuse the existing per-feature settings schema (v2 `features[id]` blob).
- Add a reminder ("≥ N GB ready for cleanup") that piggybacks on the existing
  notification runtime, throttled to at most once per day.

### Non-goals (now)
- Per-app uninstall (Mobile apps row in the mockup) — out of scope; replaced
  with developer-oriented categories.
- iOS device backups / iTunes temp — almost always empty on modern Macs;
  excluded.
- Live mounted-volume cleanup other than the boot volume.
- Full Spotlight-style "find duplicates" search.
- Mac App Store distribution. The host app already targets Developer ID direct
  distribution, so we can use full-disk-access-gated scans.

---

## 2. Architecture overview

The current package layout is feature-plugin based:

- `AppCore` — shared settings, launch-at-login, notification runtime.
- `AppUI` — shared view chrome + the `AppFeature` / `PopoverFeature` /
  `MenuBarFeature` protocols.
- `SystemMonitorCore` / `SystemMonitorUI` — the System Monitor feature.
- `App` — composition root; instantiates features and wires the popover router.

Clean Drive mirrors the System Monitor split:

- **`CleanDriveCore`** — pure logic: categories, scanning, sizing, reclaim
  (move-to-Trash / hard-delete), reminder service, settings model.
- **`CleanDriveUI`** — popover view, settings section, `CleanDriveFeature`
  conforming to `PopoverFeature`.

`AppComposer` registers a second feature; the existing tab strip in
`RootPopoverView` (already conditional on `features.count > 1`) will surface
both icons automatically.

### Package.swift diff (target shape)

```swift
.target(
    name: "CleanDriveCore",
    dependencies: ["AppCore"]
),
.target(
    name: "CleanDriveUI",
    dependencies: ["AppCore", "AppUI", "CleanDriveCore"]
),
.testTarget(
    name: "CleanDriveCoreTests",
    dependencies: ["AppCore", "CleanDriveCore"]
),
```

And add `CleanDriveUI` to the `App` executable's dependency list.

---

## 3. Category model

A `CleanDriveCategory` is the unit of scan + reclaim. Categories are
protocol-based so we can ship more without touching the model.

```swift
public protocol CleanDriveCategory: Sendable {
    var id: CleanDriveCategoryID { get }         // stable string id
    var displayName: String { get }              // "Log files"
    var symbolName: String { get }               // SF Symbol
    var requiresFullDiskAccess: Bool { get }
    var defaultEnabled: Bool { get }

    /// Enumerate candidate items (paths + sizes). Must be cancellable and
    /// off the main actor. Should not delete anything.
    func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult
}

public protocol ReclaimableCategory: CleanDriveCategory {
    /// Reclaim the items returned from `scan`. Default behavior:
    /// move to ~/.Trash. `mode == .hardDelete` only when the user opts in.
    func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport
}
```

`CleanDriveScanResult` carries: items, total bytes, per-item paths, and any
"skipped because permission denied" notes. `CleanDriveItem` is
`(url, size, kind)` where `kind ∈ {file, directory}`.

### Categories shipped in v1

Re-scoped vs. the mockup so every row has a realistic chance of finding bytes.

| ID                    | Display name              | Source                                                                                                | Requires FDA | Default on |
|-----------------------|---------------------------|-------------------------------------------------------------------------------------------------------|--------------|-----------|
| `user-caches`         | User caches               | `~/Library/Caches/*` minus an allowlist of "do not touch" bundle ids (see §4.2)                       | no           | yes       |
| `user-logs`           | Log files                 | `~/Library/Logs/*`, `/private/var/log/*` (only readable subset)                                       | no           | yes       |
| `trash`               | Trash                     | `~/.Trash` and per-volume `.Trashes/<uid>`                                                            | no           | no        |
| `xcode-derived`       | Xcode derived data        | `~/Library/Developer/Xcode/DerivedData/*`                                                             | no           | yes       |
| `xcode-archives`      | Xcode archives (old)      | `~/Library/Developer/Xcode/Archives/*` older than N days                                              | no           | no        |
| `xcode-device-support`| Xcode device support      | `~/Library/Developer/Xcode/iOS DeviceSupport`, `watchOS DeviceSupport`, etc.                          | no           | no        |
| `xcode-simulators`    | Unavailable simulators    | `xcrun simctl delete unavailable` (dry-run sizes via `~/Library/Developer/CoreSimulator/Caches`)      | no           | no        |
| `homebrew-cache`      | Homebrew cache            | `brew --cache` directory                                                                              | no           | yes       |
| `browser-caches`      | Browser caches            | Safari, Chrome, Arc, Firefox cache dirs (only browsers that exist on disk)                            | yes (Safari) | no        |
| `mail-cache`          | Mail cache                | `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads`                                     | yes          | no        |
| `downloads-old`       | Downloads (older than N)  | `~/Downloads/*` mtime older than threshold; **preview-only by default**                               | no           | no        |
| `software-updates`    | Old updates               | `/Library/Updates`, `~/Library/Application Support/SoftwareUpdate`                                    | no           | no        |

We will **not** ship Mobile apps / iTunes temp / iOS device backups categories.
If a user demands them later they're a small follow-up.

### Hard exclusions (never scanned, never deleted)
- Anything under `/System`, `/Library/Apple`, `/private/var/db`.
- Any path matching `*/iCloud Drive/*` or known cloud-sync roots.
- Active Xcode / Simulator processes' currently-open derived data dirs (probe
  via `lsof` on the directory; skip on hit).
- Any path inside the running app's container.

---

## 4. Scanning

### 4.1 Scan pipeline

`CleanDriveModel` (main-actor `ObservableObject`) owns scan state per
category. A scan kicks off a `Task` per category, each running on a background
queue via `Task.detached(priority: .utility)`. Categories report progress
through an `AsyncStream<CleanDriveScanProgress>` so the UI can show per-row
spinners.

Per-category timeout: 30 s. Whole-pass timeout: 120 s. On timeout we keep the
partial result and mark the category "incomplete".

Sizing uses `URLResourceKey.totalFileAllocatedSizeKey` (allocated, not logical)
to match what Finder shows. Directories are summed with a depth-limited
`FileManager.enumerator` that skips package contents (`.skipsPackageDescendants`).

### 4.2 Cache allowlist / blocklist

Hard-deleting random `~/Library/Caches` entries is a known footgun. The
`user-caches` category will:

1. List immediate children of `~/Library/Caches`.
2. **Skip** any bundle id in a curated `dangerous-cache-bundle-ids.json`
   resource. Initial entries: `com.apple.AddressBook`, `com.apple.Photos`,
   `com.apple.Safari` (Safari has its own row), iCloud-syncing apps, anything
   that's actually persistent state mislabeled as "cache".
3. Move selected children to Trash on reclaim.

The list ships in `CleanDriveCore/Resources/` and is unit-tested for
malformed JSON.

### 4.3 Permission detection

For `requiresFullDiskAccess` categories, we attempt a probe read of one known
file. If it fails with `EPERM`, the category result is `.permissionDenied`
instead of `.success(items)`. The UI renders a "Grant Full Disk Access" button
that opens
`x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.

---

## 5. Reclamation

### 5.1 Default: move to Trash

```swift
try FileManager.default.trashItem(at: url, resultingItemURL: nil)
```

This preserves restore-from-Trash. A reclaim report sums `bytesReclaimed`
(actually moved) and lists `failures` with reasons.

### 5.2 Hard-delete (opt-in, with confirmation)

Settings toggle: "Permanently delete instead of moving to Trash" (default off).
When enabled, the Clean Up button shows a confirmation sheet that names the
categories and total size, with a typed-confirmation pattern only if a category
is in a "danger" set (Mail cache, browser data).

### 5.3 Concurrency & cancellation

Reclaim runs as a single `Task` that processes items serially per category to
avoid thrashing the disk. The user can cancel mid-flight; partially-reclaimed
items are reported.

### 5.4 Dry-run preview (must-have)

Before reclaim, the user can click "Show files…" on any row to see the top N
items by size. This is rendered as a list sheet — purely informational, no
deletion controls. This is what protects the user from a one-button-deletes-
everything regret.

---

## 6. Settings

`CleanDriveSettings: FeatureSettings` with `featureId = "clean-drive"`. JSON
shape:

```json
{
  "categories": {
    "user-caches":    { "enabled": true },
    "user-logs":      { "enabled": true },
    "trash":          { "enabled": false },
    "xcode-derived":  { "enabled": true }
  },
  "reminders": {
    "enabled": true,
    "thresholdBytes": 2147483648,
    "minHoursBetweenReminders": 24
  },
  "reclaim": {
    "permanentlyDelete": false,
    "downloadsOlderThanDays": 30,
    "xcodeArchivesOlderThanDays": 60
  },
  "lastReminderAt": null
}
```

Persisted via the existing `RawAppSettings.features["clean-drive"]` blob —
no schema migration needed. The v2 store already round-trips arbitrary
feature blobs.

The settings section view (rendered inside the existing global Preferences
screen) groups: Categories, Reminders, Reclaim safety.

---

## 7. Reminder service

`CleanDriveReminderService` runs a low-frequency background timer (every 30
minutes while the app is alive). On each tick:

1. If `reminders.enabled == false`, return.
2. If `now - lastReminderAt < minHoursBetweenReminders`, return.
3. Run a "fast scan" (sizing only, no item enumeration) across enabled
   categories.
4. If total reclaimable ≥ `thresholdBytes`, post a notification via the
   existing `NotificationRuntime` and write `lastReminderAt = now`.

Notification action: open the Clean Drive popover. We reuse the same
notification permission flow already in `AppCore`.

The fast scan is a separate code path on each category: `scanSizeOnly()` that
returns a `UInt64` without retaining item URLs. This keeps memory bounded
when the user never opens the popover.

---

## 8. UI

### 8.1 Popover view

Mirrors the screenshot layout:

- Header: "Clean Drive".
- Hero: total reclaimable in GB + "Ready for Cleanup" subtitle.
- Stacked horizontal bar: one segment per enabled category, color by category.
- Category rows:
  - Checkbox (binds to "include in next reclaim").
  - SF Symbol + display name.
  - Trailing size, dimmed when zero or pending.
  - "Show files…" disclosure on hover for non-zero rows.
  - "Grant Full Disk Access" inline CTA when `permissionDenied`.
- Footer:
  - **Clean Up** primary button. Disabled when nothing selected or scan
    in-flight.
  - **Manage Storage…** link → `x-apple.systempreferences:com.apple.settings.Storage`.
- Empty state when scan returns 0 across the board: "Nothing to clean."

Tab strip: already implemented; will pick up the second feature for free.

### 8.2 Settings section

- **Categories**: list with per-category enable toggles.
- **Reminders**: master toggle + threshold slider (1–10 GB) + minimum hours
  between reminders.
- **Reclaim safety**: "Move to Trash" (default) vs. "Permanently delete"
  radio. Two informational lines per choice.
- **Advanced**: Downloads-older-than-N days, Xcode archives older-than-N days.

### 8.3 Symbol & feature metadata

```swift
public let id = "clean-drive"
public let displayName = "Clean Drive"
public let symbolName = "internaldrive"
```

Optional v1.1: conform to `MenuBarFeature` and surface "X GB ready" when
threshold met. Off by default. Not in v1 scope.

---

## 9. Telemetry & logs

Use `os.Logger` with subsystem `dev.oleg-verhoglyad.SystemMonitor` and
category `clean-drive`. Log:
- Scan start/finish per category with byte totals + duration.
- Reclaim mode + result counts (no file paths).
- Reminder fires.

No analytics. No network calls.

---

## 10. Tests

`CleanDriveCoreTests` is the primary test target. Tests drive against a
temp-dir fixture, never the user's real `~/Library`.

### Unit tests
- Category sizing matches `du -sb` on a fixture tree (allocated-size variant).
- `user-caches` skips every entry in the dangerous-bundle-ids allowlist.
- `xcode-archives` filters by mtime threshold correctly.
- `CleanDriveReminderService`:
  - Throttle window honored.
  - No fire when `enabled == false`.
  - No fire when below threshold.
  - `lastReminderAt` persisted via injected settings store.
- Settings codable round-trip; default values preserved when JSON keys missing.
- Permission probe returns `.permissionDenied` on injected `EPERM`.

### Integration tests (still inside the temp dir)
- Move-to-Trash path via a fake `Trasher` protocol; assert items removed from
  source dir and `bytesReclaimed` accurate.
- Hard-delete path; assert files gone and `bytesReclaimed` accurate.
- Cancellation mid-reclaim leaves the source dir partially populated and
  reports the remaining items as not-reclaimed.

### Manual checks
- Run `swift run SystemMonitor`, switch to Clean Drive tab, verify each
  category's size against `du -sh` of its source path.
- Trigger reminder by lowering threshold to 0 and waiting one tick; verify
  notification arrives in a packaged build (raw SwiftPM exec can't deliver).
- FDA flow: revoke FDA on the dev build, confirm `mail-cache` shows the
  CTA and clicking it opens the right pane.

---

## 11. Milestones

Each milestone ends with a runnable, committable state.

### M1 — Skeleton (no real scanning yet) — Done
- Add `CleanDriveCore` + `CleanDriveUI` + `CleanDriveCoreTests` targets to
  `Package.swift`.
- Empty `CleanDriveSettings`, `CleanDriveModel`, `CleanDriveFeature`.
- Register feature in `AppComposer`. Tab strip should render two icons.
- Popover shows "Coming soon" placeholder.

**Exit criteria**: app builds, both tabs render, settings file gains an empty
`clean-drive` blob after first run.

### M2 — One real category end-to-end (`user-caches`) — Done
- Implement scan + size + items.
- Implement move-to-Trash reclaim.
- Render row with checkbox, size, Clean Up button.
- Tests for sizing + reclaim against a temp-dir fixture.

**Exit criteria**: clicking Clean Up actually moves a known fixture file to
the Trash and the row updates.

### M3 — Remaining categories
- Logs, Trash, Xcode (DerivedData / Archives / DeviceSupport / Simulators),
  Homebrew cache, browser caches, Mail cache (with FDA gating), Downloads
  (older than), Software updates.
- Hard-delete path + confirmation sheet.
- "Show files…" preview sheet.

**Exit criteria**: all rows return realistic sizes on the dev machine; FDA
gate works for Mail.

### M4 — Settings UI
- Categories, Reminders, Reclaim safety, Advanced sections.
- Settings round-trip to JSON.

**Exit criteria**: every settings option is wired and persists across restart.

### M5 — Reminder service
- Background timer, fast-scan code paths, throttling, notification.
- Tests for throttle / threshold / disable.

**Exit criteria**: reminder fires once per day max in a packaged build when
threshold is exceeded; never fires when disabled.

### M6 — Polish & ship
- Tab-strip visual check at two features.
- Update `README.md` with Clean Drive section + features list.
- Update build/sign/notarize scripts only if new entitlements are needed
  (Mail / browser scans run in user space; **no new entitlements expected**).
- Manual release-checklist run.

---

## 12. Open decisions (need a call before M2)

1. **Default reminder threshold**: mockup says 2 GB; that fires too often on
   a dev machine. Suggest **5 GB** default, slider 1–20 GB.
2. **Hard-delete default**: keep off (plan assumes off). Confirm.
3. **Menu-bar surface in v1**: leave off (plan assumes off). Confirm.
4. **Mobile apps / iTunes temp / iOS backups categories**: plan drops them.
   Confirm OK.

---

## 13. Risk log

| Risk                                                | Mitigation                                                                            |
|-----------------------------------------------------|---------------------------------------------------------------------------------------|
| Deleting the wrong cache breaks an app              | Allowlist + move-to-Trash default + dry-run preview                                   |
| FDA-gated categories silently report 0              | Permission probe → explicit `permissionDenied` state with a CTA                       |
| Long scans freeze the UI                            | All scans on background tasks, per-category + global timeout, progress reported       |
| Reclaim during active Xcode build corrupts artifacts| `lsof` probe on derived data dir; skip if Xcode has handles open                      |
| Reminder spam                                       | `minHoursBetweenReminders` floor, `lastReminderAt` persisted                          |
| Settings schema collision with future features      | Already isolated under `features["clean-drive"]`; no shared keys                      |
| iCloud Drive items "deleted" but actually re-synced | Hard exclusion of cloud-sync roots from all scans                                     |

---

## 14. Out of scope follow-ups (parking lot)

- Per-app uninstall (drag-app-to-trash + leftover sweep).
- "Find duplicates" across `~/Downloads`, `~/Desktop`, `~/Documents`.
- Time Machine local snapshot pruning.
- Localization beyond en-US.
- Mac App Store build (would require dropping FDA-gated categories).
