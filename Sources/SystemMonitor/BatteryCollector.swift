import Foundation
import IOKit.ps

struct BatteryCollector: BatteryMetricSource {
    func sample() -> BatterySample? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any]
            else {
                continue
            }

            guard let currentCapacity = Self.number(description[kIOPSCurrentCapacityKey]),
                  let maxCapacity = Self.number(description[kIOPSMaxCapacityKey]),
                  maxCapacity > 0
            else {
                continue
            }

            let chargePercent = Double(currentCapacity) / Double(maxCapacity) * 100
            return BatterySample(
                chargePercent: chargePercent,
                state: Self.state(description: description, chargePercent: chargePercent),
                timeToFullSecs: Self.secondsFromMinutes(description[kIOPSTimeToFullChargeKey]),
                timeToEmptySecs: Self.secondsFromMinutes(description[kIOPSTimeToEmptyKey]),
                cycleCount: Self.cycleCount(description: description)
            )
        }

        return nil
    }

    private static func state(description: [String: Any], chargePercent: Double) -> BatteryState {
        let isCharging = bool(description[kIOPSIsChargingKey])
        let powerSourceState = description[kIOPSPowerSourceStateKey] as? String

        if chargePercent <= 0 {
            return .empty
        }
        if isCharging {
            return .charging
        }
        if powerSourceState == kIOPSACPowerValue {
            return chargePercent >= 99 ? .full : .unknown
        }
        if powerSourceState == kIOPSBatteryPowerValue {
            return .discharging
        }
        return .unknown
    }

    private static func cycleCount(description: [String: Any]) -> UInt32? {
        number(description["CycleCount"])
            .orElse(number(description["Cycle Count"]))
            .flatMap { UInt32(exactly: $0) }
    }

    private static func secondsFromMinutes(_ value: Any?) -> UInt64? {
        guard let minutes = number(value), minutes > 0 else {
            return nil
        }
        return UInt64(minutes) * 60
    }

    private static func number(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        return false
    }
}

private extension Optional {
    func orElse(_ fallback: @autoclosure () -> Wrapped?) -> Wrapped? {
        self ?? fallback()
    }
}
