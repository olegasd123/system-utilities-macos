import AppCore
import Foundation

public struct AppUninstallerSettings: FeatureSettings {
    public static let featureId = "app-uninstaller"

    public var includeNameHeuristicMatches: Bool
    public var includeSystemLibraryPaths: Bool
    public var defaultReclaimMode: ReclaimMode

    public init(
        includeNameHeuristicMatches: Bool,
        includeSystemLibraryPaths: Bool,
        defaultReclaimMode: ReclaimMode
    ) {
        self.includeNameHeuristicMatches = includeNameHeuristicMatches
        self.includeSystemLibraryPaths = includeSystemLibraryPaths
        self.defaultReclaimMode = defaultReclaimMode
    }

    public static let defaultValue = AppUninstallerSettings(
        includeNameHeuristicMatches: false,
        includeSystemLibraryPaths: true,
        defaultReclaimMode: .moveToTrash
    )

    enum CodingKeys: String, CodingKey {
        case includeNameHeuristicMatches = "include_name_heuristic_matches"
        case includeSystemLibraryPaths = "include_system_library_paths"
        case defaultReclaimMode = "default_reclaim_mode"
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaultValue
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeNameHeuristicMatches = try container.decodeIfPresent(
            Bool.self,
            forKey: .includeNameHeuristicMatches
        ) ?? defaults.includeNameHeuristicMatches
        includeSystemLibraryPaths = try container.decodeIfPresent(
            Bool.self,
            forKey: .includeSystemLibraryPaths
        ) ?? defaults.includeSystemLibraryPaths
        defaultReclaimMode = try container.decodeIfPresent(
            ReclaimMode.self,
            forKey: .defaultReclaimMode
        ) ?? defaults.defaultReclaimMode
    }
}
