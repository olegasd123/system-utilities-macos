import Foundation

public struct CustomFoldersCategory: ReclaimableCategory {
    public let id = CleanDriveCategoryID.customFolders
    public let displayName = "Custom folders"
    public let symbolName = "folder.badge.gearshape"
    public let requiresFullDiskAccess = false
    public let defaultEnabled = false

    private let trasher: any CleanDriveTrashing

    public init(trasher: any CleanDriveTrashing = SystemTrash()) {
        self.trasher = trasher
    }

    public func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        var items: [CleanDriveItem] = []
        var notes: [String] = []

        for folder in context.customFolderURLs.map(\.standardizedFileURL) {
            try Task.checkCancellation()
            guard CleanDrivePathSafety.canUseCustomFolder(
                folder,
                homeDirectory: context.homeDirectory
            ) else {
                notes.append("Skipped \(folder.lastPathComponent): this folder is protected.")
                continue
            }
            guard FileManager.default.fileExists(atPath: folder.path) else {
                notes.append("Skipped \(folder.lastPathComponent): folder was not found.")
                continue
            }
            guard isDirectory(folder) else {
                notes.append("Skipped \(folder.lastPathComponent): this is not a folder.")
                continue
            }

            do {
                items += try scanChildren(of: folder)
            } catch {
                notes.append("Skipped \(folder.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return CleanDriveScanResult(
            items: items
                .filter { CleanDrivePathSafety.canReclaim($0.url) }
                .sorted { $0.size > $1.size },
            notes: notes
        )
    }

    public func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        try await CleanDriveReclaimer.reclaim(
            items.filter { CleanDrivePathSafety.canReclaim($0.url) },
            mode: mode,
            trasher: trasher
        )
    }

    private func scanChildren(of folder: URL) throws -> [CleanDriveItem] {
        let children = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: CleanDriveSizeReader.defaultResourceKeys,
            options: []
        )
        var items: [CleanDriveItem] = []
        for child in children {
            try Task.checkCancellation()
            if let item = try item(for: child) {
                items.append(item)
            }
        }
        return items
    }

    private func item(for url: URL) throws -> CleanDriveItem? {
        guard let kind = try CleanDriveSizeReader.itemKind(at: url) else {
            return nil
        }
        let size: UInt64
        switch kind {
        case .file:
            size = try CleanDriveSizeReader.allocatedSize(of: url)
        case .directory:
            size = try CleanDriveSizeReader.recursiveAllocatedSize(of: url)
        }
        return CleanDriveItem(url: url, size: size, kind: kind)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
