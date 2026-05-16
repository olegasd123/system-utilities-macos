import AppCore
import Foundation

public enum SystemFormatters {
    public static func bytes(
        _ bytes: UInt64,
        decimals: Int = 1,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        AppFormatters.bytes(bytes, decimals: decimals, localization: localization)
    }

    public static func rate(
        _ bytesPerSecond: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        AppFormatters.byteRate(bytesPerSecond, localization: localization)
    }

    public static func temperature(
        _ celsius: Double,
        unit: TemperatureUnit,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        switch unit {
        case .celsius:
            let value = AppFormatters.localizedNumber(
                celsius,
                decimals: 1,
                localization: localization
            )
            return "\(value) \(localization("Unit celsius short"))"
        case .fahrenheit:
            let value = Int((celsius * 9 / 5 + 32).rounded())
            return "\(value) \(localization("Unit fahrenheit short"))"
        }
    }

    public static func duration(
        _ seconds: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        AppFormatters.duration(seconds, localization: localization)
    }

    public static func compactBytes(
        _ bytes: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        AppFormatters.compactBytes(bytes, localization: localization)
    }

    public static func compactRate(
        _ bytesPerSecond: UInt64,
        units: NetworkUnits,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        switch units {
        case .bytesPerSecond:
            return AppFormatters.compactByteRate(bytesPerSecond, localization: localization)
        case .bitsPerSecond:
            return AppFormatters.compactBitRate(
                bytesPerSecond.saturatingMultiply(by: 8),
                localization: localization
            )
        }
    }
}

private extension UInt64 {
    func saturatingMultiply(by value: UInt64) -> UInt64 {
        let (result, overflow) = multipliedReportingOverflow(by: value)
        return overflow ? UInt64.max : result
    }
}
