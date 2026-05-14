import Foundation

enum CleanDriveFormatter {
    static func bytes(_ bytes: UInt64) -> String {
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
        return String(format: "%.1f %@", value, units[index])
    }
}
