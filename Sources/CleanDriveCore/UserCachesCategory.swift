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
            includingPropertiesForKeys: CleanDriveSizeReader.defaultResourceKeys,
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
        try await CleanDriveReclaimer.reclaim(items, mode: mode, trasher: trasher)
    }

    public static var defaultBlockedBundleIDs: Set<String> {
        guard
            let url = dangerousCacheBundleIDsURL,
            let data = try? Data(contentsOf: url),
            let values = try? JSONDecoder().decode([String].self, from: data)
        else {
            return fallbackBlockedBundleIDs
        }
        return Set(values)
    }

    private static var dangerousCacheBundleIDsURL: URL? {
        if let url = Bundle.main.url(
            forResource: "dangerous-cache-bundle-ids",
            withExtension: "json"
        ) {
            return url
        }

        guard !Bundle.main.isPackagedApp else {
            return nil
        }

        return Bundle.module.url(
            forResource: "dangerous-cache-bundle-ids",
            withExtension: "json"
        )
    }

    private static let fallbackBlockedBundleIDs: Set<String> = [
        "com.apple.AddressBook",
        "com.apple.Photos",
        "com.apple.Safari"
    ]
}

private extension Bundle {
    var isPackagedApp: Bool {
        bundleURL.pathExtension == "app"
    }
}
