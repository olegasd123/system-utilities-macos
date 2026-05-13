# App Uninstaller — Feature Plan

A third feature alongside System Monitor and Clean Drive: list installed
apps, surface their leftovers across the filesystem, and uninstall them
(move to Trash by default, hard delete behind a confirmation).

## Goals

- One-screen view: pick an app, see the bundle plus every related leftover
  with its size, click Uninstall.
- Trash-by-default semantics matching Clean Drive.
- Conservative defaults: only suggest paths we can attribute to the app
  with high confidence; opt-in for fuzzy matches.
- Reuse Clean Drive's reclaim/trash primitives — do not fork them.

## Non-Goals (v1)

- Pkg-receipt-based scanning (`pkgutil --files`, `--forget`).
- Login items / launch agents removal as a separate management surface
  (we delete leftover plist files we find, but don't re-implement
  `launchctl` management).
- Removing kexts, audio plugins, Spotlight importers.
- Mac App Store receipt cleanup.
- Bulk uninstall / multi-select. Single-app flow first; revisit after use.

## Module Layout

Mirror the Clean Drive split.

- Prep refactor:
  - Move generic reclaim and sizing primitives out of `CleanDriveCore`
    before adding this feature. Good candidates:
    - `ReclaimMode`, `ReclaimReport`, `ReclaimFailure`
    - the generic item removal loop now in `CleanDriveReclaimer`
    - allocated-size helpers now in `CleanDriveSizeReader`
  - Prefer `AppCore` if the surface stays small. If it grows, add a
    small shared target like `FileReclaimCore`.
  - Keep Clean Drive category-specific types in `CleanDriveCore`.
- `Sources/AppUninstallerCore/`
  - `InstalledAppsScanner.swift` — enumerate `.app` bundles.
  - `InstalledApp.swift` — model: bundle ID, name, version, icon URL,
    bundle URL, source location, executable name, isSystem.
  - `LeftoverScanner.swift` — given an `InstalledApp`, find related
    paths in `~/Library` and `/Library`.
  - `LeftoverCandidate.swift` — model: URL, size, kind, match
    confidence (`exactBundleID`, `bundleIDPrefix`, `nameHeuristic`).
  - `AppUninstaller.swift` — orchestrates: quit running app, trash
    bundle + selected leftovers, return report.
  - `AppUninstallerSettings.swift` — feature-scoped settings persisted
    through `RawAppSettings`.
  - `AppUninstallerModel.swift` — `@MainActor` observable state for the
    UI (apps list, selection, scan state, in-flight uninstall).
- `Sources/AppUninstallerUI/`
  - `AppUninstallerFeature.swift` — conforms to `PopoverFeature`.
  - `AppUninstallerView.swift` — apps list + leftover detail pane.
  - `UninstallConfirmSheet.swift` — final confirmation, hard-delete
    toggle, failure list.
- `Tests/AppUninstallerCoreTests/` — unit tests for scanner/matcher.

Update `Package.swift` to add the two targets and the test target;
add `AppUninstallerUI` to `App` deps. Update `AppComposer.swift` to
construct the feature and append it to `features`.

## Settings

Persist under `RawAppSettings.features["app-uninstaller"]`:

```swift
public struct AppUninstallerSettings: FeatureSettings {
    public static let featureId = "app-uninstaller"

    public var includeNameHeuristicMatches: Bool   // default false
    public var includeSystemLibraryPaths: Bool     // default true (best effort, fails gracefully)
    public var defaultReclaimMode: ReclaimMode     // default .moveToTrash
}
```

No reminders for this feature — it's user-initiated.

## App Discovery — `InstalledAppsScanner`

Sources to enumerate:

- `/Applications`
- `/Applications/Utilities`
- `~/Applications`
- (Skip `/System/Applications` — those are Apple system apps, never
  uninstallable from our UI.)

For each `*.app` bundle:

