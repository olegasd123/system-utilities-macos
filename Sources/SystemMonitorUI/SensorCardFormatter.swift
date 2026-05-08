import AppCore
import SystemMonitorCore

enum SensorCardFormatter {
    static func subtitle(
        temperatures: [TemperatureSample],
        temperatureUnit: TemperatureUnit
    ) -> String {
        guard !temperatures.isEmpty else {
            return "Waiting for detailed sensors"
        }

        let preferredTemperatures = preferredLabels.compactMap { label in
            temperatures.first { $0.label == label }
        }
        let visibleTemperatures = preferredTemperatures.isEmpty
            ? Array(temperatures.prefix(3))
            : preferredTemperatures

        return visibleTemperatures
            .map { "\($0.label) \(SystemFormatters.temperature($0.temperatureC, unit: temperatureUnit))" }
            .joined(separator: "\n")
    }

    private static let preferredLabels = [
        "Performance Cores",
        "Efficiency Cores",
        "Graphics"
    ]
}
