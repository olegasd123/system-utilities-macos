import SystemMonitorCore

enum BatterySymbol {
    static func name(for battery: BatterySample) -> String {
        if battery.state == .charging {
            return "battery.100.bolt"
        }

        return levelName(for: battery.chargePercent)
    }

    private static func levelName(for chargePercent: Double) -> String {
        let percent = min(100, max(0, chargePercent))

        switch percent {
        case ..<12.5:
            return "battery.0"
        case ..<37.5:
            return "battery.25"
        case ..<62.5:
            return "battery.50"
        case ..<87.5:
            return "battery.75"
        default:
            return "battery.100"
        }
    }
}
