import SystemMonitorCore
import XCTest

final class SystemMonitorSettingsTests: XCTestCase {
    func testDefaultSettingsMatchExpectedUserFacingDefaults() {
        let settings = SystemMonitorSettings.defaultValue

        XCTAssertTrue(settings.menuBar.showCpuLoad)
        XCTAssertTrue(settings.menuBar.showTemperature)
        XCTAssertFalse(settings.menuBar.showNetworkSpeed)
        XCTAssertFalse(settings.menuBar.showMemoryUsage)
        XCTAssertEqual(settings.menuBar.displayMode, .singleLine)
        XCTAssertEqual(settings.networkUnits, .bytesPerSecond)
        XCTAssertEqual(settings.networkDisplay, .greater)
        XCTAssertFalse(settings.warningsEnabled)
        XCTAssertEqual(settings.warningThresholds.cpuPercent, 90)
        XCTAssertEqual(settings.warningThresholds.temperatureC, 85)
    }

    func testDecodingUsesDefaultsForMissingTopLevelKeys() throws {
        let data = Data(#"{"warnings_enabled":true}"#.utf8)

        let settings = try JSONDecoder().decode(SystemMonitorSettings.self, from: data)
        let defaults = SystemMonitorSettings.defaultValue

        XCTAssertEqual(settings.menuBar, defaults.menuBar)
        XCTAssertEqual(settings.networkUnits, defaults.networkUnits)
        XCTAssertEqual(settings.networkDisplay, defaults.networkDisplay)
        XCTAssertEqual(settings.warningThresholds, defaults.warningThresholds)
        XCTAssertTrue(settings.warningsEnabled)
    }

    func testMenuBarDecodingKeepsLegacyDefaultsForMissingKeys() throws {
        let data = Data(#"{"display_mode":"two_line"}"#.utf8)

        let settings = try JSONDecoder().decode(MenuBarSettings.self, from: data)

        XCTAssertTrue(settings.showNetworkSpeed)
        XCTAssertTrue(settings.showCpuLoad)
        XCTAssertFalse(settings.showMemoryUsage)
        XCTAssertFalse(settings.showDiskFree)
        XCTAssertTrue(settings.showBattery)
        XCTAssertFalse(settings.showTemperature)
        XCTAssertEqual(settings.displayMode, .twoLine)
    }
}
