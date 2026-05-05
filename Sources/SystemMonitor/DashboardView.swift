import SwiftUI

struct DashboardView: View {
    let snapshot: Snapshot?
    let settings: Settings
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("System Monitor")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 8) {
                MetricCardView(
                    symbol: "cpu",
                    label: "CPU LOAD",
                    value: cpuValue,
                    subtitle: cpuSubtitle,
                    accent: .blue,
                    progress: snapshot?.cpu.usagePercent ?? 0,
                    warning: cpuWarning
                )

                MetricCardView(
                    symbol: "memorychip",
                    label: "MEMORY",
                    value: memoryValue,
                    subtitle: memorySubtitle,
                    accent: .green,
                    progress: snapshot?.memory.usedPercent ?? 0,
                    warning: memoryWarning
                )

                MetricCardView(
                    symbol: "internaldrive",
                    label: "DISK",
                    value: diskValue,
                    subtitle: diskSubtitle,
                    accent: .cyan,
                    progress: primaryDisk?.usedPercent ?? 0,
                    warning: diskWarning
                )

                MetricCardView(
                    symbol: "network",
                    label: "NETWORK",
                    value: networkValue,
                    subtitle: networkSubtitle,
                    accent: .orange
                )

                MetricCardView(
                    symbol: "thermometer",
                    label: "SENSORS",
                    value: sensorValue,
                    subtitle: sensorSubtitle,
                    accent: .yellow
                )

                MetricCardView(
                    symbol: "fan",
                    label: "FANS",
                    value: fanValue,
                    subtitle: fanSubtitle,
                    accent: .yellow
                )

                if let battery = snapshot?.battery {
                    MetricCardView(
                        symbol: battery.state == .charging ? "battery.100.bolt" : "battery.100",
                        label: "BATTERY",
                        value: "\(Int(battery.chargePercent.rounded()))%",
                        subtitle: batterySubtitle(battery),
                        accent: .green,
                        progress: battery.chargePercent,
                        warning: batteryWarning(battery)
                    )
                    .gridCellColumns(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var primaryDisk: DiskSample? {
        guard let disks = snapshot?.disks else {
            return nil
        }
        return disks.first { $0.mountPoint == "/System/Volumes/Data" }
            ?? disks.first { $0.mountPoint == "/" }
            ?? disks.first { !$0.isRemovable }
            ?? disks.first
    }

    private var cpuValue: String {
        guard let snapshot else {
            return "--%"
        }
        return "\(Int(snapshot.cpu.usagePercent.rounded()))%"
    }

    private var cpuSubtitle: String {
        guard let snapshot else {
            return "Waiting for samples"
        }
        if let temperature = snapshot.cpu.temperatureC {
            return SystemFormatters.temperature(temperature, unit: settings.temperatureUnit)
        }
        return "\(snapshot.cpu.coreCount) cores"
    }

    private var memoryValue: String {
        guard let snapshot else {
            return "--%"
        }
        return "\(Int(snapshot.memory.usedPercent.rounded()))%"
    }

    private var memorySubtitle: String {
        guard let snapshot else {
            return "Waiting for samples"
        }
        return "\(SystemFormatters.bytes(snapshot.memory.usedBytes)) of \(SystemFormatters.bytes(snapshot.memory.totalBytes, decimals: 0))"
    }

    private var diskValue: String {
        guard let primaryDisk else {
            return "--% free"
        }
        return "\(Int((100 - primaryDisk.usedPercent).rounded()))% free"
    }

    private var diskSubtitle: String {
        guard let primaryDisk else {
            return "Waiting for samples"
        }
        return "\(primaryDisk.name) · \(SystemFormatters.bytes(primaryDisk.availableBytes, decimals: 0))"
    }

    private var networkValue: String {
        guard let snapshot else {
            return "↓ -- B/s"
        }
        return "↓ \(SystemFormatters.rate(snapshot.network.rxBytesPerSec))"
    }

    private var networkSubtitle: String {
        guard let network = snapshot?.network else {
            return "↑ -- B/s"
        }

        let up = "↑ \(SystemFormatters.rate(network.txBytesPerSec))"
        guard let primaryInterface = network.primaryInterface else {
            return up
        }

        let label = network.connectionType.map { "\($0) (\(primaryInterface))" }
            ?? "Interface: \(primaryInterface)"
        return "\(up)\n\(label)"
    }

    private var sensorValue: String {
        guard let snapshot else {
            return "-- active"
        }
        return "\(snapshot.temperatures.count) active"
    }

    private var sensorSubtitle: String {
        guard let snapshot, !snapshot.temperatures.isEmpty else {
            return "Waiting for detailed sensors"
        }
        return snapshot.temperatures.prefix(2)
            .map { "\($0.label) \(SystemFormatters.temperature($0.temperatureC, unit: settings.temperatureUnit))" }
            .joined(separator: "\n")
    }

    private var fanValue: String {
        guard let snapshot, !snapshot.fans.isEmpty else {
            return "No fan data"
        }
        return "\(snapshot.fans.count) \(snapshot.fans.count == 1 ? "fan" : "fans")"
    }

    private var fanSubtitle: String {
        guard let snapshot, !snapshot.fans.isEmpty else {
            return "Unavailable"
        }
        return snapshot.fans.prefix(2)
            .map { "\($0.label) \($0.rpm) RPM" }
            .joined(separator: "\n")
    }

    private var cpuWarning: Bool {
        guard let snapshot else {
            return false
        }
        return settings.warningsEnabled
            && settings.warningThresholds.cpuEnabled
            && snapshot.cpu.usagePercent >= settings.warningThresholds.cpuPercent
    }

    private var memoryWarning: Bool {
        guard let snapshot else {
            return false
        }
        return settings.warningsEnabled
            && settings.warningThresholds.memoryEnabled
            && snapshot.memory.usedPercent >= settings.warningThresholds.memoryPercent
    }

    private var diskWarning: Bool {
        guard let primaryDisk else {
            return false
        }
        return settings.warningsEnabled
            && settings.warningThresholds.diskEnabled
            && (100 - primaryDisk.usedPercent) <= settings.warningThresholds.diskFreePercent
    }

    private func batteryWarning(_ battery: BatterySample) -> Bool {
        settings.warningsEnabled
            && settings.warningThresholds.batteryEnabled
            && [.discharging, .empty, .unknown].contains(battery.state)
            && battery.chargePercent <= settings.warningThresholds.batteryPercent
    }

    private func batterySubtitle(_ battery: BatterySample) -> String {
        if battery.state == .charging, let seconds = battery.timeToFullSecs {
            return "\(SystemFormatters.duration(seconds)) until full"
        }
        if let seconds = battery.timeToEmptySecs {
            return "\(SystemFormatters.duration(seconds)) remaining"
        }
        switch battery.state {
        case .charging:
            return "Charging"
        case .discharging:
            return "Discharging"
        case .empty:
            return "Empty"
        case .full:
            return "Fully charged"
        case .unknown:
            return "Unknown"
        }
    }
}
