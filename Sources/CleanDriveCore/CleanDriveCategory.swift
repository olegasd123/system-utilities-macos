import Foundation

public struct CleanDriveCategoryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension CleanDriveCategoryID {
    public static let userCaches = CleanDriveCategoryID(rawValue: "user-caches")
}

public protocol CleanDriveCategory: Sendable {
    var id: CleanDriveCategoryID { get }
    var displayName: String { get }
    var symbolName: String { get }
    var requiresFullDiskAccess: Bool { get }
    var defaultEnabled: Bool { get }

    func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult
}

public protocol ReclaimableCategory: CleanDriveCategory {
    func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport
}

public struct CleanDriveScanContext: Sendable {
    public var homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }
}

public struct CleanDriveScanResult: Equatable, Sendable {
    public var items: [CleanDriveItem]
    public var notes: [String]

    public init(items: [CleanDriveItem], notes: [String] = []) {
        self.items = items
        self.notes = notes
    }

    public var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.size }
    }
}

public struct CleanDriveItem: Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case file
        case directory
    }

    public var id: String { url.path }
    public var url: URL
    public var size: UInt64
    public var kind: Kind

    public init(url: URL, size: UInt64, kind: Kind) {
        self.url = url
        self.size = size
        self.kind = kind
    }
}

public enum ReclaimMode: Sendable {
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
