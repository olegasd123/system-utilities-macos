import Foundation

public struct TrashCategory: ReclaimableCategory {
    public let id: CleanDriveCategoryID = .trash
    public let displayName = "Trash"
    public let symbolName = "trash"
    public let requiresFullDiskAccess = true
    public let defaultEnabled = false

    private let trasher: any CleanDriveTrashing

    public init(trasher: any CleanDriveTrashing = SystemTrash()) {
        self.trasher = trasher
    }

    public func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        let roots = trashRoots(context: context)
        let category = PathCleanDriveCategory(
            id: id,
            displayName: displayName,
            symbolName: symbolName,
            requiresFullDiskAccess: requiresFullDiskAccess,
            defaultEnabled: defaultEnabled,
            roots: roots.map { .absolute($0.path) },
            scanMode: .children,
            trasher: trasher
        )
        let result = try await category.scan(context)
        return CleanDriveScanResult(
            items: result.items.filter { !isTrashMetadata($0.url) },
            notes: result.notes
        )
    }

    public func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        try await CleanDriveReclaimer.reclaim(items, mode: mode, trasher: trasher)
    }

    private func trashRoots(context: CleanDriveScanContext) -> [URL] {
        var roots = [
            context.homeDirectory.appendingPathComponent(".Trash", isDirectory: true)
        ]

        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard
            let volumes = try? FileManager.default.contentsOfDirectory(
                at: volumesURL,
                includingPropertiesForKeys: nil
            )
        else {
            return roots
        }

        let userID = String(context.userID)
        roots += volumes.map {
            $0.appendingPathComponent(".Trashes", isDirectory: true)
                .appendingPathComponent(userID, isDirectory: true)
        }
        return roots
    }

    private func isTrashMetadata(_ url: URL) -> Bool {
        url.lastPathComponent == ".DS_Store"
    }
}