- Read `Contents/Info.plist`:
  - `CFBundleIdentifier` (required — skip bundles without one).
  - `CFBundleName` / `CFBundleDisplayName` / fall back to bundle file name.
  - `CFBundleShortVersionString`.
- Capture the bundle's icon URL (Info.plist `CFBundleIconFile`, expanded
  to `Contents/Resources/<name>.icns`) so SwiftUI can render it via
  `NSWorkspace.shared.icon(forFile:)`.
- Capture the executable name from `CFBundleExecutable`. It is useful
  for matching helper files and for detecting running apps.
- Determine `isSystem` conservatively:
  - `true` when the path starts with `/System/`.
  - `true` for a small protected bundle-id denylist if needed.
  - **Do not** hide every Apple-signed app. Apple-signed apps in
    `/Applications`, such as Xcode or GarageBand, can be valid
    uninstall candidates.
  - Always refuse to uninstall this app itself by comparing the bundle
    ID with `Bundle.main.bundleIdentifier`.
- Hide true system apps from the list (do not even offer the Uninstall
  button).

Sort the list alphabetically; the UI can filter by typed query.

### Performance

Discovery is cheap (a few hundred bundles, plist reads). Run on a
background `Task` and post results to the `@MainActor` model.
Leftover scans run on demand when an app is selected — never eagerly
across the whole list.

## Leftover Scanner — `LeftoverScanner`

The core matching problem: given a bundle ID like `com.apple.dt.Xcode`
and product name `Xcode`, find every directory or file owned by that
app outside the bundle itself.

### Scan locations

User-scope (no auth needed):

- `~/Library/Application Support/`
- `~/Library/Caches/`
- `~/Library/Preferences/`
- `~/Library/Logs/`
- `~/Library/Containers/`
- `~/Library/Group Containers/`
- `~/Library/Saved Application State/`
- `~/Library/HTTPStorages/`
- `~/Library/WebKit/`
- `~/Library/Cookies/` (file: `<bundle id>.binarycookies`)
- `~/Library/Application Scripts/`
- `~/Library/LaunchAgents/`

System-scope (read-only attempt; deletion will need admin and may fail):

- `/Library/Application Support/`
- `/Library/Caches/`
- `/Library/Preferences/`
- `/Library/Logs/`
- `/Library/LaunchAgents/`
- `/Library/LaunchDaemons/`
- `/Library/PrivilegedHelperTools/`

Each scan location is enumerated **one level deep**: we look at
immediate children and decide whether each name belongs to this app.

### Match rules (in priority order)

1. **Exact bundle ID match.** Directory or file basename equals
   `com.example.App` or `com.example.App.plist` → confidence
   `exactBundleID`.
2. **Reverse-DNS prefix match.** Basename starts with
   `com.example.App.` (note trailing dot), e.g.
   `com.apple.dt.Xcode.sourcecontrol` → confidence `bundleIDPrefix`.
   This handles helper agents, XPC services, and XCode's many
   sub-bundle IDs.
3. **Name heuristic.** Basename equals product name (case-insensitive),
   or basename equals product name with spaces stripped → confidence
   `nameHeuristic`. Only included when
   `settings.includeNameHeuristicMatches` is true.

Special case: `~/Library/Containers/<bundle id>` and
`~/Library/Group Containers/<group id>`. The container directory is
named after the bundle ID (rule 1). Group containers are trickier:
they use a group ID like `XXXXXXXXXX.com.example.shared`.

For v1, prefer exact app-group IDs from the app's entitlements. Read
`com.apple.security.application-groups` from `codesign -d --entitlements -`
or an equivalent structured API, then include only those exact group
container directories. If entitlement reading is not available or fails,
skip group containers and add a note. Do not use broad name-only group
container guesses by default.

### Sizing

Use the shared size helper from the prep refactor to compute on-disk
sizes for each candidate. This is the slow part; do it after match
enumeration so we can show "Scanning sizes…" in the UI and stream
results in.

