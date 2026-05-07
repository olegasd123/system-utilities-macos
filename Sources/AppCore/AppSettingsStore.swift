import Foundation

public struct AppSettingsStore: Sendable {
    public static let standard = AppSettingsStore()

    private let bundleId: String

    public init(bundleId: String = "dev.olegoleg.system-monitor") {
        self.bundleId = bundleId
    }

    public func load() -> RawAppSettingsLoadResult {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return RawAppSettingsLoadResult(value: .defaultValue, loadedFromDisk: false)
        }

        if let raw = decodeV2(json) {
            return RawAppSettingsLoadResult(value: raw, loadedFromDisk: true)
        }
        if let raw = decodeNamedFeatures(json) {
            return RawAppSettingsLoadResult(value: raw, loadedFromDisk: true)
        }
        if let raw = decodeFlatLegacy(json) {
            return RawAppSettingsLoadResult(value: raw, loadedFromDisk: true)
        }
        if
            let envelope = json["settings"] as? [String: Any],
            let raw = decodeFlatLegacy(envelope)
        {
            return RawAppSettingsLoadResult(value: raw, loadedFromDisk: true)
        }
        return RawAppSettingsLoadResult(value: .defaultValue, loadedFromDisk: false)
    }

    public func save(_ raw: RawAppSettings) throws {
        let directory = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        var top: [String: Any] = ["version": 2]
        top["general"] = try jsonObject(from: raw.general)

        var featuresDict: [String: Any] = [:]
        for (id, data) in raw.features {
            if let object = try? JSONSerialization.jsonObject(with: data) {
                featuresDict[id] = object
            }
        }
        top["features"] = featuresDict

        let data = try JSONSerialization.data(
            withJSONObject: top,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: settingsURL, options: .atomic)
    }

    private func decodeV2(_ json: [String: Any]) -> RawAppSettings? {
        guard
            let version = json["version"] as? Int,
            version >= 2,
            let generalObject = json["general"]
        else {
            return nil
        }

        let general = (try? typedValue(GeneralSettings.self, from: generalObject))
            ?? .defaultValue

        var features: [String: Data] = [:]
        if let featuresObject = json["features"] as? [String: Any] {
            for (id, value) in featuresObject {
                if let data = try? JSONSerialization.data(withJSONObject: value) {
                    features[id] = data
                }
            }
        }
        return RawAppSettings(general: general, features: features)
    }

    private func decodeNamedFeatures(_ json: [String: Any]) -> RawAppSettings? {
        guard
            let generalObject = json["general"],
            let general = try? typedValue(GeneralSettings.self, from: generalObject)
        else {
            return nil
        }

        var features: [String: Data] = [:]
        if
            let smObject = json["system_monitor"],
            let data = try? JSONSerialization.data(withJSONObject: smObject)
        {
            features[Self.systemMonitorFeatureId] = data
        }
        return RawAppSettings(general: general, features: features)
    }

    private func decodeFlatLegacy(_ json: [String: Any]) -> RawAppSettings? {
        let systemMonitorKeys: Set<String> = [
            "menu_bar",
            "network_units",
            "network_display",
            "warning_thresholds",
            "warnings_enabled"
        ]
        let smObject: [String: Any] = json.filter { systemMonitorKeys.contains($0.key) }
        guard !smObject.isEmpty else {
            return nil
        }

        var generalObject: [String: Any] = [:]
        if let value = json["temperature_unit"] {
            generalObject["temperature_unit"] = value
        }
        if let value = json["launch_at_login"] {
            generalObject["launch_at_login"] = value
        }
        let general = (try? typedValue(GeneralSettings.self, from: generalObject))
            ?? .defaultValue

        var features: [String: Data] = [:]
        if let data = try? JSONSerialization.data(withJSONObject: smObject) {
            features[Self.systemMonitorFeatureId] = data
        }
        return RawAppSettings(general: general, features: features)
    }

    private func typedValue<T: Decodable>(_ type: T.Type, from object: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func jsonObject<T: Encodable>(from value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private var settingsURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private static let systemMonitorFeatureId = "system-monitor"
}
