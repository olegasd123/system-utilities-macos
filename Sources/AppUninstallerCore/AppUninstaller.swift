import AppCore
import Foundation

public struct AppUninstaller: Sendable {
    private let trasher: any FileTrashing
    private let homeDirectory: URL
    private let scanRoots: [URL]

    public init(
        trasher: any FileTrashing = SystemTrash(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        scanRoots: [URL]
    ) {
        self.trasher = trasher
        self.homeDirectory = homeDirectory
        self.scanRoots = scanRoots
    }

    public func uninstall(
        _ app: InstalledApp,
        leftovers: [LeftoverCandidate],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        let safety = AppUninstallerPathSafety(
            appBundleURL: app.bundleURL,
            scanRoots: scanRoots,
            homeDirectory: homeDirectory
        )
        let bundleSize = (try? FileSizeReader.recursiveLogicalSize(of: app.bundleURL)) ?? 0
        let bundle = LeftoverCandidate(
            url: app.bundleURL,
            size: bundleSize,
            kind: .directory,
            confidence: .appBundle
        )
        let items: [any FileReclaimItem] = ([bundle] + leftovers)
            .filter { safety.canRemove($0.url) }
        return try await FileReclaimer.reclaim(items, mode: mode, trasher: trasher)
    }
}