### Safety

Add an App Uninstaller path safety gate before anything is shown as a
deletable candidate and again before removal. It should:

- Only allow the selected `.app` bundle and candidates under the known
  scan roots.
- Reject root paths such as `/`, `/System`, `/Library`, `~/Library`,
  and the user's home directory.
- Reject paths that are parents of known scan roots.
- Do not follow symlinks. If a symlink itself is matched, trash only the
  link, never its target.
- Reject candidates whose standardized path escapes the scan root.
- Keep this logic covered by unit tests.

### Output

```swift
public struct LeftoverScanResult {
    public var app: InstalledApp
    public var bundle: LeftoverCandidate          // the .app bundle itself
    public var leftovers: [LeftoverCandidate]
    public var notes: [String]                    // FDA hints, permission failures
}
```

## Uninstall Orchestration — `AppUninstaller`

```swift
public func uninstall(
    _ app: InstalledApp,
    leftovers: [LeftoverCandidate],
    mode: ReclaimMode
) async throws -> ReclaimReport
```

Steps:

1. **Detect running.** Check `NSWorkspace.shared.runningApplications`
   for a match on bundle ID. If running, ask the user (in the UI
   confirm sheet) to quit. Send `terminate()` if they accept; if it
   refuses, surface a failure note and abort.
2. **Trash bundle.** Move the `.app` to Trash (or hard delete).
3. **Trash leftovers.** Iterate the user-confirmed list and delegate
   to the same `CleanDriveTrashing` implementation Clean Drive uses
   (`SystemTrash` for trash mode; permanent removal for hard delete).
4. **Collect failures.** Permission errors (typical for `/Library`
   paths) become `ReclaimFailure` entries — don't throw, just report.
5. **Return `ReclaimReport`** so the UI can show bytes reclaimed and
   the failure list using the same formatting Clean Drive already has.

We deliberately reuse `ReclaimMode`, `ReclaimReport`, `ReclaimFailure`
from the shared reclaim helper rather than defining parallel types.

Permission behavior is best-effort in v1. The app will not install or
run a privileged helper, and it will not prompt for admin credentials.
Paths under `/Library` may fail to delete; those failures become
`ReclaimFailure` entries. The UI should explain that some items may
need manual removal or Full Disk Access.

## UI Flow — `AppUninstallerView`

Three regions in the popover, top to bottom:

1. **Search field + apps list.** Scrollable list of `InstalledApp`
   rows: icon, name, version, bundle path. Click selects.
2. **Detail pane** (right side / below depending on layout). Shows:
   - Selected app's bundle row with size.
   - "Leftovers" section: grouped by confidence
     (`Exact match`, `Related (bundle ID prefix)`, and if enabled,
     `Possibly related (name match)`).
   - Each row: path, size, checkbox (defaults: on for exact + prefix,
     off for name heuristic).
   - "Show possibly related items" toggle if heuristic matches found.
3. **Action bar.** "Uninstall" button → opens `UninstallConfirmSheet`
   summarising the count, total size, and the hard-delete toggle.

Confirm sheet mirrors Clean Drive's permanent-delete flow so users get
a consistent experience. After completion, show the `ReclaimReport`
inline (bytes reclaimed, failures with reason).

Empty / loading states:

- "Scanning installed apps…" on first open.
- "No apps found" if the user's `/Applications` is empty (unlikely).
- "Scanning leftovers…" while the leftover scan + sizing runs.

## Edge Cases

- **App is itself.** Refuse to uninstall System Monitor (compare
  bundle ID against our own).
- **Apple-signed app in `/Applications`.** Do not treat this as system
  by signature alone. Xcode and similar apps should be removable.
- **App is currently running.** Confirm sheet must require the user
  to quit it; we send `terminate()` on confirm and wait briefly.
  Force-terminate is out of scope.
