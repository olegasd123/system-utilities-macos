import AppCore
import SystemMonitorCore
import XCTest

final class AppSettingsStoreTests: XCTestCase {
    private var bundleIds: [String] = []

    override func tearDownWithError() throws {
        for bundleId in bundleIds {
            try? FileManager.default.removeItem(at: settingsDirectory(bundleId: bundleId))
        }
        bundleIds = []
        try super.tearDownWithError()
    }

    func testSaveAndLoadRoundTripUsesVersionedFormat() throws {
        let bundleId = uniqueBundleId()
        let store = AppSettingsStore(bundleId: bundleId)
        var raw = RawAppSettings(
            general: GeneralSettings(temperatureUnit: .fahrenheit, launchAtLogin: false),
            features: [:]
        )
        var monitor = SystemMonitorSettings.defaultValue
        monitor.menuBar.showNetworkSpeed = true
        monitor.networkUnits = .bitsPerSecond
        monitor.networkDisplay = .combined
        monitor.warningsEnabled = true
        raw.setValue(monitor)

        try store.save(raw)
        let loaded = store.load()

        XCTAssertTrue(loaded.loadedFromDisk)
        XCTAssertEqual(loaded.value.general, raw.general)
        XCTAssertEqual(loaded.value.value(for: SystemMonitorSettings.self), monitor)
    }

    func testLoadReadsFlatLegacySettings() throws {
        let bundleId = uniqueBundleId()
        let store = AppSettingsStore(bundleId: bundleId)
        try writeSettings(
            bundleId: bundleId,
            json: [
                "temperature_unit": "fahrenheit",
                "launch_at_login": false,
                "network_units": "bits_per_second",
                "network_display": "upload_only",
                "warnings_enabled": true,
                "menu_bar": [
                    "show_cpu_load": false,
                    "show_network_speed": true,
                    "display_mode": "two_line"
                ]
            ]
        )

        let loaded = store.load()
        let monitor = loaded.value.value(for: SystemMonitorSettings.self)

        XCTAssertTrue(loaded.loadedFromDisk)
        XCTAssertEqual(loaded.value.general.temperatureUnit, .fahrenheit)
        XCTAssertFalse(loaded.value.general.launchAtLogin)
        XCTAssertEqual(monitor.networkUnits, .bitsPerSecond)
        XCTAssertEqual(monitor.networkDisplay, .uploadOnly)
        XCTAssertTrue(monitor.warningsEnabled)
        XCTAssertFalse(monitor.menuBar.showCpuLoad)
        XCTAssertTrue(monitor.menuBar.showNetworkSpeed)
        XCTAssertEqual(monitor.menuBar.displayMode, .twoLine)
    }

    func testLoadReturnsDefaultsForMissingFile() {
        let store = AppSettingsStore(bundleId: uniqueBundleId())

        let loaded = store.load()

        XCTAssertFalse(loaded.loadedFromDisk)
        XCTAssertEqual(loaded.value, .defaultValue)
    }

    private func uniqueBundleId() -> String {
        let bundleId = "dev.oleg-verhoglyad.SystemMonitorTests.\(UUID().uuidString)"
        bundleIds.append(bundleId)
        return bundleId
    }

    private func writeSettings(bundleId: String, json: [String: Any]) throws {
        let directory = settingsDirectory(bundleId: bundleId)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: directory.appendingPathComponent("settings.json"), options: .atomic)
    }

    private func settingsDirectory(bundleId: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bundleId, isDirectory: true)
    }
}
