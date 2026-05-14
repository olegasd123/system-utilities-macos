import Foundation

enum AppUninstallerFormatter {
    static func bytes(_ bytes: UInt64) -> String {
        if bytes == 0 {
            return "0 KB"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