- **Symlinks.** Don't follow them while scanning leftovers; trash the
  link, not the target.
- **Cloud-synced library paths.** macOS doesn't sync `~/Library` to
  iCloud Drive by default; no special handling unless the user has
  rebound it. Document that we don't follow.
- **Full Disk Access.** Some `~/Library` subpaths (e.g.
  `~/Library/Containers/com.apple.mail`) refuse to enumerate without
  FDA. Reuse Clean Drive's FDA callout component.
- **Apps installed via Homebrew Cask.** We just remove the bundle and
  leftovers; Homebrew's metadata won't be updated. Surface a hint in
  notes ("Looks like a Homebrew Cask install. Run `brew uninstall
  --cask <name>` to update Homebrew's records.") if we can detect it
  (the bundle's parent dir is `/Applications` but Homebrew records the
  install in `/opt/homebrew/Caskroom/<name>` or
  `/usr/local/Caskroom/<name>` — check existence). Keep this as a
  note only; do not modify Homebrew metadata.

## Tests (`AppUninstallerCoreTests`)

- `LeftoverScanner` matching rules: feed a fixture directory tree with
  known bundle ID and assert which paths are picked up at each
  confidence tier.
- `InstalledAppsScanner` filters: malformed Info.plist, missing bundle
  ID, system app exclusion.
- Path safety: rejects root paths, scan-root parents, escaped
  standardized paths, and symlink targets.
- `AppUninstaller` happy path with an injected `CleanDriveTrashing`
  (use `DirectoryTrash` pointed at a temp dir); assert files moved
  and report numbers correct.
- `AppUninstaller` failure path: trashing fails for one item → the
  rest still succeed and the failure appears in the report.

## Wiring Checklist

- [ ] `Package.swift`: add `AppUninstallerCore`, `AppUninstallerUI`,
      `AppUninstallerCoreTests` targets; add `AppUninstallerUI` to `App`
      dependencies.
- [ ] `RawAppSettings`: register `AppUninstallerSettings` with
      `featureId = "app-uninstaller"` and persist defaults from
      `AppComposer` when missing.
- [ ] `AppComposer.swift`: construct the model, settings, and feature;
      append to `features`.
- [ ] `PopoverRouter`: nothing to change — feature ID routing already
      works via `AppFeature.id`.
- [ ] `RootPopoverView`: no change expected if it already iterates
      `composer.features` for tabs (verify).
- [ ] README "Features" section: add an "App Uninstaller" subsection.
- [ ] Release-checks list in README: add a manual test for uninstalling
      a throwaway app.

## Phased Rollout

1. **Phase 1 — Discovery + listing.** `InstalledAppsScanner`, basic
   list UI, no leftover scan, no uninstall action. Verify discovery
   on real machines.
2. **Phase 2 — Leftover scanning (read-only).** `LeftoverScanner` with
   exact + prefix rules; UI shows leftover list and total size; still
   no destructive action. Verify match accuracy on a known set of
   apps (Slack, Discord, Visual Studio Code, Chrome).
3. **Phase 3 — Uninstall (trash mode).** Wire `AppUninstaller` end to
   end with `SystemTrash`. Confirm sheet, running-app check, report.
4. **Phase 4 — Hard delete + heuristics toggle + settings UI.**
5. **Phase 5 (deferred — separate plan).** `pkgutil` receipt scanner
   and admin-elevated deletion for `/Library` paths.

## Open Questions

- Does `RootPopoverView` build its tab bar from `composer.features`
  dynamically, or is the tab list hand-rolled? If hand-rolled, the
  wiring step needs an extra edit there.
- Should the shared reclaim/sizing helpers live in `AppCore`, or should
  we add a small `FileReclaimCore` target? Lean toward `AppCore` unless
  the shared surface grows during implementation.
- Do we want any opt-in telemetry for "leftovers found per app" so we
  can tune match rules? Probably no — keep it local-only, consistent
  with the rest of the app.
