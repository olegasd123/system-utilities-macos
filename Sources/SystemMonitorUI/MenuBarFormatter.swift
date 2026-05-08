import AppCore
import AppUI
import Foundation
import SystemMonitorCore

public enum MenuBarFormatter {
    public static func title(
        snapshot: Snapshot?,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit
    ) -> String {
        lines(snapshot: snapshot, settings: settings, temperatureUnit: temperatureUnit)
            .joined(separator: "  ")
    }

    public static func lines(
        snapshot: Snapshot?,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit
    ) -> [String] {
        statusLines(snapshot: snapshot, settings: settings, temperatureUnit: temperatureUnit)
            .map(\.text)
    }

    public static func statusLines(
        snapshot: Snapshot?,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit
    ) -> [MenuBarStatusLine] {
        guard hasSelectedMenuBarMetric(settings.menuBar) else {
            return []
        }

        guard let snapshot else {
            return settings.menuBar.displayMode == .twoLine
                ? [
                    MenuBarStatusLine(
                        segments: [
                            MenuBarStatusSegment(text: "CPU", reservedText: "CPU"),
                            MenuBarStatusSegment(text: "NET", reservedText: "NET")
                        ]
                    ),
                    MenuBarStatusLine(
                        segments: [
                            MenuBarStatusSegment(text: "--", reservedText: "100%"),
                            MenuBarStatusSegment(text: "--", reservedText: "999.9MB/s")
                        ]
                    )
                ]
                : [MenuBarStatusLine(text: "CPU --  NET --")]
        }

        let parts = makeParts(
            snapshot: snapshot,
            settings: settings,
            temperatureUnit: temperatureUnit
        )

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

    private static func makeParts(
        snapshot: Snapshot,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit
    ) -> [MenuBarPart] {
        var parts: [MenuBarPart] = []
        let menuBar = settings.menuBar

        if menuBar.showCpuLoad {
            let value = "\(Int(snapshot.cpu.usagePercent.rounded()))%"
            parts.append(
                MenuBarPart(
                    label: "CPU",
                    value: value,
                    reservedValue: "100%",
                    text: "CPU \(value)",
                    reservedText: "CPU 100%",
                    compactText: value,
                    compactReservedText: "100%",
                    symbolName: "cpu",
                    fallbackPrefix: "CPU"
                )
            )
        }

        if menuBar.showTemperature, let temperature = snapshot.cpu.temperatureC {
            let value = compactTemperature(temperature, unit: temperatureUnit)
            parts.append(
                MenuBarPart(
                    label: "TEMP",
                    value: value,
                    reservedValue: compactReservedTemperature(unit: temperatureUnit),
                    text: "TEMP \(SystemFormatters.temperature(temperature, unit: temperatureUnit))",
                    reservedText: "TEMP \(reservedTemperature(unit: temperatureUnit))",
                    compactText: SystemFormatters.temperature(temperature, unit: temperatureUnit),
                    compactReservedText: reservedTemperature(unit: temperatureUnit),
                    symbolName: "thermometer.medium",
                    fallbackPrefix: "TEMP"
                )
            )
        }

        if menuBar.showMemoryUsage {
            let value = "\(Int(snapshot.memory.usedPercent.rounded()))%"
            parts.append(
                MenuBarPart(
                    label: "RAM",
                    value: value,
                    reservedValue: "100%",
                    text: "RAM \(value)",
                    reservedText: "RAM 100%",
                    compactText: value,
                    compactReservedText: "100%",
                    symbolName: "memorychip",
                    fallbackPrefix: "RAM"
                )
            )
        }

        if menuBar.showDiskFree, let disk = primaryDisk(from: snapshot.disks) {
            let value = SystemFormatters.compactBytes(disk.availableBytes)
            parts.append(
                MenuBarPart(
                    label: "DISK",
                    value: value,
                    reservedValue: "9999.9GB",
                    text: "DISK \(value)",
                    reservedText: "DISK 9999.9GB",
                    compactText: value,
                    compactReservedText: "9999.9GB",
                    symbolName: "internaldrive",
                    fallbackPrefix: "DISK"
                )
            )
        }

        if menuBar.showBattery, let battery = snapshot.battery {
            let prefix = isOnPower(battery.state) ? "*" : ""
            let percent = "\(Int(battery.chargePercent.rounded()))%"
            let value = "\(prefix)\(percent)"
            parts.append(
                MenuBarPart(
                    label: "BAT",
                    value: value,
                    reservedValue: "*100%",
                    text: "BAT \(value)",
                    reservedText: "BAT *100%",
                    compactText: percent,
                    compactReservedText: "100%",
                    symbolName: BatterySymbol.name(for: battery),
                    fallbackPrefix: "BAT"
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
                if menuBar.displayMode == .singleLine {
                    parts.append(
                        MenuBarPart(
                            label: "↓",
                            value: down,
                            reservedValue: reservedRate,
                            text: "↓ \(down)",
                            reservedText: "↓ \(reservedRate)",
                            compactText: "↓ \(down)",
                            compactReservedText: "↓ \(reservedRate)",
                            symbolName: nil,
                            fallbackPrefix: nil
                        )
                    )
                    parts.append(
                        MenuBarPart(
                            label: "↑",
                            value: up,
                            reservedValue: reservedRate,
                            text: "↑ \(up)",
                            reservedText: "↑ \(reservedRate)",
                            compactText: "↑ \(up)",
                            compactReservedText: "↑ \(reservedRate)",
                            symbolName: nil,
                            fallbackPrefix: nil
                        )
                    )
                } else {
                    parts.append(
                        MenuBarPart(
                            label: "↓",
                            value: "↑ \(up)",
                            reservedValue: "↑ \(reservedRate)",
                            text: "↓ \(down) ↑ \(up)",
                            reservedText: "↓ \(reservedRate) ↑ \(reservedRate)",
                            compactText: "↓ \(down) ↑ \(up)",
                            compactReservedText: "↓ \(reservedRate) ↑ \(reservedRate)",
                            symbolName: nil,
                            fallbackPrefix: nil,
                            twoLineTopText: "↓ \(down)",
                            twoLineReservedTopText: "↓ \(reservedRate)"
                        )
                    )
                }
            case .uploadOnly:
                parts.append(
                    MenuBarPart(
                        label: "↑",
                        value: up,
                        reservedValue: reservedRate,
                        text: "UP \(up)",
                        reservedText: "UP \(reservedRate)",
                        compactText: up,
                        compactReservedText: reservedRate,
                        symbolName: "arrow.up",
                        fallbackPrefix: "UP"
                    )
                )
            case .downloadOnly:
                parts.append(
                    MenuBarPart(
                        label: "↓",
                        value: down,
                        reservedValue: reservedRate,
                        text: "DOWN \(down)",
                        reservedText: "DOWN \(reservedRate)",
                        compactText: down,
                        compactReservedText: reservedRate,
                        symbolName: "arrow.down",
                        fallbackPrefix: "DOWN"
                    )
                )
            case .combined:
                parts.append(
                    MenuBarPart(
                        label: "↓",
                        value: down,
                        reservedValue: reservedRate,
                        text: "NET \(down)",
                        reservedText: "NET \(reservedRate)",
                        compactText: down,
                        compactReservedText: reservedRate,
                        symbolName: nil,
                        fallbackPrefix: nil
                    )
                )
            }
        }

        return parts
    }

    private static func twoLineParts(_ parts: [MenuBarPart]) -> [MenuBarStatusLine] {
        return [
            twoLineLabels(from: parts),
            twoLineValues(from: parts)
        ]
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

    private static func twoLineLabels(from parts: [MenuBarPart]) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                MenuBarStatusSegment(
                    text: $0.twoLineTopText,
                    reservedText: $0.twoLineReservedText
                )
            }
        )
    }

