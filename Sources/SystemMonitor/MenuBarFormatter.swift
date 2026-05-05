import Foundation

enum MenuBarFormatter {
    static func title(snapshot: Snapshot?, settings: Settings) -> String {
        lines(snapshot: snapshot, settings: settings).joined(separator: "  ")
    }

    static func lines(snapshot: Snapshot?, settings: Settings) -> [String] {
        guard let snapshot else {
            return settings.menuBar.displayMode == .twoLine
                ? ["CPU --", "NET --"]
                : ["CPU --  NET --"]
        }

        let parts = makeParts(snapshot: snapshot, settings: settings)

        guard !parts.isEmpty else {
            return ["System Monitor"]
        }

        switch settings.menuBar.displayMode {
        case .singleLine:
            return [joined(parts)]
        case .twoLine:
            return twoLineParts(parts)
        }
    }

    private static func makeParts(snapshot: Snapshot, settings: Settings) -> [MenuBarPart] {
        var parts: [MenuBarPart] = []
        let menuBar = settings.menuBar

        if menuBar.showCpuLoad {
            parts.append(MenuBarPart("CPU \(Int(snapshot.cpu.usagePercent.rounded()))%", group: .system))
        }

        if menuBar.showTemperature, let temperature = snapshot.cpu.temperatureC {
            parts.append(
                MenuBarPart(
                    "TEMP \(SystemFormatters.temperature(temperature, unit: settings.temperatureUnit))",
                    group: .system
                )
            )
        }

        if menuBar.showMemoryUsage {
            parts.append(MenuBarPart("RAM \(Int(snapshot.memory.usedPercent.rounded()))%", group: .system))
        }

        if menuBar.showDiskFree, let disk = primaryDisk(from: snapshot.disks) {
            parts.append(MenuBarPart("DISK \(SystemFormatters.compactBytes(disk.availableBytes))", group: .system))
        }

        if menuBar.showBattery, let battery = snapshot.battery {
            let prefix = isOnPower(battery.state) ? "*" : ""
            parts.append(
                MenuBarPart(
                    "BAT \(prefix)\(Int(battery.chargePercent.rounded()))%",
                    group: .system
                )
            )
        }

        if menuBar.showNetworkSpeed {
            let down = SystemFormatters.compactRate(
                snapshot.network.rxBytesPerSec,
                units: settings.networkUnits
            )
            let up = SystemFormatters.compactRate(
                snapshot.network.txBytesPerSec,
                units: settings.networkUnits
            )
            switch settings.networkDisplay {
            case .uploadAndDownload:
                parts.append(MenuBarPart("↓ \(down) ↑ \(up)", group: .network))
            case .uploadOnly:
                parts.append(MenuBarPart("UP \(up)", group: .network))
            case .downloadOnly:
                parts.append(MenuBarPart("DOWN \(down)", group: .network))
            case .combined:
                parts.append(MenuBarPart("NET \(down)", group: .network))
            }
        }

        return parts
    }

    private static func twoLineParts(_ parts: [MenuBarPart]) -> [String] {
        let systemParts = parts.filter { $0.group == .system }
        let networkParts = parts.filter { $0.group == .network }

        if !systemParts.isEmpty, !networkParts.isEmpty {
            return [joined(systemParts), joined(networkParts)]
        }

        if parts.count < 3 {
            return [joined(parts)]
        }

        let splitIndex = (parts.count + 1) / 2
        return [
            joined(Array(parts.prefix(splitIndex))),
            joined(Array(parts.suffix(from: splitIndex)))
        ].filter { !$0.isEmpty }
    }

    private static func joined(_ parts: [MenuBarPart]) -> String {
        parts.map(\.text).joined(separator: "  ")
    }

    private static func primaryDisk(from disks: [DiskSample]) -> DiskSample? {
        disks.first { $0.mountPoint == "/System/Volumes/Data" }
            ?? disks.first { $0.mountPoint == "/" }
            ?? disks.first { !$0.isRemovable }
            ?? disks.first
    }

    private static func isOnPower(_ state: BatteryState) -> Bool {
        state == .charging || state == .full
    }
}

private struct MenuBarPart {
    var text: String
    var group: MenuBarPartGroup

    init(_ text: String, group: MenuBarPartGroup) {
        self.text = text
        self.group = group
    }
}

private enum MenuBarPartGroup {
    case system
    case network
}
