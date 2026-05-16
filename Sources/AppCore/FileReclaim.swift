import Foundation

public protocol FileReclaimItem {
    var url: URL { get }
    var size: UInt64 { get }
}

public protocol FileTrashing: Sendable {
    func trashItem(at url: URL) throws
}

public struct SystemTrash: FileTrashing {
    public init() {}

    public func trashItem(at url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(
            at: url,
            resultingItemURL: &resultingURL
        )
    }
}

public struct DirectoryTrash: FileTrashing {
    private let trashDirectory: URL

    public init(trashDirectory: URL) {
        self.trashDirectory = trashDirectory
    }

    public func trashItem(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: trashDirectory,
            withIntermediateDirectories: true
        )
        let destination = uniqueDestination(for: url)
        try FileManager.default.moveItem(at: url, to: destination)
    }

    private func uniqueDestination(for url: URL) -> URL {
        let base = trashDirectory.appendingPathComponent(url.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: base.path) else {
            return uniqueNumberedDestination(for: url)
        }
        return base
    }

    private func uniqueNumberedDestination(for url: URL) -> URL {
        let name = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        var index = 1
        while true {
            let fileName = pathExtension.isEmpty
                ? "\(name) \(index)"
                : "\(name) \(index).\(pathExtension)"
            let candidate = trashDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}

public enum FileReclaimKind: String, Codable, Sendable {
    case file
    case directory
}

public enum ReclaimMode: String, CaseIterable, Codable, Hashable, Sendable {
    case moveToTrash
    case hardDelete
}

public struct ReclaimReport: Equatable, Sendable {
    public var bytesReclaimed: UInt64
    public var reclaimedItemCount: Int
    public var failures: [ReclaimFailure]

    public init(
        bytesReclaimed: UInt64 = 0,
        reclaimedItemCount: Int = 0,
        failures: [ReclaimFailure] = []
    ) {
        self.bytesReclaimed = bytesReclaimed
        self.reclaimedItemCount = reclaimedItemCount
        self.failures = failures
    }
}

public struct ReclaimFailure: Equatable, Sendable {
    public var path: String
    public var reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public enum FileSizeReader {
    public static let defaultResourceKeys: [URLResourceKey] = [
        .fileAllocatedSizeKey,
        .fileSizeKey,
        .isDirectoryKey,
        .isPackageKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .totalFileSizeKey,
        .totalFileAllocatedSizeKey
    ]

    public static func allocatedSize(of url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ])
        let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
        return UInt64(max(size, 0))
    }

    public static func logicalSize(of url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .totalFileSizeKey
        ])
        let size = values.totalFileSize ?? values.fileSize ?? 0
        return UInt64(max(size, 0))
    }

    public static func itemKind(at url: URL) throws -> FileReclaimKind? {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ])
        if values.isSymbolicLink == true {
            return nil
        }
        if values.isDirectory == true {
            return .directory
        }
        if values.isRegularFile == true {
            return .file
        }
        return nil
    }

    public static func recursiveAllocatedSize(of directory: URL) throws -> UInt64 {
        try allocatedSize(of: directory) + recursiveChildrenSize(of: directory)
    }

    public static func recursiveLogicalSize(of directory: URL) throws -> UInt64 {
        try logicalSize(of: directory) + recursiveLogicalChildrenSize(of: directory)
    }

    private static func recursiveChildrenSize(of directory: URL) throws -> UInt64 {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: defaultResourceKeys,
            options: []
        )

        var total: UInt64 = 0
        for child in children {
            try Task.checkCancellation()
            guard let kind = try itemKind(at: child) else {
                continue
            }

            switch kind {
            case .file:
                total += try allocatedSize(of: child)
            case .directory:
                let values = try child.resourceValues(forKeys: [.isPackageKey])
                if values.isPackage == true {
                    total += try allocatedSize(of: child)
                } else {
                    total += try recursiveAllocatedSize(of: child)
                }
            }
        }
        return total
    }

    private static func recursiveLogicalChildrenSize(of directory: URL) throws -> UInt64 {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: defaultResourceKeys,
            options: []
        )

        var total: UInt64 = 0
        for child in children {
            try Task.checkCancellation()
            guard let kind = try itemKind(at: child) else {
                continue
            }

            switch kind {
            case .file:
                total += try logicalSize(of: child)
            case .directory:
                total += try recursiveLogicalSize(of: child)
            }
        }
        return total
    }
}

public enum FileReclaimer {
    public static func reclaim(
        _ items: [any FileReclaimItem],
        mode: ReclaimMode,
        trasher: any FileTrashing
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
}
