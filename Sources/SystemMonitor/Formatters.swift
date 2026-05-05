import Foundation

enum SystemFormatters {
    static func bytes(_ bytes: UInt64, decimals: Int = 1) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }

        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1024
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%.\(decimals)f %@", value, units[index])
    }

    static func rate(_ bytesPerSecond: UInt64) -> String {
        if bytesPerSecond < 1024 {
            return "\(bytesPerSecond) B/s"
        }
        if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", Double(bytesPerSecond) / 1024)
        }
        return String(format: "%.1f MB/s", Double(bytesPerSecond) / 1024 / 1024)
    }

    static func temperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return String(format: "%.1f C", celsius)
        case .fahrenheit:
            return "\(Int((celsius * 9 / 5 + 32).rounded())) F"
        }
    }

    static func duration(_ seconds: UInt64) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }

        let days = hours / 24
        return "\(days)d \(hours % 24)h"
    }

    static func compactBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        }
        if bytes < 1024 * 1024 {
            return "\(bytes / 1024)KB"
        }
        if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1fMB", Double(bytes) / 1024 / 1024)
        }
        return String(format: "%.1fGB", Double(bytes) / 1024 / 1024 / 1024)
    }

    static func compactRate(_ bytesPerSecond: UInt64, units: NetworkUnits) -> String {
        switch units {
        case .bytesPerSecond:
            return compactByteRate(bytesPerSecond)
        case .bitsPerSecond:
            return compactBitRate(bytesPerSecond.saturatingMultiply(by: 8))
        }
    }

    private static func compactByteRate(_ bytesPerSecond: UInt64) -> String {
        if bytesPerSecond < 1024 {
            return "\(bytesPerSecond)B/s"
        }
        if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1fKB/s", Double(bytesPerSecond) / 1024)
        }
        return String(format: "%.1fMB/s", Double(bytesPerSecond) / 1024 / 1024)
    }

    private static func compactBitRate(_ bitsPerSecond: UInt64) -> String {
        if bitsPerSecond < 1000 {
            return "\(bitsPerSecond)b/s"
        }
        if bitsPerSecond < 1000 * 1000 {
            return String(format: "%.1fKb/s", Double(bitsPerSecond) / 1000)
        }
        return String(format: "%.1fMb/s", Double(bitsPerSecond) / 1000 / 1000)
    }
}

private extension UInt64 {
    func saturatingMultiply(by value: UInt64) -> UInt64 {
        let (result, overflow) = multipliedReportingOverflow(by: value)
        return overflow ? UInt64.max : result
    }
}
