import Foundation

enum CleanDrivePathSafety {
    static func canScan(_ url: URL) -> Bool {
        canTouch(url)
    }

    static func canReclaim(_ url: URL) -> Bool {
        canTouch(url)
    }

    private static func canTouch(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        if path == "/System" || path.hasPrefix("/System/") {
            return false
        }
        if path == "/Library/Apple" || path.hasPrefix("/Library/Apple/") {
            return false
        }
        if path == "/private/var/db" || path.hasPrefix("/private/var/db/") {
            return false
        }
        if path.contains("/iCloud Drive/") {
            return false
        }
        if path.contains("/Library/Mobile Documents/") {
            return false
        }
        return true
    }
}
