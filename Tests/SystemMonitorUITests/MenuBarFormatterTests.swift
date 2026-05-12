import AppCore
import AppUI
import SystemMonitorCore
import SystemMonitorUI
import XCTest

final class MenuBarFormatterTests: XCTestCase {
    func testNoSelectedMetricsReturnsNoLines() {
        var settings = SystemMonitorSettings.defaultValue
        settings.menuBar = MenuBarSettings(
            showNetworkSpeed: false,
            showCpuLoad: false,
            showMemoryUsage: false,
            showDiskFree: false,
            showBattery: false,
            showTemperature: false
        )

        XCTAssertEqual(
            MenuBarFormatter.statusLines(
                snapshot: sampleSnapshot,
                settings: settings,
                temperatureUnit: .celsius
            ),
            []
        )
    }

    func testMissingSnapshotUsesPlaceholders() {
        var settings = SystemMonitorSettings.defaultValue
        settings.menuBar.showNetworkSpeed = true

        XCTAssertEqual(
            MenuBarFormatter.lines(
                snapshot: nil,
                settings: settings,
                temperatureUnit: .celsius
            ),
            ["CPU --  ↕ --"]
        )

        settings.menuBar.displayMode = .twoLine

        XCTAssertEqual(
            MenuBarFormatter.lines(
                snapshot: nil,
                settings: settings,
                temperatureUnit: .celsius
            ),
            ["CPU  ↕", "--  --"]
        )
    }

    func testSingleLineIncludesSelectedMetricsInOrder() {
        var settings = allMetricsSettings
        settings.networkDisplay = .greater
        settings.networkUnits = .bytesPerSecond

        let lines = MenuBarFormatter.lines(
            snapshot: sampleSnapshot,
            settings: settings,
            temperatureUnit: .celsius
        )

        XCTAssertEqual(lines, ["42%  55.0 C  60%  512.0GB  78%  ↓ 2.0KB"])
    }

    func testTwoLineUploadAndDownloadKeepsNetworkValuesTogether() {
        var settings = allMetricsSettings
        settings.menuBar.displayMode = .twoLine
        settings.networkDisplay = .uploadAndDownload

        let lines = MenuBarFormatter.lines(
            snapshot: sampleSnapshot,
            settings: settings,
            temperatureUnit: .fahrenheit
        )

        XCTAssertEqual(lines, [
            "CPU  TEMP  RAM  DISK  BAT  ↓ 2.0KB",
            "42%  131F  60%  512.0GB  78%  ↑ 1.0KB"
        ])
    }

    func testStatusLineSegmentsIncludeSymbolsAndReservedText() {
        var settings = SystemMonitorSettings.defaultValue
        settings.menuBar.showTemperature = false

        let lines = MenuBarFormatter.statusLines(
            snapshot: sampleSnapshot,
            settings: settings,
            temperatureUnit: .celsius
        )

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].segments.count, 1)
        XCTAssertEqual(lines[0].segments[0], MenuBarStatusSegment(
            text: "42%",
            reservedText: "100%",
            symbolName: "cpu",
            fallbackPrefix: "CPU"
        ))
    }

    private var allMetricsSettings: SystemMonitorSettings {
        var settings = SystemMonitorSettings.defaultValue
        settings.menuBar.showCpuLoad = true
        settings.menuBar.showTemperature = true
        settings.menuBar.showMemoryUsage = true
        settings.menuBar.showDiskFree = true
        settings.menuBar.showBattery = true
        settings.menuBar.showNetworkSpeed = true
        return settings
    }

    private var sampleSnapshot: Snapshot {
        Snapshot(
            cpu: CpuSample(usagePercent: 41.6, coreCount: 8, temperatureC: 55),
            memory: MemorySample(
                usedBytes: 12 * 1024 * 1024 * 1024,
                totalBytes: 20 * 1024 * 1024 * 1024,
                usedPercent: 60
            ),
            disks: [
                DiskSample(
                    name: "Data",
                    mountPoint: "/System/Volumes/Data",
                    totalBytes: 1024 * 1024 * 1024 * 1024,
                    availableBytes: 512 * 1024 * 1024 * 1024,
                    usedBytes: 512 * 1024 * 1024 * 1024,
                    usedPercent: 50,
                    isRemovable: false
                )
            ],
            network: NetworkSample(
                rxBytesPerSec: 2048,
                txBytesPerSec: 1024,
                totalRxBytes: 10_000,
                totalTxBytes: 5_000,
                connectionType: "Wi-Fi"
            ),
            battery: BatterySample(
                chargePercent: 78,
                state: .discharging,
                timeToFullSecs: nil,
                timeToEmptySecs: 7_200
            ),
            temperatures: [
                TemperatureSample(label: "Performance Cores", temperatureC: 55)
            ],
            fans: [
                FanSample(label: "Fan 1", rpm: 2400)
            ]
        )
    }
}
