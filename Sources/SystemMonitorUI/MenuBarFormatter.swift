import AppCore
import AppUI
import Foundation
import SystemMonitorCore

public enum MenuBarFormatter {
    public static func title(
        snapshot: Snapshot?,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        lines(
            snapshot: snapshot,
            settings: settings,
            temperatureUnit: temperatureUnit,
            localization: localization
        )
            .joined(separator: "  ")
    }

    public static func lines(
        snapshot: Snapshot?,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> [String] {
        statusLines(
            snapshot: snapshot,
            settings: settings,
            temperatureUnit: temperatureUnit,
            localization: localization
        )
            .map(\.text)
    }

    public static func statusLines(
        snapshot: Snapshot?,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> [MenuBarStatusLine] {
        guard hasSelectedMenuBarMetric(settings.menuBar) else {
            return []
        }

        guard let snapshot else {
            let cpuLabel = shortTrayLabel("Tray CPU", localization: localization)
            return settings.menuBar.displayMode == .twoLine
                ? [
                    MenuBarStatusLine(
                        segments: [
                            MenuBarStatusSegment(text: cpuLabel, reservedText: cpuLabel),
                            MenuBarStatusSegment(text: "↕", reservedText: "↕")
                        ]
                    ),
                    MenuBarStatusLine(
                        segments: [
                            MenuBarStatusSegment(text: "--", reservedText: "100%"),
                            MenuBarStatusSegment(
                                text: "--",
                                reservedText: reservedNetworkRate(
                                    units: settings.networkUnits,
                                    localization: localization
                                )
                            )
                        ]
                    )
                ]
                : [MenuBarStatusLine(text: "CPU --  ↕ --")]
        }

        let parts = makeParts(
            snapshot: snapshot,
            settings: settings,
            temperatureUnit: temperatureUnit,
            localization: localization
        )

        guard !parts.isEmpty else {
            return [MenuBarStatusLine(text: localization("System Monitor"))]
        }

        switch settings.menuBar.displayMode {
        case .singleLine:
            return [line(from: parts)]
        case .twoLine:
            return twoLineParts(parts)
        }
    }

    private static func makeParts(
        snapshot: Snapshot,
        settings: SystemMonitorSettings,
        temperatureUnit: TemperatureUnit,
        localization: AppLocalization
    ) -> [MenuBarPart] {
        var parts: [MenuBarPart] = []
        let menuBar = settings.menuBar
        let cpuLabel = shortTrayLabel("Tray CPU", localization: localization)
        let temperatureLabel = shortTrayLabel("Tray temperature", localization: localization)
        let memoryLabel = shortTrayLabel("Tray memory", localization: localization)
        let diskLabel = shortTrayLabel("Tray disk", localization: localization)
        let batteryLabel = shortTrayLabel("Tray battery", localization: localization)
        let networkLabel = shortTrayLabel("Tray network", localization: localization)

        if menuBar.showCpuLoad {
            let value = "\(Int(snapshot.cpu.usagePercent.rounded()))%"
            parts.append(
                MenuBarPart(
                    singleLineText: value,
                    singleLineReservedText: "100%",
                    symbolName: "cpu",
                    fallbackPrefix: "CPU",
                    twoLineTopText: cpuLabel,
                    twoLineTopReservedText: cpuLabel,
                    twoLineBottomText: value,
                    twoLineBottomReservedText: "100%"
                )
            )
        }

        if menuBar.showTemperature, let temperature = snapshot.cpu.temperatureC {
            let value = compactTemperature(
                temperature,
                unit: temperatureUnit,
                localization: localization
            )
            parts.append(
                MenuBarPart(
                    singleLineText: SystemFormatters.temperature(
                        temperature,
                        unit: temperatureUnit,
                        localization: localization
                    ),
                    singleLineReservedText: reservedTemperature(unit: temperatureUnit),
                    symbolName: "thermometer.medium",
                    fallbackPrefix: "TEMP",
                    twoLineTopText: temperatureLabel,
                    twoLineTopReservedText: temperatureLabel,
                    twoLineBottomText: value,
                    twoLineBottomReservedText: compactReservedTemperature(unit: temperatureUnit)
                )
            )
        }

        if menuBar.showMemoryUsage {
            let value = "\(Int(snapshot.memory.usedPercent.rounded()))%"
            parts.append(
                MenuBarPart(
                    singleLineText: value,
                    singleLineReservedText: "100%",
                    symbolName: "memorychip",
                    fallbackPrefix: "RAM",
                    twoLineTopText: memoryLabel,
                    twoLineTopReservedText: memoryLabel,
                    twoLineBottomText: value,
                    twoLineBottomReservedText: "100%"
                )
            )
        }

        if menuBar.showDiskFree, let disk = primaryDisk(from: snapshot.disks) {
            let value = SystemFormatters.compactBytes(
                disk.availableBytes,
                localization: localization
            )
            parts.append(
                MenuBarPart(
                    singleLineText: value,
                    singleLineReservedText: reservedDiskSpace(localization: localization),
                    symbolName: "internaldrive",
                    fallbackPrefix: "DISK",
                    twoLineTopText: diskLabel,
                    twoLineTopReservedText: diskLabel,
                    twoLineBottomText: value,
                    twoLineBottomReservedText: reservedDiskSpace(localization: localization)
                )
            )
        }

        if menuBar.showBattery, let battery = snapshot.battery {
            let percent = "\(Int(battery.chargePercent.rounded()))%"
            let label = battery.state == .charging ? "\(batteryLabel)⚡" : batteryLabel
            parts.append(
                MenuBarPart(
                    singleLineText: percent,
                    singleLineReservedText: "100%",
                    symbolName: BatterySymbol.name(for: battery),
                    fallbackPrefix: "BAT",
                    twoLineTopText: label,
                    twoLineTopReservedText: "\(batteryLabel)⚡",
                    twoLineBottomText: percent,
                    twoLineBottomReservedText: "100%"
                )
            )
        }

        if menuBar.showNetworkSpeed {
            let down = SystemFormatters.compactRate(
                snapshot.network.rxBytesPerSec,
                units: settings.networkUnits,
                localization: localization
            )
            let up = SystemFormatters.compactRate(
                snapshot.network.txBytesPerSec,
                units: settings.networkUnits,
                localization: localization
            )
            let reservedRate = reservedNetworkRate(
                units: settings.networkUnits,
                localization: localization
            )
            switch settings.networkDisplay {
            case .greater:
                let (symbol, rate) = greaterNetworkRate(snapshot.network)
                let value = SystemFormatters.compactRate(
                    rate,
                    units: settings.networkUnits,
                    localization: localization
                )
                parts.append(
                    MenuBarPart(
                        singleLineText: "\(symbol) \(value)",
                        singleLineReservedText: "↓ \(reservedRate)",
                        symbolName: nil,
                        fallbackPrefix: nil,
                        twoLineTopText: "\(networkLabel)\(symbol)",
                        twoLineTopReservedText: "\(networkLabel)↓",
                        twoLineBottomText: value,
                        twoLineBottomReservedText: reservedRate
                    )
                )
            case .uploadAndDownload:
                if menuBar.displayMode == .singleLine {
                    parts.append(
                        MenuBarPart(
                            singleLineText: "↓ \(down)",
                            singleLineReservedText: "↓ \(reservedRate)",
                            symbolName: nil,
                            fallbackPrefix: nil,
                            twoLineTopText: "↓",
                            twoLineTopReservedText: "↓",
                            twoLineBottomText: down,
                            twoLineBottomReservedText: reservedRate
                        )
                    )
                    parts.append(
                        MenuBarPart(
                            singleLineText: "↑ \(up)",
                            singleLineReservedText: "↑ \(reservedRate)",
                            symbolName: nil,
                            fallbackPrefix: nil,
                            twoLineTopText: "↑",
                            twoLineTopReservedText: "↑",
                            twoLineBottomText: up,
                            twoLineBottomReservedText: reservedRate
                        )
                    )
                } else {
                    parts.append(
                        MenuBarPart(
                            singleLineText: "↓ \(down) ↑ \(up)",
                            singleLineReservedText: "↓ \(reservedRate) ↑ \(reservedRate)",
                            symbolName: nil,
                            fallbackPrefix: nil,
                            twoLineTopText: "↓ \(down)",
                            twoLineTopReservedText: "↓ \(reservedRate)",
                            twoLineBottomText: "↑ \(up)",
                            twoLineBottomReservedText: "↑ \(reservedRate)"
                        )
                    )
                }
            case .uploadOnly:
                parts.append(
                    MenuBarPart(
                        singleLineText: "↑ \(up)",
                        singleLineReservedText: "↑ \(reservedRate)",
                        symbolName: nil,
                        fallbackPrefix: nil,
                        twoLineTopText: "\(networkLabel)↑",
                        twoLineTopReservedText: "\(networkLabel)↑",
                        twoLineBottomText: up,
                        twoLineBottomReservedText: reservedRate
                    )
                )
            case .downloadOnly:
                parts.append(
                    MenuBarPart(
                        singleLineText: "↓ \(down)",
                        singleLineReservedText: "↓ \(reservedRate)",
                        symbolName: nil,
                        fallbackPrefix: nil,
                        twoLineTopText: "\(networkLabel)↓",
                        twoLineTopReservedText: "\(networkLabel)↓",
                        twoLineBottomText: down,
                        twoLineBottomReservedText: reservedRate
                    )
                )
            case .combined:
                let combined = SystemFormatters.compactRate(
                    combinedNetworkBytesPerSecond(snapshot.network),
                    units: settings.networkUnits,
                    localization: localization
                )
                parts.append(
                    MenuBarPart(
                        singleLineText: "↕ \(combined)",
                        singleLineReservedText: "↕ \(reservedRate)",
                        symbolName: nil,
                        fallbackPrefix: nil,
                        twoLineTopText: "\(networkLabel)↕",
                        twoLineTopReservedText: "\(networkLabel)↕",
                        twoLineBottomText: combined,
                        twoLineBottomReservedText: reservedRate
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
        from parts: [MenuBarPart]
    ) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                MenuBarStatusSegment(
                    text: $0.singleLineText,
                    reservedText: $0.singleLineReservedText,
                    symbolName: $0.symbolName,
                    fallbackPrefix: $0.fallbackPrefix
                )
            }
        )
    }

    private static func twoLineLabels(from parts: [MenuBarPart]) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                MenuBarStatusSegment(
                    text: $0.twoLineTopText,
                    reservedText: $0.twoLineTopReservedText
                )
            }
        )
    }

