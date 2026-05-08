import Foundation

public struct RawAppSettings: Equatable, Sendable {
    public var general: GeneralSettings
    public var features: [String: Data]

    public init(general: GeneralSettings, features: [String: Data]) {
        self.general = general
        self.features = features
    }

    public static var defaultValue: RawAppSettings {
        RawAppSettings(general: .defaultValue, features: [:])
    }

    public func value<T: FeatureSettings>(for type: T.Type) -> T {
        guard
            let data = features[T.featureId],
            let decoded = try? JSONDecoder().decode(T.self, from: data)
        else {
            return T.defaultValue
        }
        return decoded
    }

    public mutating func setValue<T: FeatureSettings>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        features[T.featureId] = data
    }
}

public struct RawAppSettingsLoadResult: Equatable, Sendable {
    public let value: RawAppSettings
    public let loadedFromDisk: Bool

    public init(value: RawAppSettings, loadedFromDisk: Bool) {
        self.value = value
        self.loadedFromDisk = loadedFromDisk
    }
}
