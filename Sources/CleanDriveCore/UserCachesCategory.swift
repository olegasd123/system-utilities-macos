import Foundation

public struct UserCachesCategory: ReclaimableCategory {
    public let id: CleanDriveCategoryID = .userCaches
    public let displayName = "User caches"
    public let symbolName = "folder"
    public let requiresFullDiskAccess = false
    public let defaultEnabled = true

    private let blockedBundleIDs: Set<String>
    private let trasher: any CleanDriveTrashing

    public init(
        blockedBundleIDs: Set<String> = UserCachesCategory.defaultBlockedBundleIDs,
        trasher: any CleanDriveTrashing = SystemTrash()
    ) {
        self.blockedBundleIDs = blockedBundleIDs
        self.trasher = trasher
    }

    public func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        let cacheDirectory = context.homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)

        guard FileManager.default.fileExists(atPath: cacheDirectory.path) else {
            return CleanDriveScanResult(items: [])
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [
                .fileAllocatedSizeKey,
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .totalFileAllocatedSizeKey
            ],
            options: [.skipsHiddenFiles]
        )

        var items: [CleanDriveItem] = []
        var notes: [String] = []
        for child in children where !blockedBundleIDs.contains(child.lastPathComponent) {
            try Task.checkCancellation()
            do {
                guard let kind = try CleanDriveSizeReader.itemKind(at: child) else {
                    continue
                }
                let size: UInt64
                switch kind {
                case .file:
                    size = try CleanDriveSizeReader.allocatedSize(of: child)
                case .directory:
                    size = try CleanDriveSizeReader.recursiveAllocatedSize(of: child)
                }
                items.append(CleanDriveItem(url: child, size: size, kind: kind))
            } catch {
                notes.append("Skipped \(child.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return CleanDriveScanResult(
            items: items.sorted { $0.size > $1.size },
            notes: notes
        )
    }

    public func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        var report = ReclaimReport()
        for item in items {
            try Task.checkCancellation()
            do {
                switch mode {
                case .moveToTrash:
                    try trasher.trashItem(at: item.url)
                case .hardDelete:
                    try FileManager.default.removeItem(at: item.url)
                }
                report.bytesReclaimed += item.size
                report.reclaimedItemCount += 1
            } catch {
                report.failures.append(
                    ReclaimFailure(
                        path: item.url.path,
                        reason: error.localizedDescription
                    )
                )
            }
        }
        return report
    }

    public static var defaultBlockedBundleIDs: Set<String> {
        guard
            let url = Bundle.module.url(
                forResource: "dangerous-cache-bundle-ids",
                withExtension: "json"
            ),
            let data = try? Data(contentsOf: url),
            let values = try? JSONDecoder().decode([String].self, from: data)
        else {
            return fallbackBlockedBundleIDs
        }
        return Set(values)
    }

    private static let fallbackBlockedBundleIDs: Set<String> = [
        "com.apple.AddressBook",
        "com.apple.Photos",
        "com.apple.Safari"
    ]
}
