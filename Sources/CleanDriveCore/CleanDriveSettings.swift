import AppCore
import Foundation

public struct CleanDriveSettings: FeatureSettings {
    public static let featureId = "clean-drive"

    public init() {}

    public static var defaultValue: CleanDriveSettings {
        CleanDriveSettings()
    }
}
