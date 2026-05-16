import AppCore
import AppUI
import SwiftUI
import SystemMonitorCore

public struct DashboardView: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject private var model: SystemMonitorModel
    private let settings: SystemMonitorSettings
    private let temperatureUnit: TemperatureUnit

    public init(
        model: SystemMonitorModel,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit
    ) {
        self.model = model
        self.settings = settings
        self.temperatureUnit = temperatureUnit
    }

    public var body: some View {
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
                        label: networkLabel,
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
                        subtitleLineLimit: 3,
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
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var snapshot: Snapshot? {
        model.snapshot
    }

    private var networkTotals: NetworkTotals? {
        model.networkTotals
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
            return localization("Waiting for samples")
        }
        if let temperature = snapshot.cpu.temperatureC {
            return localization(
                "Temp %@",
                SystemFormatters.temperature(
                    temperature,
                    unit: temperatureUnit,
                    localization: localization
                )
            )
        }
        return localization("%d cores", snapshot.cpu.coreCount)
    }

    private var memoryValue: String {
        guard let snapshot else {
            return "--%"
        }
        return "\(Int(snapshot.memory.usedPercent.rounded()))%"
    }

    private var memorySubtitle: String {
        guard let snapshot else {
            return localization("Waiting for samples")
        }
        return localization(
            "%@ of %@",
            SystemFormatters.bytes(snapshot.memory.usedBytes, localization: localization),
            SystemFormatters.bytes(snapshot.memory.totalBytes, decimals: 0, localization: localization)
        )
    }

    private var diskValue: String {
        guard let primaryDisk else {
            return localization("--% free")
        }
        return localization("%d%% free", Int((100 - primaryDisk.usedPercent).rounded()))
    }

    private var diskSubtitle: String {
        guard let primaryDisk else {
            return localization("Waiting for samples")
        }
        let availableBytes = SystemFormatters.bytes(
            primaryDisk.availableBytes,
            decimals: 0,
            localization: localization
        )
        let freeSpace = "\(primaryDisk.name) · \(availableBytes)"
        guard let storageTemperature else {
            return freeSpace
        }
        let temperature = SystemFormatters.temperature(
            storageTemperature.temperatureC,
            unit: temperatureUnit,
            localization: localization
        )
        return "\(freeSpace)\n\(localization("Temp %@", temperature))"
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
            return "↓ -- \(localization("Unit byte per second"))"
        }
        return "↓ \(SystemFormatters.rate(snapshot.network.rxBytesPerSec, localization: localization))"
    }

    private var networkLabel: String {
        snapshot?.network.connectionType?.uppercased() ?? "NETWORK"
    }

    private var networkSubtitle: String {
        guard let network = snapshot?.network else {
            return "↑ -- \(localization("Unit byte per second"))"
        }

        return "↑ \(SystemFormatters.rate(network.txBytesPerSec, localization: localization))"
    }

    private var networkTotalsFooter: AnyView? {
        guard let networkTotals else {
            return nil
        }

        return AnyView(
            HStack(spacing: 8) {
                Label(
                    SystemFormatters.bytes(networkTotals.rxBytes, localization: localization),
                    systemImage: "arrow.down"
                )
                Label(
                    SystemFormatters.bytes(networkTotals.txBytes, localization: localization),
                    systemImage: "arrow.up"
                )

                Spacer(minLength: 0)

                Button(action: { model.resetNetworkTotals() }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help(localization("Reset network totals"))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        )
    }

    private var sensorValue: String {
        guard let snapshot else {
            return localization("-- active")
        }
        return localization("%d active", snapshot.temperatures.count)
    }

    private var sensorSubtitle: String {
        SensorCardFormatter.subtitle(
            temperatures: snapshot?.temperatures ?? [],
            temperatureUnit: temperatureUnit,
            localization: localization
        )
    }

    private var fanValue: String {
        FanCardFormatter.value(
            fans: snapshot?.fans ?? [],
            localization: localization
        )
    }

    private var fanSubtitle: String {
        FanCardFormatter.subtitle(
            fans: snapshot?.fans ?? [],
            localization: localization
        )
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
        var lines: [String] = []
        if battery.state == .charging, let seconds = battery.timeToFullSecs {
            lines.append(
                localization(
                    "%@ until full",
                    SystemFormatters.duration(seconds, localization: localization)
                )
            )
        } else if let seconds = battery.timeToEmptySecs {
            lines.append(
                localization(
                    "%@ remaining",
                    SystemFormatters.duration(seconds, localization: localization)
                )
            )
        } else {
            lines.append(batteryStateLabel(battery.state))
        }
        if let temperature = battery.temperatureC {
            lines.append(
                localization(
                    "Temp %@",
                    SystemFormatters.temperature(
                        temperature,
                        unit: temperatureUnit,
                        localization: localization
                    )
                )
            )
        }
        return lines.joined(separator: "\n")
    }

    private func batteryStateLabel(_ state: BatteryState) -> String {
        switch state {
        case .charging:
            return localization("Charging")
        case .discharging:
            return localization("Discharging")
        case .empty:
            return localization("Empty")
        case .full:
            return localization("Fully charged")
        case .unknown:
            return localization("Unknown")
        }
    }
}
