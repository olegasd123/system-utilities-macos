import Foundation

struct MenuBarStatusLine {
    var segments: [MenuBarStatusSegment]

    init(segments: [MenuBarStatusSegment]) {
        self.segments = segments
    }

    init(text: String) {
        segments = [MenuBarStatusSegment(text: text, reservedText: text)]
    }

    var text: String {
        segments.map(\.text).joined(separator: "  ")
    }
}

struct MenuBarStatusSegment {
    var text: String
    var reservedText: String
}

enum MenuBarFormatter {
    static func title(snapshot: Snapshot?, settings: Settings) -> String {
        lines(snapshot: snapshot, settings: settings).joined(separator: "  ")
    }

    static func lines(snapshot: Snapshot?, settings: Settings) -> [String] {
        statusLines(snapshot: snapshot, settings: settings).map(\.text)
    }

    static func statusLines(snapshot: Snapshot?, settings: Settings) -> [MenuBarStatusLine] {
        guard let snapshot else {
            return settings.menuBar.displayMode == .twoLine
                ? [
                    MenuBarStatusLine(text: "CPU --"),
                    MenuBarStatusLine(text: "NET --")
                ]
                : [MenuBarStatusLine(text: "CPU --  NET --")]
        }

        let parts = makeParts(snapshot: snapshot, settings: settings)

        guard !parts.isEmpty else {
            return [MenuBarStatusLine(text: "System Monitor")]
        }

        switch settings.menuBar.displayMode {
        case .singleLine:
            return [line(from: parts)]
        case .twoLine:
            return twoLineParts(parts)
        }
    }

    private static func makeParts(snapshot: Snapshot, settings: Settings) -> [MenuBarPart] {
        var parts: [MenuBarPart] = []
        let menuBar = settings.menuBar

        if menuBar.showCpuLoad {
            parts.append(
                MenuBarPart(
                    text: "CPU \(Int(snapshot.cpu.usagePercent.rounded()))%",
                    reservedText: "CPU 100%",
                    group: .system
                )
            )
        }

        if menuBar.showTemperature, let temperature = snapshot.cpu.temperatureC {
            parts.append(
                MenuBarPart(
                    text: "TEMP \(SystemFormatters.temperature(temperature, unit: settings.temperatureUnit))",
                    reservedText: "TEMP \(reservedTemperature(unit: settings.temperatureUnit))",
                    group: .system
                )
            )
        }

        if menuBar.showMemoryUsage {
            parts.append(
                MenuBarPart(
                    text: "RAM \(Int(snapshot.memory.usedPercent.rounded()))%",
                    reservedText: "RAM 100%",
                    group: .system
                )
            )
        }

        if menuBar.showDiskFree, let disk = primaryDisk(from: snapshot.disks) {
            parts.append(
                MenuBarPart(
                    text: "DISK \(SystemFormatters.compactBytes(disk.availableBytes))",
                    reservedText: "DISK 9999.9GB",
                    group: .system
                )
            )
        }

        if menuBar.showBattery, let battery = snapshot.battery {
            let prefix = isOnPower(battery.state) ? "*" : ""
            parts.append(
                MenuBarPart(
                    text: "BAT \(prefix)\(Int(battery.chargePercent.rounded()))%",
                    reservedText: "BAT *100%",
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
            let reservedRate = reservedNetworkRate(units: settings.networkUnits)
            switch settings.networkDisplay {
            case .uploadAndDownload:
                parts.append(
                    MenuBarPart(
                        text: "↓ \(down) ↑ \(up)",
                        reservedText: "↓ \(reservedRate) ↑ \(reservedRate)",
                        group: .network
                    )
                )
            case .uploadOnly:
                parts.append(
                    MenuBarPart(
                        text: "UP \(up)",
                        reservedText: "UP \(reservedRate)",
                        group: .network
                    )
                )
            case .downloadOnly:
                parts.append(
                    MenuBarPart(
                        text: "DOWN \(down)",
                        reservedText: "DOWN \(reservedRate)",
                        group: .network
                    )
                )
            case .combined:
                parts.append(
                    MenuBarPart(
                        text: "NET \(down)",
                        reservedText: "NET \(reservedRate)",
                        group: .network
                    )
                )
            }
        }

        return parts
    }

    private static func twoLineParts(_ parts: [MenuBarPart]) -> [MenuBarStatusLine] {
        let systemParts = parts.filter { $0.group == .system }
        let networkParts = parts.filter { $0.group == .network }

        if !systemParts.isEmpty, !networkParts.isEmpty {
            return [line(from: systemParts), line(from: networkParts)]
        }

        if parts.count < 3 {
            return [line(from: parts)]
        }

        let splitIndex = (parts.count + 1) / 2
        return [
            line(from: Array(parts.prefix(splitIndex))),
            line(from: Array(parts.suffix(from: splitIndex)))
        ].filter { !$0.segments.isEmpty }
    }

    private static func line(from parts: [MenuBarPart]) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                MenuBarStatusSegment(text: $0.text, reservedText: $0.reservedText)
            }
        )
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

    private static func reservedTemperature(unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return "100.0 C"
        case .fahrenheit:
            return "212 F"
        }
    }

    private static func reservedNetworkRate(units: NetworkUnits) -> String {
        switch units {
        case .bytesPerSecond:
            return "999.9MB/s"
        case .bitsPerSecond:
            return "999.9Mb/s"
        }
    }
}

private struct MenuBarPart {
    var text: String
    var reservedText: String
    var group: MenuBarPartGroup

    init(text: String, reservedText: String, group: MenuBarPartGroup) {
        self.text = text
        self.reservedText = reservedText
        self.group = group
    }
}

private enum MenuBarPartGroup {
    case system
    case network
}
