import Foundation

public enum CleanDriveCategoryCatalog {
    public static func defaultCategories(
        trasher: any CleanDriveTrashing = SystemTrash()
    ) -> [any ReclaimableCategory] {
        [
            UserCachesCategory(trasher: trasher),
            PathCleanDriveCategory(
                id: .userLogs,
                displayName: "Log files",
                symbolName: "doc.text",
                requiresFullDiskAccess: false,
                defaultEnabled: true,
                roots: [
                    .home(["Library", "Logs"]),
                    .absolute("/private/var/log")
                ],
                scanMode: .children,
                trasher: trasher
            ),
            TrashCategory(trasher: trasher),
            PathCleanDriveCategory(
                id: .xcodeDerived,
                displayName: "Xcode derived data",
                symbolName: "hammer",
                requiresFullDiskAccess: false,
                defaultEnabled: true,
                roots: [.home(["Library", "Developer", "Xcode", "DerivedData"])],
                scanMode: .children,
                trasher: trasher
            ),
            PathCleanDriveCategory(
                id: .xcodeArchives,
                displayName: "Xcode archives (old)",
                symbolName: "archivebox",
                requiresFullDiskAccess: false,
                defaultEnabled: false,
                roots: [.home(["Library", "Developer", "Xcode", "Archives"])],
                scanMode: .xcodeArchives,
                trasher: trasher
            ),
            PathCleanDriveCategory(
                id: .xcodeDeviceSupport,
                displayName: "Xcode device support",
                symbolName: "iphone",
                requiresFullDiskAccess: false,
                defaultEnabled: false,
                roots: [
                    .home(["Library", "Developer", "Xcode", "iOS DeviceSupport"]),
                    .home(["Library", "Developer", "Xcode", "watchOS DeviceSupport"]),
                    .home(["Library", "Developer", "Xcode", "tvOS DeviceSupport"]),
                    .home(["Library", "Developer", "Xcode", "visionOS DeviceSupport"])
                ],
                scanMode: .children,
                trasher: trasher
            ),
            UnavailableSimulatorsCategory(trasher: trasher),
            HomebrewCacheCategory(trasher: trasher),
            PathCleanDriveCategory(
                id: .browserCaches,
                displayName: "Browser caches",
                symbolName: "globe",
                requiresFullDiskAccess: true,
                defaultEnabled: false,
                roots: [
                    .home(["Library", "Containers", "com.apple.Safari", "Data", "Library", "Caches"]),
                    .home(["Library", "Caches", "Google", "Chrome"]),
                    .home(["Library", "Caches", "Company The Browser Company", "Arc"]),
                    .home(["Library", "Caches", "Firefox", "Profiles"])
                ],
                scanMode: .root,
                trasher: trasher
            ),
            PathCleanDriveCategory(
                id: .mailCache,
                displayName: "Mail cache",
                symbolName: "envelope",
                requiresFullDiskAccess: true,
                defaultEnabled: false,
                roots: [
                    .home(["Library", "Containers", "com.apple.mail", "Data", "Library", "Mail Downloads"])
                ],
                scanMode: .children,
                trasher: trasher
            ),
            PathCleanDriveCategory(
                id: .downloadsOld,
                displayName: "Downloads (old)",
                symbolName: "arrow.down.circle",
                requiresFullDiskAccess: false,
                defaultEnabled: false,
                roots: [.home(["Downloads"])],
                scanMode: .downloadsOlderThanDays,
                trasher: trasher
            ),
            PathCleanDriveCategory(
                id: .softwareUpdates,
                displayName: "Old updates",
                symbolName: "arrow.triangle.2.circlepath",
                requiresFullDiskAccess: false,
                defaultEnabled: false,
                roots: [
                    .absolute("/Library/Updates"),
                    .home(["Library", "Application Support", "SoftwareUpdate"])
                ],
                scanMode: .root,
                trasher: trasher
            )
        ]
    }
}
