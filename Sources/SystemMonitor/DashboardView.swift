import SwiftUI

struct DashboardView: View {
    let snapshot: Snapshot?
    let networkTotals: NetworkTotals?
    let settings: Settings
    let onResetNetworkTotals: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: PopoverLayout.titleSpacing) {
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
            .frame(height: PopoverLayout.titleHeight)
            .padding(.horizontal, 4)

            VStack(spacing: PopoverLayout.rowSpacing) {
                metricRow {
                    MetricCardView(
                        symbol: "cpu",
                        label: "CPU LOAD",
                        value: cpuValue,
                        subtitle: cpuSubtitle,
                        accent: .blue,
                        progress: snapshot?.cpu.usagePercent ?? 0,
                        warning: cpuWarning
                    )
                } right: {
                    MetricCardView(
                        symbol: "memorychip",
                        label: "MEMORY",
                        value: memoryValue,
                        subtitle: memorySubtitle,
                        accent: .green,
                        progress: snapshot?.memory.usedPercent ?? 0,
                        warning: memoryWarning
                    )
                }

                metricRow {
                    MetricCardView(
                        symbol: "internaldrive",
                        label: "DISK",
                        value: diskValue,
                        subtitle: diskSubtitle,
                        accent: .cyan,
                        progress: primaryDisk?.usedPercent ?? 0,
                        warning: diskWarning
                    )
                } right: {
                    MetricCardView(
                        symbol: "network",
                        label: "NETWORK",
                        value: networkValue,
                        subtitle: networkSubtitle,
                        accent: .orange,
                        footer: networkTotalsFooter
                    )
                }

                metricRow {
                    MetricCardView(
                        symbol: "thermometer",
                        label: "SENSORS",
                        value: sensorValue,
                        subtitle: sensorSubtitle,
                        accent: .yellow,
                        warning: temperatureWarning
                    )
                } right: {
                    MetricCardView(
                        symbol: "fan",
                        label: "FANS",
                        value: fanValue,
                        subtitle: fanSubtitle,
                        accent: .yellow
                    )
                }

                if let battery = snapshot?.battery {
                    MetricCardView(
                        symbol: BatterySymbol.name(for: battery),
                        label: "BATTERY",
                        value: "\(Int(battery.chargePercent.rounded()))%",
                        subtitle: batterySubtitle(battery),
                        accent: .green,
                        progress: battery.chargePercent,
                        warning: batteryWarning(battery)
                    )
                }
            }
        }
        .padding(PopoverLayout.contentPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func metricRow<Left: View, Right: View>(
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        HStack(spacing: PopoverLayout.rowSpacing) {
            left()
            right()
        }
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
            return "Temp \(SystemFormatters.temperature(temperature, unit: settings.temperatureUnit))"
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
        let freeSpace = "\(primaryDisk.name) · \(SystemFormatters.bytes(primaryDisk.availableBytes, decimals: 0))"
        guard let storageTemperature else {
            return freeSpace
        }
        return "\(freeSpace)\nStorage \(SystemFormatters.temperature(storageTemperature.temperatureC, unit: settings.temperatureUnit))"
    }

    private var storageTemperature: TemperatureSample? {
        snapshot?.temperatures.first { sample in
            let label = sample.label.lowercased()
            return label == "storage"
                || label.contains("nand")
                || label.contains("ssd")
                || label.contains("nvme")
                || label.contains("disk")
        }
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

    private var networkTotalsFooter: AnyView? {
        guard let networkTotals else {
            return nil
        }

        return AnyView(
            HStack(spacing: 8) {
                Label(SystemFormatters.bytes(networkTotals.rxBytes), systemImage: "arrow.down")
                Label(SystemFormatters.bytes(networkTotals.txBytes), systemImage: "arrow.up")

                Spacer(minLength: 0)

                Button(action: onResetNetworkTotals) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help("Reset network totals")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        )
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
            .map { "\($0.label):  \($0.rpm) RPM" }
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

    private var temperatureWarning: Bool {
        guard let temperature = warningTemperatureC else {
            return false
        }
        return settings.warningsEnabled
            && settings.warningThresholds.temperatureEnabled
            && temperature >= settings.warningThresholds.temperatureC
    }

    private var warningTemperatureC: Double? {
        if let temperature = snapshot?.cpu.temperatureC {
            return temperature
        }
        return snapshot?.temperatures.map(\.temperatureC).max()
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
