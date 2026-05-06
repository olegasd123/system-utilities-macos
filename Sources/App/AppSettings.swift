import AppCore
import Foundation
import SystemMonitor

struct AppSettings: Codable, Equatable, Sendable {
    var general: GeneralSettings
    var systemMonitor: SystemMonitorSettings

    static var defaultValue: AppSettings {
        AppSettings(
            general: .defaultValue,
            systemMonitor: .defaultValue
        )
    }

    enum CodingKeys: String, CodingKey {
        case general
        case systemMonitor = "system_monitor"
    }
}
