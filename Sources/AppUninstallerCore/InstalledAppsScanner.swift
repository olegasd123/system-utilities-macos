import Foundation

public struct InstalledAppsScanner: Sendable {
    private let searchRoots: [URL]
    private let ownBundleIdentifier: String?
    private let protectedBundleIdentifiers: Set<String>

    public init(
        searchRoots: [URL] = InstalledAppsScanner.defaultSearchRoots(),
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        protectedBundleIdentifiers: Set<String> = []
    ) {
        self.searchRoots = searchRoots
        self.ownBundleIdentifier = ownBundleIdentifier
        self.protectedBundleIdentifiers = protectedBundleIdentifiers
    }

    public static func defaultSearchRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    public func scan() throws -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seenPaths: Set<String> = []

        for root in searchRoots {
            try Task.checkCancellation()
            guard FileManager.default.fileExists(atPath: root.path) else {
                continue
            }

            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                continue
            }

            for child in children where child.pathExtension == "app" {
                try Task.checkCancellation()
                let standardizedPath = child.standardizedFileURL.path
                guard !seenPaths.contains(standardizedPath) else {
                    continue
                }
                seenPaths.insert(standardizedPath)
                if let app = installedApp(at: child, sourceRoot: root), !app.isSystem {
                    apps.append(app)
                }
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func installedApp(at bundleURL: URL, sourceRoot: URL) -> InstalledApp? {
        let infoURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard
            let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
            let bundleIdentifier = info["CFBundleIdentifier"] as? String,
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        let displayName = info["CFBundleDisplayName"] as? String
        let bundleName = info["CFBundleName"] as? String
        let fileName = bundleURL.deletingPathExtension().lastPathComponent
        let name = [displayName, bundleName, fileName].compactMap { value in
            value?.isEmpty == false ? value : nil
        }.first ?? fileName

        let iconURL = iconURL(from: info, bundleURL: bundleURL)
        let appGroups = info["com.apple.security.application-groups"] as? [String] ?? []
        let isSystem = isSystemApp(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL)

        return InstalledApp(
            bundleIdentifier: bundleIdentifier,
            name: name,
            version: info["CFBundleShortVersionString"] as? String,
            iconURL: iconURL,
            bundleURL: bundleURL,
            sourceLocation: sourceRoot.path,
            executableName: info["CFBundleExecutable"] as? String,
            isSystem: isSystem,
            appGroupIdentifiers: appGroups
        )
    }

    private func iconURL(from info: [String: Any], bundleURL: URL) -> URL? {
        guard var iconName = info["CFBundleIconFile"] as? String, !iconName.isEmpty else {
            return nil
        }
        if URL(fileURLWithPath: iconName).pathExtension.isEmpty {
            iconName += ".icns"
        }
        return bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(iconName)
    }

    private func isSystemApp(bundleIdentifier: String, bundleURL: URL) -> Bool {
        let path = bundleURL.standardizedFileURL.path
        if path.hasPrefix("/System/") {
            return true
        }
        if bundleIdentifier == ownBundleIdentifier {
            return true
        }
        return protectedBundleIdentifiers.contains(bundleIdentifier)
    }

}
