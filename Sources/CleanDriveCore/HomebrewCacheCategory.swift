import Foundation

public struct HomebrewCacheCategory: ReclaimableCategory {
    public let id: CleanDriveCategoryID = .homebrewCache
    public let displayName = "Homebrew cache"
    public let symbolName = "shippingbox"
    public let requiresFullDiskAccess = false
    public let defaultEnabled = true

    private let trasher: any CleanDriveTrashing
    private let commandRunner = CleanDriveCommandRunner()

    public init(trasher: any CleanDriveTrashing = SystemTrash()) {
        self.trasher = trasher
    }

    public func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        guard let cacheURL = try cacheDirectory() else {
            return CleanDriveScanResult(items: [])
        }

        let category = PathCleanDriveCategory(
            id: id,
            displayName: displayName,
            symbolName: symbolName,
            requiresFullDiskAccess: requiresFullDiskAccess,
            defaultEnabled: defaultEnabled,
            roots: [.absolute(cacheURL.path)],
            scanMode: .children,
            trasher: trasher
        )
        return try await category.scan(context)
    }

    public func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        try await CleanDriveReclaimer.reclaim(items, mode: mode, trasher: trasher)
    }

    private func cacheDirectory() throws -> URL? {
        for path in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] {
            let executable = URL(fileURLWithPath: path)
            guard FileManager.default.isExecutableFile(atPath: executable.path) else {
                continue
            }
            let output = try commandRunner.output(executable: executable, arguments: ["--cache"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty else {
                continue
            }
            return URL(fileURLWithPath: output)
        }
        return nil
    }
}
