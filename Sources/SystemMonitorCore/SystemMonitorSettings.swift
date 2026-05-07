import AppCore
import Foundation

public struct SystemMonitorSettings: FeatureSettings {
    public static let featureId = "system-monitor"

    public var menuBar: MenuBarSettings
    public var networkUnits: NetworkUnits
    public var networkDisplay: NetworkDisplay
    public var warningThresholds: WarningThresholds
    public var warningsEnabled: Bool

    public init(
        menuBar: MenuBarSettings,
        networkUnits: NetworkUnits,
        networkDisplay: NetworkDisplay,
        warningThresholds: WarningThresholds,
        warningsEnabled: Bool
    ) {
        self.menuBar = menuBar
        self.networkUnits = networkUnits
        self.networkDisplay = networkDisplay
        self.warningThresholds = warningThresholds
        self.warningsEnabled = warningsEnabled
    }

    public static var defaultValue: SystemMonitorSettings {
        SystemMonitorSettings(
            menuBar: MenuBarSettings(
                showNetworkSpeed: false,
                showCpuLoad: true,
                showMemoryUsage: false,
                showDiskFree: false,
                showBattery: false,
                showTemperature: true,
                displayMode: .singleLine
            ),
            networkUnits: .bytesPerSecond,
            networkDisplay: .uploadAndDownload,
            warningThresholds: .defaultValue,
            warningsEnabled: false
        )
    }

    public enum CodingKeys: String, CodingKey {
        case menuBar = "menu_bar"
        case networkUnits = "network_units"
        case networkDisplay = "network_display"
        case warningThresholds = "warning_thresholds"
        case warningsEnabled = "warnings_enabled"
    }
}

public struct MenuBarSettings: Codable, Equatable, Sendable {
    public var showNetworkSpeed: Bool
    public var showCpuLoad: Bool
    public var showMemoryUsage: Bool
    public var showDiskFree: Bool
    public var showBattery: Bool
    public var showTemperature: Bool
    public var displayMode: MenuBarDisplayMode

    public init(
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

    public enum CodingKeys: String, CodingKey {
        case showNetworkSpeed = "show_network_speed"
        case showCpuLoad = "show_cpu_load"
        case showMemoryUsage = "show_memory_usage"
        case showDiskFree = "show_disk_free"
        case showBattery = "show_battery"
        case showTemperature = "show_temperature"
        case displayMode = "display_mode"
    }

    public init(from decoder: Decoder) throws {
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

public struct WarningThresholds: Codable, Equatable, Sendable {
    public var cpuEnabled: Bool
    public var memoryEnabled: Bool
    public var diskEnabled: Bool
    public var batteryEnabled: Bool
    public var temperatureEnabled: Bool
    public var cpuPercent: Double
    public var memoryPercent: Double
    public var diskFreePercent: Double
    public var batteryPercent: Double
    public var temperatureC: Double

    public init(
        cpuEnabled: Bool,
        memoryEnabled: Bool,
        diskEnabled: Bool,
        batteryEnabled: Bool,
        temperatureEnabled: Bool,
        cpuPercent: Double,
        memoryPercent: Double,
        diskFreePercent: Double,
        batteryPercent: Double,
        temperatureC: Double
    ) {
        self.cpuEnabled = cpuEnabled
        self.memoryEnabled = memoryEnabled
        self.diskEnabled = diskEnabled
        self.batteryEnabled = batteryEnabled
        self.temperatureEnabled = temperatureEnabled
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.diskFreePercent = diskFreePercent
        self.batteryPercent = batteryPercent
        self.temperatureC = temperatureC
    }

    public static let defaultValue = WarningThresholds(
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

    public enum CodingKeys: String, CodingKey {
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

public enum NetworkUnits: String, Codable, Sendable {
    case bytesPerSecond = "bytes_per_second"
    case bitsPerSecond = "bits_per_second"
}

public enum NetworkDisplay: String, Codable, Sendable {
    case uploadAndDownload = "upload_and_download"
    case uploadOnly = "upload_only"
    case downloadOnly = "download_only"
    case combined
}

public enum MenuBarDisplayMode: String, Codable, CaseIterable, Sendable {
    case singleLine = "single_line"
    case twoLine = "two_line"
}
