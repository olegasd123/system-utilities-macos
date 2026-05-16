import Foundation

public enum AppFormatters {
    public static func bytes(
        _ bytes: UInt64,
        decimals: Int = 1,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if bytes < 1024 {
            return normalUnit(bytes, "Unit byte", localization: localization)
        }

        let unitKeys = ["Unit kilobyte", "Unit megabyte", "Unit gigabyte", "Unit terabyte"]
        let (value, unitKey) = scaledBinaryValue(Double(bytes), unitKeys: unitKeys)
        return normalUnit(value, unitKey, decimals: decimals, localization: localization)
    }

    public static func compactBytes(
        _ bytes: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if bytes < 1024 {
            return compactUnit(bytes, "Unit byte compact", localization: localization)
        }
        if bytes < 1024 * 1024 {
            return compactUnit(bytes / 1024, "Unit kilobyte compact", localization: localization)
        }
        if bytes < 1024 * 1024 * 1024 {
            return compactUnit(
                Double(bytes) / 1024 / 1024,
                "Unit megabyte compact",
                localization: localization
            )
        }
        return compactUnit(
            Double(bytes) / 1024 / 1024 / 1024,
            "Unit gigabyte compact",
            localization: localization
        )
    }

    public static func byteRate(
        _ bytesPerSecond: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if bytesPerSecond < 1024 {
            return normalUnit(bytesPerSecond, "Unit byte per second", localization: localization)
        }
        if bytesPerSecond < 1024 * 1024 {
            return normalUnit(
                Double(bytesPerSecond) / 1024,
                "Unit kilobyte per second",
                localization: localization
            )
        }
        return normalUnit(
            Double(bytesPerSecond) / 1024 / 1024,
            "Unit megabyte per second",
            localization: localization
        )
    }

    public static func compactByteRate(
        _ bytesPerSecond: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if bytesPerSecond < 1024 {
            return compactUnit(bytesPerSecond, "Unit byte compact", localization: localization)
        }
        if bytesPerSecond < 1024 * 1024 {
            return compactUnit(
                Double(bytesPerSecond) / 1024,
                "Unit kilobyte compact",
                localization: localization
            )
        }
        return compactUnit(
            Double(bytesPerSecond) / 1024 / 1024,
            "Unit megabyte compact",
            localization: localization
        )
    }

    public static func compactBitRate(
        _ bitsPerSecond: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if bitsPerSecond < 1000 {
            return compactUnit(bitsPerSecond, "Unit bit compact", localization: localization)
        }
        if bitsPerSecond < 1000 * 1000 {
            return compactUnit(
                Double(bitsPerSecond) / 1000,
                "Unit kilobit compact",
                localization: localization
            )
        }
        return compactUnit(
            Double(bitsPerSecond) / 1000 / 1000,
            "Unit megabit compact",
            localization: localization
        )
    }

    public static func duration(
        _ seconds: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if seconds < 60 {
            return durationPart(seconds, "Unit second short", localization: localization)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return durationPart(minutes, "Unit minute short", localization: localization)
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            let hourText = durationPart(hours, "Unit hour short", localization: localization)
            guard remainingMinutes > 0 else {
                return hourText
            }
            return "\(hourText) \(durationPart(remainingMinutes, "Unit minute short", localization: localization))"
        }

        let days = hours / 24
        return [
            durationPart(days, "Unit day short", localization: localization),
            durationPart(hours % 24, "Unit hour short", localization: localization)
        ].joined(separator: " ")
    }

    public static func localizedNumber(
        _ value: Double,
        decimals: Int,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        String(format: "%.\(decimals)f", locale: localization.locale, value)
    }

    private static func scaledBinaryValue(
        _ bytes: Double,
        unitKeys: [String]
    ) -> (value: Double, unitKey: String) {
        var value = bytes / 1024
        var index = 0
        while value >= 1024, index < unitKeys.count - 1 {
            value /= 1024
            index += 1
        }
        return (value, unitKeys[index])
    }

    private static func normalUnit(
        _ value: UInt64,
        _ unitKey: String,
        localization: AppLocalization
    ) -> String {
        "\(value) \(localization(unitKey))"
    }

    private static func normalUnit(
        _ value: Double,
        _ unitKey: String,
        decimals: Int = 1,
        localization: AppLocalization
    ) -> String {
        "\(localizedNumber(value, decimals: decimals, localization: localization)) \(localization(unitKey))"
    }

    private static func compactUnit(
        _ value: UInt64,
        _ unitKey: String,
        localization: AppLocalization
    ) -> String {
        "\(value)\(localization(unitKey))"
    }

    private static func compactUnit(
        _ value: Double,
        _ unitKey: String,
        localization: AppLocalization
    ) -> String {
        "\(localizedNumber(value, decimals: 1, localization: localization))\(localization(unitKey))"
    }

    private static func durationPart(
        _ value: UInt64,
        _ unitKey: String,
        localization: AppLocalization
    ) -> String {
        "\(value)\(localization("Duration unit separator"))\(localization(unitKey))"
    }
}
