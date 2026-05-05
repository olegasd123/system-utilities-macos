import Foundation

struct Settings: Codable, Equatable {
    var menuBar: MenuBarSettings
    var temperatureUnit: TemperatureUnit
    var networkUnits: NetworkUnits
    var networkDisplay: NetworkDisplay
    var warningThresholds: WarningThresholds
    var warningsEnabled: Bool
    var launchAtLogin: Bool

    static let defaultValue = Settings(
        menuBar: MenuBarSettings(
            showNetworkSpeed: true,
            showCpuLoad: true,
            showMemoryUsage: false,
            showDiskFree: false,
            showBattery: true,
            showTemperature: false
        ),
        temperatureUnit: .celsius,
        networkUnits: .bytesPerSecond,
        networkDisplay: .uploadAndDownload,
        warningThresholds: .defaultValue,
        warningsEnabled: true,
        launchAtLogin: false
    )

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

    enum CodingKeys: String, CodingKey {
        case showNetworkSpeed = "show_network_speed"
        case showCpuLoad = "show_cpu_load"
        case showMemoryUsage = "show_memory_usage"
        case showDiskFree = "show_disk_free"
        case showBattery = "show_battery"
        case showTemperature = "show_temperature"
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
        cpuEnabled: true,
        memoryEnabled: true,
        diskEnabled: true,
        batteryEnabled: true,
        temperatureEnabled: true,
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
