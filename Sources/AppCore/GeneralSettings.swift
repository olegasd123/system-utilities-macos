import Foundation

public struct GeneralSettings: Codable, Equatable, Sendable {
    public var temperatureUnit: TemperatureUnit
    public var launchAtLogin: Bool
    public var language: AppLanguage

    public init(
        temperatureUnit: TemperatureUnit,
        launchAtLogin: Bool,
        language: AppLanguage = .system
    ) {
        self.temperatureUnit = temperatureUnit
        self.launchAtLogin = launchAtLogin
        self.language = language
    }

    public static var defaultValue: GeneralSettings {
        GeneralSettings(
            temperatureUnit: TemperatureUnit.systemPreferred,
            launchAtLogin: true,
            language: .system
        )
    }

    public enum CodingKeys: String, CodingKey {
        case temperatureUnit = "temperature_unit"
        case launchAtLogin = "launch_at_login"
        case language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.temperatureUnit = try container.decodeIfPresent(
            TemperatureUnit.self,
            forKey: .temperatureUnit
        ) ?? TemperatureUnit.systemPreferred
        self.launchAtLogin = try container.decodeIfPresent(
            Bool.self,
            forKey: .launchAtLogin
        ) ?? true
        self.language = try container.decodeIfPresent(
            AppLanguage.self,
            forKey: .language
        ) ?? .system
    }
}

public enum TemperatureUnit: String, Codable, CaseIterable, Sendable {
    case celsius
    case fahrenheit

    public static var systemPreferred: TemperatureUnit {
        if let rawUnit = UserDefaults.standard
            .string(forKey: "AppleTemperatureUnit")?
            .lowercased()
        {
            if rawUnit.hasPrefix("f") {
                return .fahrenheit
            }

            if rawUnit.hasPrefix("c") {
                return .celsius
            }
        }

        return Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
    }
}
