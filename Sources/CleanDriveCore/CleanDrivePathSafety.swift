import Foundation

enum CleanDrivePathSafety {
    static func canScan(_ url: URL) -> Bool {
        canTouch(url)
    }

    static func canReclaim(_ url: URL) -> Bool {
        canTouch(url)
    }

    static func canUseCustomFolder(_ url: URL, homeDirectory: URL) -> Bool {
        let folderPath = url.standardizedFileURL.path
        guard canTouch(url), !isBroadRoot(folderPath) else {
            return false
        }

        let homePath = homeDirectory.standardizedFileURL.path
        if folderPath == homePath {
            return false
        }

        let components = url.standardizedFileURL.pathComponents
        if components.first == "/", components.dropFirst().first == "Volumes" {
            return components.count > 3
        }
        return true
    }

    private static func isBroadRoot(_ path: String) -> Bool {
        if URL(fileURLWithPath: path).standardizedFileURL.pathComponents.count <= 2 {
            return true
        }
        return path == "/private" || path == "/private/tmp" || path == "/private/var"
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