    private static func twoLineValues(from parts: [MenuBarPart]) -> MenuBarStatusLine {
        MenuBarStatusLine(
            segments: parts.map {
                MenuBarStatusSegment(
                    text: $0.twoLineBottomText,
                    reservedText: $0.twoLineBottomReservedText
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

    private static func reservedTemperature(unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return "100.0 C"
        case .fahrenheit:
            return "212 F"
        }
    }

    private static func compactTemperature(
        _ celsius: Double,
        unit: TemperatureUnit,
        localization: AppLocalization
    ) -> String {
        switch unit {
        case .celsius:
            return "\(Int(celsius.rounded()))\(localization("Unit celsius short"))"
        case .fahrenheit:
            return "\(Int((celsius * 9 / 5 + 32).rounded()))\(localization("Unit fahrenheit short"))"
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

    private static func reservedDiskSpace(localization: AppLocalization) -> String {
        "9999.9\(localization("Unit gigabyte compact"))"
    }

    private static func reservedNetworkRate(
        units: NetworkUnits,
        localization: AppLocalization
    ) -> String {
        switch units {
        case .bytesPerSecond:
            return "999.9\(localization("Unit megabyte compact"))"
        case .bitsPerSecond:
            return "999.9\(localization("Unit megabit compact"))"
        }
    }

    private static func combinedNetworkBytesPerSecond(_ network: NetworkSample) -> UInt64 {
        let (total, overflow) = network.rxBytesPerSec.addingReportingOverflow(network.txBytesPerSec)
        return overflow ? UInt64.max : total
    }

    private static func greaterNetworkRate(_ network: NetworkSample) -> (symbol: String, rate: UInt64) {
        if network.txBytesPerSec > network.rxBytesPerSec {
            return ("↑", network.txBytesPerSec)
        }

        return ("↓", network.rxBytesPerSec)
    }

    private static func shortTrayLabel(_ key: String, localization: AppLocalization) -> String {
        String(localization(key).prefix(4))
    }
}

private struct MenuBarPart {
    var singleLineText: String
    var singleLineReservedText: String
    var symbolName: String?
    var fallbackPrefix: String?
    var twoLineTopText: String
    var twoLineTopReservedText: String
    var twoLineBottomText: String
    var twoLineBottomReservedText: String

    init(
        singleLineText: String,
        singleLineReservedText: String,
        symbolName: String?,
        fallbackPrefix: String?,
        twoLineTopText: String,
        twoLineTopReservedText: String,
        twoLineBottomText: String,
        twoLineBottomReservedText: String
    ) {
        self.singleLineText = singleLineText
        self.singleLineReservedText = singleLineReservedText
        self.symbolName = symbolName
        self.fallbackPrefix = fallbackPrefix
        self.twoLineTopText = twoLineTopText
        self.twoLineTopReservedText = twoLineTopReservedText
        self.twoLineBottomText = twoLineBottomText
        self.twoLineBottomReservedText = twoLineBottomReservedText
    }
}
