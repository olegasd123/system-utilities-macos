@testable import SystemMonitorUI
import SystemMonitorCore
import XCTest

final class SensorCardFormatterTests: XCTestCase {
    func testSubtitleUsesPreferredCoreAndGraphicsSensors() {
        let subtitle = SensorCardFormatter.subtitle(
            temperatures: [
                sample("Main Chip", 70),
                sample("Performance Cores", 65),
                sample("Power System", 50),
                sample("Efficiency Cores", 48),
                sample("Graphics", 55)
            ],
            temperatureUnit: .celsius
        )

        XCTAssertEqual(subtitle, [
            "Performance Cores 65.0 C",
            "Efficiency Cores 48.0 C",
            "Graphics 55.0 C"
        ].joined(separator: "\n"))
    }

    func testSubtitleFallsBackToAvailableSensorsWhenPreferredSensorsAreMissing() {
        let subtitle = SensorCardFormatter.subtitle(
            temperatures: [
                sample("Main Chip", 70),
                sample("Power System", 50),
                sample("Storage", 42),
                sample("Extra", 30)
            ],
            temperatureUnit: .celsius
        )

        XCTAssertEqual(subtitle, [
            "Main Chip 70.0 C",
            "Power System 50.0 C",
            "Storage 42.0 C"
        ].joined(separator: "\n"))
    }

    func testSubtitleUsesWaitingTextWhenSensorsAreEmpty() {
        XCTAssertEqual(
            SensorCardFormatter.subtitle(temperatures: [], temperatureUnit: .celsius),
            "Waiting for detailed sensors"
        )
    }

    private func sample(_ label: String, _ temperatureC: Double) -> TemperatureSample {
        TemperatureSample(label: label, temperatureC: temperatureC, criticalC: nil)
    }
}
