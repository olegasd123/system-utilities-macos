import Foundation

public enum CleanDrivePathRoot: Sendable {
    case home([String])
    case absolute(String)

    func url(in context: CleanDriveScanContext) -> URL {
        switch self {
        case .home(let components):
            return components.reduce(context.homeDirectory) { partial, component in
                partial.appendingPathComponent(component, isDirectory: true)
            }
        case .absolute(let path):
            return URL(fileURLWithPath: path)
        }
    }
}

public enum CleanDrivePathScanMode: Sendable {
    case children
    case root
    case childrenOlderThanDays(Int)
    case xcodeArchives
}

public struct PathCleanDriveCategory: ReclaimableCategory {
    public let id: CleanDriveCategoryID
    public let displayName: String
    public let symbolName: String
    public let requiresFullDiskAccess: Bool
    public let defaultEnabled: Bool

    private let roots: [CleanDrivePathRoot]
    private let scanMode: CleanDrivePathScanMode
    private let trasher: any CleanDriveTrashing

    public init(
        id: CleanDriveCategoryID,
        displayName: String,
        symbolName: String,
        requiresFullDiskAccess: Bool,
        defaultEnabled: Bool,
        roots: [CleanDrivePathRoot],
        scanMode: CleanDrivePathScanMode,
        trasher: any CleanDriveTrashing = SystemTrash()
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.requiresFullDiskAccess = requiresFullDiskAccess
        self.defaultEnabled = defaultEnabled
        self.roots = roots
        self.scanMode = scanMode
        self.trasher = trasher
    }

    public func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        var items: [CleanDriveItem] = []
        var notes: [String] = []

        for root in roots.map({ $0.url(in: context) }) where CleanDrivePathSafety.canScan(root) {
            try Task.checkCancellation()
            guard FileManager.default.fileExists(atPath: root.path) else {
                continue
            }

            do {
                items += try scanRoot(root, context: context)
            } catch {
                if CleanDriveErrorClassifier.isPermissionDenied(error), requiresFullDiskAccess {
                    throw CleanDrivePermissionDeniedError(path: root.path)
                }
                notes.append("Skipped \(root.lastPathComponent): \(error.localizedDescription)")
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

    private func scanRoot(
        _ root: URL,
        context: CleanDriveScanContext
    ) throws -> [CleanDriveItem] {
        switch scanMode {
        case .children:
            return try scanChildren(of: root)
        case .root:
            return try item(for: root).map { [$0] } ?? []
        case .childrenOlderThanDays(let days):
            return try scanChildren(of: root).filter { isOlder($0.url, thanDays: days) }
        case .xcodeArchives:
            return try scanXcodeArchives(root, olderThanDays: context.xcodeArchivesOlderThanDays)
        }
    }

    private func scanChildren(of root: URL) throws -> [CleanDriveItem] {
        let children = try FileManager.default.contentsOfDirectory(
            at: root,
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

    private func scanXcodeArchives(
        _ root: URL,
        olderThanDays days: Int
    ) throws -> [CleanDriveItem] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: CleanDriveSizeReader.defaultResourceKeys + [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        else {
            return []
        }

        var items: [CleanDriveItem] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            guard url.pathExtension == "xcarchive", isOlder(url, thanDays: days) else {
                continue
            }
            if let item = try item(for: url) {
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

    private func isOlder(_ url: URL, thanDays days: Int) -> Bool {
        guard days > 0 else {
            return true
        }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = values?.contentModificationDate else {
            return false
        }
        let threshold = Date().addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        return date < threshold
    }
}
