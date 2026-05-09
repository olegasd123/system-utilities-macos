@testable import SystemMonitorCore
import XCTest

@MainActor
final class WarningServiceTests: XCTestCase {
    func testCpuWarningUsesHysteresisAndCooldown() {
        let sender = SpyWarningNotificationSender()
        let clock = TestClock(date: Date(timeIntervalSince1970: 1_000))
        let service = WarningService(notificationSender: sender, now: { clock.date })
        let settings = warningSettings { $0.cpuEnabled = true }

        service.evaluate(snapshot: snapshot(cpu: 95), settings: settings)
        service.evaluate(snapshot: snapshot(cpu: 96), settings: settings)
        service.evaluate(snapshot: snapshot(cpu: 84), settings: settings)
        service.evaluate(snapshot: snapshot(cpu: 95), settings: settings)

        XCTAssertEqual(sender.notifications.map(\.title), ["CPU warning"])

        clock.date = Date(timeIntervalSince1970: 1_000 + 10 * 60)
        service.evaluate(snapshot: snapshot(cpu: 84), settings: settings)
        service.evaluate(snapshot: snapshot(cpu: 95), settings: settings)

        XCTAssertEqual(sender.notifications.map(\.title), ["CPU warning", "CPU warning"])
    }

    func testDisabledWarningsResetActiveStateWithoutSending() {
        let sender = SpyWarningNotificationSender()
        let service = WarningService(notificationSender: sender)
        var settings = warningSettings { $0.cpuEnabled = true }

        settings.warningsEnabled = false
        service.evaluate(snapshot: snapshot(cpu: 95), settings: settings)

        XCTAssertEqual(sender.notifications, [])

        settings.warningsEnabled = true
        service.evaluate(snapshot: snapshot(cpu: 95), settings: settings)

        XCTAssertEqual(sender.notifications.map(\.title), ["CPU warning"])
    }

    func testDiskWarningUsesPrimaryDataVolumeFreePercent() {
        let sender = SpyWarningNotificationSender()
        let service = WarningService(notificationSender: sender)
        let settings = warningSettings { $0.diskEnabled = true }

        service.evaluate(
            snapshot: snapshot(disks: [
                disk(mountPoint: "/", usedPercent: 50),
                disk(mountPoint: "/System/Volumes/Data", usedPercent: 92)
            ]),
            settings: settings
        )

        XCTAssertEqual(sender.notifications.map(\.title), ["Disk warning"])
        XCTAssertEqual(sender.notifications[0].body, "Free disk space is 8%. Limit is 10%.")
    }

    func testBatteryWarningOnlySendsWhenBatteryIsDropping() {
        let sender = SpyWarningNotificationSender()
        let service = WarningService(notificationSender: sender)
        let settings = warningSettings { $0.batteryEnabled = true }

        service.evaluate(snapshot: snapshot(battery: battery(percent: 10, state: .charging)), settings: settings)
        service.evaluate(snapshot: snapshot(battery: battery(percent: 10, state: .discharging)), settings: settings)

        XCTAssertEqual(sender.notifications.map(\.title), ["Battery warning"])
    }

    func testTemperatureWarningUsesCpuTemperatureBeforeDetailedSensors() {
        let sender = SpyWarningNotificationSender()
        let service = WarningService(notificationSender: sender)
        let settings = warningSettings { $0.temperatureEnabled = true }

        service.evaluate(
            snapshot: snapshot(cpuTemperatureC: 80, temperatures: [
                TemperatureSample(label: "Main Chip", temperatureC: 95)
            ]),
            settings: settings
        )

        XCTAssertEqual(sender.notifications, [])

        service.evaluate(
            snapshot: snapshot(cpuTemperatureC: 86, temperatures: [
                TemperatureSample(label: "Main Chip", temperatureC: 70)
            ]),
            settings: settings
        )

        XCTAssertEqual(sender.notifications.map(\.title), ["Temperature warning"])
    }

    func testTemperatureWarningFallsBackToHighestDetailedSensor() {
        let sender = SpyWarningNotificationSender()
        let service = WarningService(notificationSender: sender)
        let settings = warningSettings { $0.temperatureEnabled = true }

        service.evaluate(
            snapshot: snapshot(cpuTemperatureC: nil, temperatures: [
                TemperatureSample(label: "Storage", temperatureC: 70),
                TemperatureSample(label: "Main Chip", temperatureC: 90)
            ]),
            settings: settings
        )

        XCTAssertEqual(sender.notifications.map(\.title), ["Temperature warning"])
        XCTAssertEqual(sender.notifications[0].body, "Temperature is 90 C. Limit is 85 C.")
    }

    private func warningSettings(
        _ update: (inout WarningThresholds) -> Void
    ) -> SystemMonitorSettings {
        var settings = SystemMonitorSettings.defaultValue
        settings.warningsEnabled = true
        update(&settings.warningThresholds)
        return settings
    }

    private func snapshot(
        cpu: Double = 10,
        memory: Double = 50,
        cpuTemperatureC: Double? = 40,
        disks: [DiskSample] = [],
        battery: BatterySample? = nil,
        temperatures: [TemperatureSample] = []
    ) -> Snapshot {
        Snapshot(
            cpu: CpuSample(usagePercent: cpu, coreCount: 8, temperatureC: cpuTemperatureC),
            memory: MemorySample(usedBytes: 1, totalBytes: 2, usedPercent: memory),
            disks: disks,
            network: NetworkSample(
                rxBytesPerSec: 0,
                txBytesPerSec: 0,
                totalRxBytes: 0,
                totalTxBytes: 0,
                connectionType: nil
            ),
            battery: battery,
            temperatures: temperatures,
            fans: []
        )
    }

    private func disk(mountPoint: String, usedPercent: Double) -> DiskSample {
        DiskSample(
            name: mountPoint,
            mountPoint: mountPoint,
            totalBytes: 100,
            availableBytes: UInt64(100 - usedPercent),
            usedBytes: UInt64(usedPercent),
            usedPercent: usedPercent,
            isRemovable: false
        )
    }

    private func battery(percent: Double, state: BatteryState) -> BatterySample {
        BatterySample(
            chargePercent: percent,
            state: state,
            timeToFullSecs: nil,
            timeToEmptySecs: nil
        )
    }
}

@MainActor
private final class SpyWarningNotificationSender: WarningNotificationSending {
    var notifications: [WarningNotification] = []

    func send(_ notification: WarningNotification) {
        notifications.append(notification)
    }
}

private final class TestClock {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}