    private static func twoLineValues(from parts: [MenuBarPart]) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                MenuBarStatusSegment(
                    text: $0.value,
                    reservedText: $0.twoLineReservedText
                )
            }
        )
    }

    private static func primaryDisk(from disks: [DiskSample]) -> DiskSample? {
        disks.first { $0.mountPoint == "/System/Volumes/Data" }
            ?? disks.first { $0.mountPoint == "/" }
            ?? disks.first { !$0.isRemovable }
            ?? disks.first
    }

    private static func hasSelectedMenuBarMetric(_ menuBar: MenuBarSettings) -> Bool {
        menuBar.showCpuLoad
            || menuBar.showTemperature
            || menuBar.showMemoryUsage
            || menuBar.showDiskFree
            || menuBar.showBattery
            || menuBar.showNetworkSpeed
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

    private static func compactTemperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return "\(Int(celsius.rounded()))C"
        case .fahrenheit:
            return "\(Int((celsius * 9 / 5 + 32).rounded()))F"
        }
    }

    private static func compactReservedTemperature(unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return "100C"
        case .fahrenheit:
            return "212F"
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
    var label: String
    var value: String
    var reservedValue: String
    var text: String
    var reservedText: String
    var compactText: String
    var compactReservedText: String
    var symbolName: String?
    var fallbackPrefix: String?
    var twoLineTopText: String
    var twoLineReservedTopText: String

    init(
        label: String,
        value: String,
        reservedValue: String,
        text: String,
        reservedText: String,
        compactText: String,
        compactReservedText: String,
        symbolName: String?,
        fallbackPrefix: String?,
        twoLineTopText: String? = nil,
        twoLineReservedTopText: String? = nil
    ) {
        self.label = label
        self.value = value
        self.reservedValue = reservedValue
        self.text = text
        self.reservedText = reservedText
        self.compactText = compactText
        self.compactReservedText = compactReservedText
        self.symbolName = symbolName
        self.fallbackPrefix = fallbackPrefix
        self.twoLineTopText = twoLineTopText ?? label
        self.twoLineReservedTopText = twoLineReservedTopText ?? label
    }

    var twoLineReservedText: String {
        [twoLineReservedTopText, reservedValue]
            .max { $0.count < $1.count } ?? reservedValue
    }
}

private enum MenuBarStatusLineStyle {
    case text
    case icon
}
