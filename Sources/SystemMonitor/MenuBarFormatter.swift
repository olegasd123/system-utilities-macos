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
    var symbolName: String?
    var fallbackPrefix: String?

    init(
        text: String,
        reservedText: String,
        symbolName: String? = nil,
        fallbackPrefix: String? = nil
    ) {
        self.text = text
        self.reservedText = reservedText
        self.symbolName = symbolName
        self.fallbackPrefix = fallbackPrefix
    }
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
            return [line(from: parts, style: .icon)]
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
                    compactText: "\(Int(snapshot.cpu.usagePercent.rounded()))%",
                    compactReservedText: "100%",
                    symbolName: "cpu",
                    fallbackPrefix: "CPU",
                    group: .system
                )
            )
        }

        if menuBar.showTemperature, let temperature = snapshot.cpu.temperatureC {
            parts.append(
                MenuBarPart(
                    text: "TEMP \(SystemFormatters.temperature(temperature, unit: settings.temperatureUnit))",
                    reservedText: "TEMP \(reservedTemperature(unit: settings.temperatureUnit))",
                    compactText: SystemFormatters.temperature(temperature, unit: settings.temperatureUnit),
                    compactReservedText: reservedTemperature(unit: settings.temperatureUnit),
                    symbolName: "thermometer.medium",
                    fallbackPrefix: "TEMP",
                    group: .system
                )
            )
        }

        if menuBar.showMemoryUsage {
            parts.append(
                MenuBarPart(
                    text: "RAM \(Int(snapshot.memory.usedPercent.rounded()))%",
                    reservedText: "RAM 100%",
                    compactText: "\(Int(snapshot.memory.usedPercent.rounded()))%",
                    compactReservedText: "100%",
                    symbolName: "memorychip",
                    fallbackPrefix: "RAM",
                    group: .system
                )
            )
        }

        if menuBar.showDiskFree, let disk = primaryDisk(from: snapshot.disks) {
            parts.append(
                MenuBarPart(
                    text: "DISK \(SystemFormatters.compactBytes(disk.availableBytes))",
                    reservedText: "DISK 9999.9GB",
                    compactText: SystemFormatters.compactBytes(disk.availableBytes),
                    compactReservedText: "9999.9GB",
                    symbolName: "internaldrive",
                    fallbackPrefix: "DISK",
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
                    compactText: "\(prefix)\(Int(battery.chargePercent.rounded()))%",
                    compactReservedText: "*100%",
                    symbolName: "battery.100",
                    fallbackPrefix: "BAT",
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
                        compactText: "↓ \(down) ↑ \(up)",
                        compactReservedText: "↓ \(reservedRate) ↑ \(reservedRate)",
                        symbolName: "network",
                        fallbackPrefix: "NET",
                        group: .network
                    )
                )
            case .uploadOnly:
                parts.append(
                    MenuBarPart(
                        text: "UP \(up)",
                        reservedText: "UP \(reservedRate)",
                        compactText: up,
                        compactReservedText: reservedRate,
                        symbolName: "arrow.up",
                        fallbackPrefix: "UP",
                        group: .network
                    )
                )
            case .downloadOnly:
                parts.append(
                    MenuBarPart(
                        text: "DOWN \(down)",
                        reservedText: "DOWN \(reservedRate)",
                        compactText: down,
                        compactReservedText: reservedRate,
                        symbolName: "arrow.down",
                        fallbackPrefix: "DOWN",
                        group: .network
                    )
                )
            case .combined:
                parts.append(
                    MenuBarPart(
                        text: "NET \(down)",
                        reservedText: "NET \(reservedRate)",
                        compactText: down,
                        compactReservedText: reservedRate,
                        symbolName: "network",
                        fallbackPrefix: "NET",
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
            return [line(from: systemParts, style: .text), line(from: networkParts, style: .text)]
        }

        if parts.count < 3 {
            return [line(from: parts, style: .text)]
        }

        let splitIndex = (parts.count + 1) / 2
        return [
            line(from: Array(parts.prefix(splitIndex)), style: .text),
            line(from: Array(parts.suffix(from: splitIndex)), style: .text)
        ].filter { !$0.segments.isEmpty }
    }

    private static func line(
        from parts: [MenuBarPart],
        style: MenuBarStatusLineStyle
    ) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                switch style {
                case .text:
                    return MenuBarStatusSegment(text: $0.text, reservedText: $0.reservedText)
                case .icon:
                    return MenuBarStatusSegment(
                        text: $0.compactText,
                        reservedText: $0.compactReservedText,
                        symbolName: $0.symbolName,
                        fallbackPrefix: $0.fallbackPrefix
                    )
                }
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
    var compactText: String
    var compactReservedText: String
    var symbolName: String
    var fallbackPrefix: String
    var group: MenuBarPartGroup

    init(
        text: String,
        reservedText: String,
        compactText: String,
        compactReservedText: String,
        symbolName: String,
        fallbackPrefix: String,
        group: MenuBarPartGroup
    ) {
        self.text = text
        self.reservedText = reservedText
        self.compactText = compactText
        self.compactReservedText = compactReservedText
        self.symbolName = symbolName
        self.fallbackPrefix = fallbackPrefix
        self.group = group
    }
}

private enum MenuBarPartGroup {
    case system
    case network
}

private enum MenuBarStatusLineStyle {
    case text
    case icon
}
