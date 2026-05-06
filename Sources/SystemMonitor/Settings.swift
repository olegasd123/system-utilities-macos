import Foundation

struct Settings: Codable, Equatable {
    var menuBar: MenuBarSettings
    var temperatureUnit: TemperatureUnit
    var networkUnits: NetworkUnits
    var networkDisplay: NetworkDisplay
    var warningThresholds: WarningThresholds
    var warningsEnabled: Bool
    var launchAtLogin: Bool

    static var defaultValue: Settings {
        Settings(
            menuBar: MenuBarSettings(
                showNetworkSpeed: false,
                showCpuLoad: true,
                showMemoryUsage: false,
                showDiskFree: false,
                showBattery: false,
                showTemperature: true,
                displayMode: .singleLine
            ),
            temperatureUnit: systemPreferredTemperatureUnit,
            networkUnits: .bytesPerSecond,
            networkDisplay: .uploadAndDownload,
            warningThresholds: .defaultValue,
            warningsEnabled: false,
            launchAtLogin: true
        )
    }

    private static var systemPreferredTemperatureUnit: TemperatureUnit {
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

    enum CodingKeys: String, CodingKey {
        case menuBar = "menu_bar"
        case temperatureUnit = "temperature_unit"
        case networkUnits = "network_units"
        case networkDisplay = "network_display"
        case warningThresholds = "warning_thresholds"
        case warningsEnabled = "warnings_enabled"
        case launchAtLogin = "launch_at_login"
    }
}

struct MenuBarSettings: Codable, Equatable {
    var showNetworkSpeed: Bool
    var showCpuLoad: Bool
    var showMemoryUsage: Bool
    var showDiskFree: Bool
    var showBattery: Bool
    var showTemperature: Bool
    var displayMode: MenuBarDisplayMode

    init(
        showNetworkSpeed: Bool,
        showCpuLoad: Bool,
        showMemoryUsage: Bool,
        showDiskFree: Bool,
        showBattery: Bool,
        showTemperature: Bool,
        displayMode: MenuBarDisplayMode = .singleLine
    ) {
        self.showNetworkSpeed = showNetworkSpeed
        self.showCpuLoad = showCpuLoad
        self.showMemoryUsage = showMemoryUsage
        self.showDiskFree = showDiskFree
        self.showBattery = showBattery
        self.showTemperature = showTemperature
        self.displayMode = displayMode
    }

    enum CodingKeys: String, CodingKey {
        case showNetworkSpeed = "show_network_speed"
        case showCpuLoad = "show_cpu_load"
        case showMemoryUsage = "show_memory_usage"
        case showDiskFree = "show_disk_free"
        case showBattery = "show_battery"
        case showTemperature = "show_temperature"
        case displayMode = "display_mode"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showNetworkSpeed = try container.decodeIfPresent(
            Bool.self,
            forKey: .showNetworkSpeed
        ) ?? true
        showCpuLoad = try container.decodeIfPresent(Bool.self, forKey: .showCpuLoad) ?? true
        showMemoryUsage = try container.decodeIfPresent(
            Bool.self,
            forKey: .showMemoryUsage
        ) ?? false
        showDiskFree = try container.decodeIfPresent(Bool.self, forKey: .showDiskFree) ?? false
        showBattery = try container.decodeIfPresent(Bool.self, forKey: .showBattery) ?? true
        showTemperature = try container.decodeIfPresent(
            Bool.self,
            forKey: .showTemperature
        ) ?? false
        displayMode = try container.decodeIfPresent(
            MenuBarDisplayMode.self,
            forKey: .displayMode
        ) ?? .singleLine
    }
}

struct WarningThresholds: Codable, Equatable {
    var cpuEnabled: Bool
    var memoryEnabled: Bool
    var diskEnabled: Bool
    var batteryEnabled: Bool
    var temperatureEnabled: Bool
    var cpuPercent: Double
    var memoryPercent: Double
    var diskFreePercent: Double
    var batteryPercent: Double
    var temperatureC: Double

    static let defaultValue = WarningThresholds(
        cpuEnabled: false,
        memoryEnabled: false,
        diskEnabled: false,
        batteryEnabled: false,
        temperatureEnabled: false,
        cpuPercent: 90,
        memoryPercent: 90,
        diskFreePercent: 10,
        batteryPercent: 20,
        temperatureC: 85
    )

    enum CodingKeys: String, CodingKey {
        case cpuEnabled = "cpu_enabled"
        case memoryEnabled = "memory_enabled"
        case diskEnabled = "disk_enabled"
        case batteryEnabled = "battery_enabled"
        case temperatureEnabled = "temperature_enabled"
        case cpuPercent = "cpu_percent"
        case memoryPercent = "memory_percent"
        case diskFreePercent = "disk_free_percent"
        case batteryPercent = "battery_percent"
        case temperatureC = "temperature_c"
    }
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius
    case fahrenheit
}

enum NetworkUnits: String, Codable {
    case bytesPerSecond = "bytes_per_second"
    case bitsPerSecond = "bits_per_second"
}

enum NetworkDisplay: String, Codable {
    case uploadAndDownload = "upload_and_download"
    case uploadOnly = "upload_only"
    case downloadOnly = "download_only"
    case combined
}

enum MenuBarDisplayMode: String, Codable, CaseIterable {
    case singleLine = "single_line"
    case twoLine = "two_line"
}
