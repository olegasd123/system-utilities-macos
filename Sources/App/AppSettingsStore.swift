import AppCore
import Foundation
import SystemMonitor

struct AppSettingsStore: Sendable {
    static let standard = AppSettingsStore()

    func loadResult() -> AppSettingsLoadResult {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return AppSettingsLoadResult(settings: .defaultValue, loadedFromDisk: false)
        }

        let decoder = JSONDecoder()

        if let settings = try? decoder.decode(AppSettings.self, from: data) {
            return AppSettingsLoadResult(settings: settings, loadedFromDisk: true)
        }

        if let legacy = try? decoder.decode(LegacyFlatSettings.self, from: data) {
            return AppSettingsLoadResult(settings: legacy.toAppSettings(), loadedFromDisk: true)
        }

        if let envelope = try? decoder.decode(LegacyEnvelope.self, from: data) {
            return AppSettingsLoadResult(
                settings: envelope.settings.toAppSettings(),
                loadedFromDisk: true
            )
        }

        return AppSettingsLoadResult(settings: .defaultValue, loadedFromDisk: false)
    }

    func save(_ settings: AppSettings) throws {
        let directory = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    private var settingsURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("dev.olegoleg.system-monitor", isDirectory: true)
            .appendingPathComponent("settings.json")
    }
}

struct AppSettingsLoadResult: Equatable, Sendable {
    let settings: AppSettings
    let loadedFromDisk: Bool
}

private struct LegacyFlatSettings: Codable {
    var menuBar: MenuBarSettings
    var temperatureUnit: TemperatureUnit
    var networkUnits: NetworkUnits
    var networkDisplay: NetworkDisplay
    var warningThresholds: WarningThresholds
    var warningsEnabled: Bool
    var launchAtLogin: Bool

    enum CodingKeys: String, CodingKey {
        case menuBar = "menu_bar"
        case temperatureUnit = "temperature_unit"
        case networkUnits = "network_units"
        case networkDisplay = "network_display"
        case warningThresholds = "warning_thresholds"
        case warningsEnabled = "warnings_enabled"
        case launchAtLogin = "launch_at_login"
    }

    func toAppSettings() -> AppSettings {
        AppSettings(
            general: GeneralSettings(
                temperatureUnit: temperatureUnit,
                launchAtLogin: launchAtLogin
            ),
            systemMonitor: SystemMonitorSettings(
                menuBar: menuBar,
                networkUnits: networkUnits,
                networkDisplay: networkDisplay,
                warningThresholds: warningThresholds,
                warningsEnabled: warningsEnabled
            )
        )
    }
}

private struct LegacyEnvelope: Codable {
    let settings: LegacyFlatSettings
}
