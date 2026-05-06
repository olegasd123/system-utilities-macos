import AppCore
import Foundation
import UserNotifications

@MainActor
final class WarningService {
    private var cpu = WarningModuleState()
    private var memory = WarningModuleState()
    private var disk = WarningModuleState()
    private var battery = WarningModuleState()
    private var temperature = WarningModuleState()
    private var permissionRequested = false

    func requestPermission() {
        guard !permissionRequested, NotificationRuntime.canUseUserNotifications else {
            return
        }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(snapshot: Snapshot, settings: SystemMonitorSettings) {
        if !settings.warningsEnabled {
            reset()
            return
        }

        let thresholds = settings.warningThresholds

        check(
            module: .cpu,
            state: &cpu,
            enabled: thresholds.cpuEnabled,
            value: snapshot.cpu.usagePercent,
            threshold: thresholds.cpuPercent
        )
        check(
            module: .memory,
            state: &memory,
            enabled: thresholds.memoryEnabled,
            value: snapshot.memory.usedPercent,
            threshold: thresholds.memoryPercent
        )

        if let diskFreePercent = primaryDiskFreePercent(snapshot) {
            check(
                module: .disk,
                state: &disk,
                enabled: thresholds.diskEnabled,
                value: diskFreePercent,
                threshold: thresholds.diskFreePercent
            )
        } else {
            disk.active = false
        }

        if let sample = snapshot.battery {
            check(
                module: .battery,
                state: &battery,
                enabled: thresholds.batteryEnabled && isBatteryDropping(sample.state),
                value: sample.chargePercent,
                threshold: thresholds.batteryPercent
            )
        } else {
            battery.active = false
        }

        if let temperatureC = warningTemperatureC(snapshot) {
            check(
                module: .temperature,
                state: &temperature,
                enabled: thresholds.temperatureEnabled,
                value: temperatureC,
                threshold: thresholds.temperatureC
            )
        } else {
            temperature.active = false
        }
    }

    private func check(
        module: WarningModule,
        state: inout WarningModuleState,
        enabled: Bool,
        value: Double,
        threshold: Double
    ) {
        guard enabled, value.isFinite, threshold.isFinite else {
            state.active = false
            return
        }

        if isWarningValue(module: module, value: value, threshold: threshold) {
            if !state.active, canNotify(state.lastNotifiedAt) {
                sendNotification(module: module, value: value, threshold: threshold)
                state.lastNotifiedAt = Date()
            }
            state.active = true
            return
        }

        if isRecoveredValue(module: module, value: value, threshold: threshold) {
            state.active = false
        }
    }

    private func reset() {
        cpu.active = false
        memory.active = false
        disk.active = false
        battery.active = false
        temperature.active = false
    }

    private func canNotify(_ lastNotifiedAt: Date?) -> Bool {
        guard let lastNotifiedAt else {
            return true
        }
        return Date().timeIntervalSince(lastNotifiedAt) >= 10 * 60
    }

    private func isWarningValue(module: WarningModule, value: Double, threshold: Double) -> Bool {
        switch module {
        case .cpu, .memory, .temperature:
            return value >= threshold
        case .disk, .battery:
            return value <= threshold
        }
    }

    private func isRecoveredValue(module: WarningModule, value: Double, threshold: Double) -> Bool {
        switch module {
        case .cpu, .memory:
            return value <= threshold - 5
        case .temperature:
            return value <= threshold - 3
        case .disk, .battery:
            return value >= threshold + 5
        }
    }

    private func warningTemperatureC(_ snapshot: Snapshot) -> Double? {
        snapshot.cpu.temperatureC ?? snapshot.temperatures.map(\.temperatureC).max()
    }

    private func primaryDiskFreePercent(_ snapshot: Snapshot) -> Double? {
        let disk = snapshot.disks.first { $0.mountPoint == "/System/Volumes/Data" }
            ?? snapshot.disks.first { $0.mountPoint == "/" }
            ?? snapshot.disks.first { !$0.isRemovable }
            ?? snapshot.disks.first
        guard let disk else {
            return nil
        }
        return 100 - disk.usedPercent
    }

    private func isBatteryDropping(_ state: BatteryState) -> Bool {
        state == .discharging || state == .empty || state == .unknown
    }

    private func sendNotification(module: WarningModule, value: Double, threshold: Double) {
        guard NotificationRuntime.canUseUserNotifications else {
            return
        }

        let content = UNMutableNotificationContent()
        let text = notificationText(module: module, value: value, threshold: threshold)
        content.title = text.title
        content.body = text.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "system-monitor-\(module.rawValue)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func notificationText(
        module: WarningModule,
        value: Double,
        threshold: Double
    ) -> (title: String, body: String) {
        switch module {
        case .cpu:
            return (
                "CPU warning",
                "CPU load is \(Int(value.rounded()))%. Limit is \(Int(threshold.rounded()))%."
            )
        case .memory:
            return (
                "Memory warning",
                "Memory use is \(Int(value.rounded()))%. Limit is \(Int(threshold.rounded()))%."
            )
        case .disk:
            return (
                "Disk warning",
                "Free disk space is \(Int(value.rounded()))%. Limit is \(Int(threshold.rounded()))%."
            )
        case .battery:
            return (
                "Battery warning",
                "Battery charge is \(Int(value.rounded()))%. Limit is \(Int(threshold.rounded()))%."
            )
        case .temperature:
            return (
                "Temperature warning",
                "Temperature is \(Int(value.rounded())) C. Limit is \(Int(threshold.rounded())) C."
            )
        }
    }
}

private struct WarningModuleState {
    var active = false
    var lastNotifiedAt: Date?
}

private enum WarningModule: String {
    case cpu
    case memory
    case disk
    case battery
    case temperature
}
