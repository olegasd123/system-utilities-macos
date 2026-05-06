import Foundation

public struct GeneralSettings: Codable, Equatable, Sendable {
    public var temperatureUnit: TemperatureUnit
    public var launchAtLogin: Bool

    public init(temperatureUnit: TemperatureUnit, launchAtLogin: Bool) {
        self.temperatureUnit = temperatureUnit
        self.launchAtLogin = launchAtLogin
    }

    public static var defaultValue: GeneralSettings {
        GeneralSettings(
            temperatureUnit: TemperatureUnit.systemPreferred,
            launchAtLogin: true
        )
    }

    public enum CodingKeys: String, CodingKey {
        case temperatureUnit = "temperature_unit"
        case launchAtLogin = "launch_at_login"
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
