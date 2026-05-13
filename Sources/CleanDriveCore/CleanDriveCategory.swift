import Foundation
import Darwin
import AppCore

public struct CleanDriveCategoryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension CleanDriveCategoryID {
    public static let userCaches = CleanDriveCategoryID(rawValue: "user-caches")
    public static let userLogs = CleanDriveCategoryID(rawValue: "user-logs")
    public static let trash = CleanDriveCategoryID(rawValue: "trash")
    public static let xcodeDerived = CleanDriveCategoryID(rawValue: "xcode-derived")
    public static let xcodeArchives = CleanDriveCategoryID(rawValue: "xcode-archives")
    public static let xcodeDeviceSupport = CleanDriveCategoryID(rawValue: "xcode-device-support")
    public static let xcodeSimulators = CleanDriveCategoryID(rawValue: "xcode-simulators")
    public static let homebrewCache = CleanDriveCategoryID(rawValue: "homebrew-cache")
    public static let browserCaches = CleanDriveCategoryID(rawValue: "browser-caches")
    public static let mailCache = CleanDriveCategoryID(rawValue: "mail-cache")
    public static let downloadsOld = CleanDriveCategoryID(rawValue: "downloads-old")
    public static let softwareUpdates = CleanDriveCategoryID(rawValue: "software-updates")
    public static let customFolders = CleanDriveCategoryID(rawValue: "custom-folders")
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
    public var userID: Int
    public var downloadsOlderThanDays: Int
    public var xcodeArchivesOlderThanDays: Int
    public var customFolderURLs: [URL]

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        userID: Int = Int(getuid()),
        downloadsOlderThanDays: Int = 30,
        xcodeArchivesOlderThanDays: Int = 60,
        customFolderURLs: [URL] = []
    ) {
        self.homeDirectory = homeDirectory
        self.userID = userID
        self.downloadsOlderThanDays = downloadsOlderThanDays
        self.xcodeArchivesOlderThanDays = xcodeArchivesOlderThanDays
        self.customFolderURLs = customFolderURLs
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

public struct CleanDriveItem: Identifiable, Equatable, Sendable, FileReclaimItem {
    public typealias Kind = FileReclaimKind
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
