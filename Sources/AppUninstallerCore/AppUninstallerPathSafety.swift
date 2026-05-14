import Foundation

public struct AppUninstallerPathSafety: Sendable {
    private let appBundleURL: URL
    private let scanRoots: [URL]
    private let directAllowedPaths: Set<String>
    private let deniedPaths: Set<String>

    public init(
        appBundleURL: URL,
        scanRoots: [URL],
        directAllowedPaths: [URL] = [],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.appBundleURL = appBundleURL.standardizedFileURL
        self.scanRoots = scanRoots.map(\.standardizedFileURL)
        self.directAllowedPaths = Set(directAllowedPaths.map { $0.standardizedFileURL.path })
        self.deniedPaths = Set([
            URL(fileURLWithPath: "/").standardizedFileURL.path,
            URL(fileURLWithPath: "/System").standardizedFileURL.path,
            URL(fileURLWithPath: "/Library").standardizedFileURL.path,
            homeDirectory.standardizedFileURL.path,
            homeDirectory.appendingPathComponent("Library", isDirectory: true)
                .standardizedFileURL.path
        ])
    }

    public func canShowCandidate(_ url: URL) -> Bool {
        canRemove(url)
    }

    public func canRemove(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        let path = standardized.path
        guard !deniedPaths.contains(path) else {
            return false
        }

        if path == appBundleURL.path {
            return true
        }
        if directAllowedPaths.contains(path) {
            return true
        }

        return scanRoots.contains { root in
            isChild(path, of: root.path)
        }
    }

    private func isChild(_ path: String, of rootPath: String) -> Bool {
        guard path != rootPath else {
            return false
        }
        let normalizedRoot = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        return path.hasPrefix(normalizedRoot)
    }
}
