import AppCore
import Foundation

public struct CleanDriveSettings: FeatureSettings {
    public static let featureId = "clean-drive"

    public var categories: [CleanDriveCategoryID: CleanDriveCategorySettings]
    public var customFolders: [CleanDriveCustomFolder]
    public var reminders: CleanDriveReminderSettings
    public var reclaim: CleanDriveReclaimSettings
    public var lastReminderAt: Date?

    public init(
        categories: [CleanDriveCategoryID: CleanDriveCategorySettings],
        customFolders: [CleanDriveCustomFolder] = [],
        reminders: CleanDriveReminderSettings,
        reclaim: CleanDriveReclaimSettings,
        lastReminderAt: Date? = nil
    ) {
        self.categories = categories
        self.customFolders = customFolders
        self.reminders = reminders
        self.reclaim = reclaim
        self.lastReminderAt = lastReminderAt
    }

    public static let defaultValue = CleanDriveSettings(
        categories: [
            .userCaches: CleanDriveCategorySettings(enabled: true),
            .userLogs: CleanDriveCategorySettings(enabled: true),
            .trash: CleanDriveCategorySettings(enabled: false),
            .browserCaches: CleanDriveCategorySettings(enabled: false),
            .mailCache: CleanDriveCategorySettings(enabled: false),
            .downloadsOld: CleanDriveCategorySettings(enabled: false),
            .softwareUpdates: CleanDriveCategorySettings(enabled: false),
            .customFolders: CleanDriveCategorySettings(enabled: false),
            .homebrewCache: CleanDriveCategorySettings(enabled: true),
            .xcodeDerived: CleanDriveCategorySettings(enabled: true),
            .xcodeArchives: CleanDriveCategorySettings(enabled: false),
            .xcodeDeviceSupport: CleanDriveCategorySettings(enabled: false),
            .xcodeSimulators: CleanDriveCategorySettings(enabled: false)
        ],
        reminders: .defaultValue,
        reclaim: .defaultValue
    )

    enum CodingKeys: String, CodingKey {
        case categories
        case customFolders = "custom_folders"
        case reminders
        case reclaim
        case lastReminderAt = "last_reminder_at"
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaultValue
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rawCategories = try container.decodeIfPresent(
            [String: CleanDriveCategorySettings].self,
            forKey: .categories
        ) {
            var mergedCategories = defaults.categories
            for (id, settings) in rawCategories {
                mergedCategories[CleanDriveCategoryID(rawValue: id)] = settings
            }
            categories = mergedCategories
        } else {
            categories = defaults.categories
        }
        customFolders = try container.decodeIfPresent(
            [CleanDriveCustomFolder].self,
            forKey: .customFolders
        ) ?? defaults.customFolders
        reminders = try container.decodeIfPresent(
            CleanDriveReminderSettings.self,
            forKey: .reminders
        ) ?? defaults.reminders
        reclaim = try container.decodeIfPresent(
            CleanDriveReclaimSettings.self,
            forKey: .reclaim
        ) ?? defaults.reclaim
        lastReminderAt = try container.decodeIfPresent(Date.self, forKey: .lastReminderAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawCategories = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.key.rawValue, $0.value) }
        )
        try container.encode(rawCategories, forKey: .categories)
        try container.encode(customFolders, forKey: .customFolders)
        try container.encode(reminders, forKey: .reminders)
        try container.encode(reclaim, forKey: .reclaim)
        try container.encodeIfPresent(lastReminderAt, forKey: .lastReminderAt)
    }

    public func isCategoryEnabled(_ id: CleanDriveCategoryID, defaultEnabled: Bool) -> Bool {
        categories[id]?.enabled ?? defaultEnabled
    }

    public mutating func setCategoryEnabled(
        _ enabled: Bool,
        id: CleanDriveCategoryID
    ) {
        categories[id] = CleanDriveCategorySettings(enabled: enabled)
    }
}

public struct CleanDriveCustomFolder: Codable, Equatable, Identifiable, Sendable {
    public var path: String
    public var id: String { path }

    public init(path: String) {
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
    }

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public static func canUse(
        _ url: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        CleanDrivePathSafety.canUseCustomFolder(url, homeDirectory: homeDirectory)
    }
}

public struct CleanDriveCategorySettings: Codable, Equatable, Sendable {
    public var enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

public struct CleanDriveReminderSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var thresholdBytes: UInt64
    public var minHoursBetweenReminders: Int

    public init(
        enabled: Bool,
        thresholdBytes: UInt64,
        minHoursBetweenReminders: Int
    ) {
        self.enabled = enabled
        self.thresholdBytes = thresholdBytes
        self.minHoursBetweenReminders = minHoursBetweenReminders
    }

    public static let defaultValue = CleanDriveReminderSettings(
        enabled: true,
        thresholdBytes: 5 * 1_024 * 1_024 * 1_024,
        minHoursBetweenReminders: 24
    )

    enum CodingKeys: String, CodingKey {
        case enabled
        case thresholdBytes = "threshold_bytes"
        case minHoursBetweenReminders = "min_hours_between_reminders"
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaultValue
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        thresholdBytes = try container.decodeIfPresent(
            UInt64.self,
            forKey: .thresholdBytes
        ) ?? defaults.thresholdBytes
        minHoursBetweenReminders = try container.decodeIfPresent(
            Int.self,
            forKey: .minHoursBetweenReminders
        ) ?? defaults.minHoursBetweenReminders
    }
}

public struct CleanDriveReclaimSettings: Codable, Equatable, Sendable {
    public var permanentlyDelete: Bool
    public var downloadsOlderThanDays: Int
    public var xcodeArchivesOlderThanDays: Int

    public init(
        permanentlyDelete: Bool,
        downloadsOlderThanDays: Int,
        xcodeArchivesOlderThanDays: Int
    ) {
        self.permanentlyDelete = permanentlyDelete
        self.downloadsOlderThanDays = downloadsOlderThanDays
        self.xcodeArchivesOlderThanDays = xcodeArchivesOlderThanDays
    }

    public static let defaultValue = CleanDriveReclaimSettings(
        permanentlyDelete: false,
        downloadsOlderThanDays: 30,
        xcodeArchivesOlderThanDays: 60
    )

    enum CodingKeys: String, CodingKey {
        case permanentlyDelete = "permanently_delete"
        case downloadsOlderThanDays = "downloads_older_than_days"
        case xcodeArchivesOlderThanDays = "xcode_archives_older_than_days"
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaultValue
        let container = try decoder.container(keyedBy: CodingKeys.self)
        permanentlyDelete = try container.decodeIfPresent(
            Bool.self,
            forKey: .permanentlyDelete
        ) ?? defaults.permanentlyDelete
        downloadsOlderThanDays = try container.decodeIfPresent(
            Int.self,
            forKey: .downloadsOlderThanDays
        ) ?? defaults.downloadsOlderThanDays
        xcodeArchivesOlderThanDays = try container.decodeIfPresent(
            Int.self,
            forKey: .xcodeArchivesOlderThanDays
        ) ?? defaults.xcodeArchivesOlderThanDays
    }
}
