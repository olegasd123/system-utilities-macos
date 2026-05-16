import AppCore
import AppKit
import Combine
import Foundation

@MainActor
public final class AppUninstallerModel: ObservableObject {
    @Published public private(set) var apps: [InstalledApp] = []
    @Published public var query: String = ""
    @Published public private(set) var selectedApp: InstalledApp?
    @Published public private(set) var scanResult: LeftoverScanResult?
    @Published public private(set) var selectedLeftoverIDs: Set<String> = []
    @Published public private(set) var isLoadingApps = false
    @Published public private(set) var isScanningLeftovers = false
    @Published public private(set) var isUninstalling = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastReclaimReport: ReclaimReport?

    private let appScanner: InstalledAppsScanner
    private let leftoverScanner: LeftoverScanner
    private let trasher: any FileTrashing
    private let homeDirectory: URL
    private let settingsModel: SettingsModel<AppUninstallerSettings>?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        appScanner: InstalledAppsScanner = InstalledAppsScanner(),
        leftoverScanner: LeftoverScanner = LeftoverScanner(),
        trasher: any FileTrashing = SystemTrash(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        settings: SettingsModel<AppUninstallerSettings>? = nil
    ) {
        self.appScanner = appScanner
        self.leftoverScanner = leftoverScanner
        self.trasher = trasher
        self.homeDirectory = homeDirectory
        self.settingsModel = settings

        settings?.publisher
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.scanSelectedApp()
                }
            }
            .store(in: &cancellables)
    }

    public var filteredApps: [InstalledApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return apps
        }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmed)
                || app.bundleIdentifier.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public var selectedLeftovers: [LeftoverCandidate] {
        guard let scanResult else {
            return []
        }
        return scanResult.leftovers.filter { selectedLeftoverIDs.contains($0.id) }
    }

    public var selectedBytes: UInt64 {
        guard let scanResult else {
            return 0
        }
        return scanResult.bundle.size + selectedLeftovers.reduce(0) { $0 + $1.size }
    }

    public var canUninstall: Bool {
        scanResult != nil && !isLoadingApps && !isScanningLeftovers && !isUninstalling
    }

    public var settings: AppUninstallerSettings {
        settingsModel?.settings ?? .defaultValue
    }

    public func loadAppsIfNeeded() async {
        guard apps.isEmpty else {
            return
        }
        await loadApps()
    }

    public func loadApps() async {
        guard !isLoadingApps else {
            return
        }
        isLoadingApps = true
        errorMessage = nil
        scanResult = nil
        selectedLeftoverIDs = []
        lastReclaimReport = nil

        do {
            let scanner = appScanner
            let found = try await Task.detached(priority: .utility) {
                try scanner.scan()
            }.value
            apps = found
            if let selectedApp, found.contains(where: { $0.id == selectedApp.id }) {
                self.selectedApp = selectedApp
            } else {
                selectedApp = found.first
                scanResult = nil
                selectedLeftoverIDs = []
            }
        } catch is CancellationError {
            errorMessage = "Scan canceled."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingApps = false
        if selectedApp != nil {
            await scanSelectedApp()
        }
    }

    public func selectApp(_ app: InstalledApp) {
        guard selectedApp?.id != app.id else {
            return
        }
        selectedApp = app
        scanResult = nil
        selectedLeftoverIDs = []
        lastReclaimReport = nil
        Task {
            await scanSelectedApp()
        }
    }

    public func scanSelectedApp() async {
        guard let selectedApp, !isScanningLeftovers else {
            return
        }
        isScanningLeftovers = true
        errorMessage = nil

        do {
            let scanner = leftoverScanner
            let settings = settings
            let result = try await Task.detached(priority: .utility) {
                try scanner.scan(app: selectedApp, settings: settings)
            }.value
            scanResult = result
            selectedLeftoverIDs = Set(
                result.leftovers
                    .filter(\.isSelectedByDefault)
                    .map(\.id)
            )
        } catch is CancellationError {
            errorMessage = "Scan canceled."
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanningLeftovers = false
    }

    public func setSelected(_ candidate: LeftoverCandidate, isSelected: Bool) {
        if isSelected {
            selectedLeftoverIDs.insert(candidate.id)
        } else {
            selectedLeftoverIDs.remove(candidate.id)
        }
    }

    @discardableResult
    public func uninstallSelected() async -> ReclaimReport? {
        guard let scanResult, canUninstall else {
            return nil
        }
        isUninstalling = true
        defer {
            isUninstalling = false
        }
        errorMessage = nil
        lastReclaimReport = nil

        let app = scanResult.app
        do {
            try await terminateIfRunning(app)
            let scanner = leftoverScanner
            let scanRoots = scanner.scanRoots(includeSystem: settings.includeSystemLibraryPaths)
            let uninstaller = AppUninstaller(
                trasher: trasher,
                homeDirectory: homeDirectory,
                scanRoots: scanRoots
            )
            let leftovers = selectedLeftovers
            let mode = settings.defaultReclaimMode
            let report = try await Task.detached(priority: .utility) {
                try await uninstaller.uninstall(app, leftovers: leftovers, mode: mode)
            }.value
            lastReclaimReport = report
            await loadApps()
            lastReclaimReport = report
            return report
        } catch is CancellationError {
            errorMessage = "Uninstall canceled."
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    private func terminateIfRunning(_ app: InstalledApp) async throws {
        guard let runningApp = runningApplication(for: app) else {
            return
        }
        runningApp.terminate()
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if runningApplication(for: app) == nil {
                return
            }
        }
        throw AppUninstallerError.appStillRunning(app.name)
    }

    private func runningApplication(for app: InstalledApp) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == app.bundleIdentifier
        }
    }
}

public enum AppUninstallerError: LocalizedError, Equatable {
    case appStillRunning(String)

    public var errorDescription: String? {
        switch self {
        case .appStillRunning(let name):
            return "\(name) is still running. Quit it and try again."
        }
    }
}
