import AppCore
import SystemMonitorCore

enum SensorCardFormatter {
    static func subtitle(
        temperatures: [TemperatureSample],
        temperatureUnit: TemperatureUnit,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        guard !temperatures.isEmpty else {
            return localization("Waiting for detailed sensors")
        }

        let preferredTemperatures = preferredLabels.compactMap { label in
            temperatures.first { $0.label == label }
        }
        let visibleTemperatures = preferredTemperatures.isEmpty
            ? Array(temperatures.prefix(3))
            : preferredTemperatures

        return visibleTemperatures
            .map {
                let temperature = SystemFormatters.temperature(
                    $0.temperatureC,
                    unit: temperatureUnit,
                    localization: localization
                )
                return "\(localization($0.label)) \(temperature)"
            }
            .joined(separator: "\n")
    }

    private static let preferredLabels = [
        "Performance Cores",
        "Efficiency Cores",
        "Graphics"
    ]
}
