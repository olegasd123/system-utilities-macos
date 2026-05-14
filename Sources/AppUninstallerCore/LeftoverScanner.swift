import AppCore
import Foundation

public struct LeftoverScanner: Sendable {
    private let homeDirectory: URL
    private let temporaryDirectory: URL
    private let userScanRoots: [URL]?
    private let systemScanRoots: [URL]?

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        userScanRoots: [URL]? = nil,
        systemScanRoots: [URL]? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.temporaryDirectory = temporaryDirectory
        self.userScanRoots = userScanRoots
        self.systemScanRoots = systemScanRoots
    }

    public func scan(
        app: InstalledApp,
        settings: AppUninstallerSettings = .defaultValue
    ) throws -> LeftoverScanResult {
        let roots = scanRoots(includeSystem: settings.includeSystemLibraryPaths)
        let safety = AppUninstallerPathSafety(
            appBundleURL: app.bundleURL,
            scanRoots: roots,
            homeDirectory: homeDirectory
        )
        var notes: [String] = []
        var leftovers: [LeftoverCandidate] = []
        let appGroupIdentifiers = uniqueStrings(
            app.appGroupIdentifiers + entitlementAppGroups(at: app.bundleURL)
        )

        let bundle = try bundleCandidate(for: app)

        for root in roots {
            try Task.checkCancellation()
            guard FileManager.default.fileExists(atPath: root.path) else {
                continue
            }

            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: FileSizeReader.defaultResourceKeys,
                    options: []
                )
            } catch {
                notes.append("Skipped \(root.path): \(error.localizedDescription)")
                continue
            }

            for child in children {
                try Task.checkCancellation()
                guard
                    let confidence = matchConfidence(
                        for: child,
                        app: app,
                        root: root,
                        appGroupIdentifiers: appGroupIdentifiers,
                        temporaryDirectory: temporaryDirectory,
                        includeNameHeuristicMatches: settings.includeNameHeuristicMatches
                    ),
                    safety.canShowCandidate(child)
                else {
                    continue
                }

                do {
                    leftovers.append(
                        try candidate(for: child, confidence: confidence)
                    )
                } catch {
                    notes.append("Skipped \(child.path): \(error.localizedDescription)")
                }
            }
        }

        let unique = Dictionary(grouping: leftovers) { $0.url.standardizedFileURL.path }
            .compactMap { $0.value.first }
            .sorted {
                if $0.confidence.rawValue == $1.confidence.rawValue {
                    return $0.url.path.localizedCaseInsensitiveCompare($1.url.path) == .orderedAscending
                }
                return confidenceRank($0.confidence) < confidenceRank($1.confidence)
            }

        if !appGroupIdentifiers.isEmpty {
            notes.append("App group containers were matched from app metadata.")
        } else if roots.contains(where: { $0.lastPathComponent == "Group Containers" }) {
            notes.append("Group containers skipped because app group data was unavailable.")
        }

        return LeftoverScanResult(
            app: app,
            bundle: bundle,
            leftovers: unique,
            notes: notes
        )
    }

    public func scanRoots(includeSystem: Bool) -> [URL] {
        var roots = userScanRoots ?? Self.defaultUserScanRoots(
            homeDirectory: homeDirectory,
            temporaryDirectory: temporaryDirectory
        )
        if includeSystem {
            roots += systemScanRoots ?? Self.defaultSystemScanRoots()
        }
        return roots
    }

    public static func defaultUserScanRoots(homeDirectory: URL) -> [URL] {
        defaultUserScanRoots(
            homeDirectory: homeDirectory,
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
    }

    public static func defaultUserScanRoots(
        homeDirectory: URL,
        temporaryDirectory: URL
    ) -> [URL] {
        let library = homeDirectory.appendingPathComponent("Library", isDirectory: true)
        let libraryRoots = [
            "Application Support",
            "Application Support/CrashReporter",
            "Caches",
            "Preferences",
            "Logs",
            "Containers",
            "Group Containers",
            "Saved Application State",
            "HTTPStorages",
            "WebKit",
            "Cookies",
            "Application Scripts",
            "LaunchAgents"
        ].map { library.appendingPathComponent($0, isDirectory: true) }
        return libraryRoots + [temporaryDirectory]
    }

    public static func defaultSystemScanRoots() -> [URL] {
        let library = URL(fileURLWithPath: "/Library", isDirectory: true)
        return [
            "Application Support",
            "Application Support/CrashReporter",
            "Caches",
            "Preferences",
            "Logs",
            "LaunchAgents",
            "LaunchDaemons",
            "PrivilegedHelperTools"
        ].map { library.appendingPathComponent($0, isDirectory: true) }
    }

    private func bundleCandidate(for app: InstalledApp) throws -> LeftoverCandidate {
        let size: UInt64
        if app.bundleSize > 0 {
            size = app.bundleSize
        } else {
            size = (try? FileSizeReader.recursiveLogicalSize(of: app.bundleURL)) ?? 0
        }
        return LeftoverCandidate(
            url: app.bundleURL,
            size: size,
            kind: .directory,
            confidence: .appBundle
        )
    }

    private func candidate(
        for url: URL,
        confidence: LeftoverConfidence
    ) throws -> LeftoverCandidate {
        let kind = try leftoverKind(at: url)
        let size: UInt64
        switch kind {
        case .file, .symlink:
            size = try FileSizeReader.logicalSize(of: url)
        case .directory:
            size = try FileSizeReader.recursiveLogicalSize(of: url)
        }
        return LeftoverCandidate(url: url, size: size, kind: kind, confidence: confidence)
    }

    private func leftoverKind(at url: URL) throws -> LeftoverKind {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ])
        if values.isSymbolicLink == true {
            return .symlink
        }
        if values.isDirectory == true {
            return .directory
        }
        if values.isRegularFile == true {
            return .file
        }
        return .file
    }

    private func matchConfidence(
        for url: URL,
        app: InstalledApp,
        root: URL,
        appGroupIdentifiers: [String],
        temporaryDirectory: URL,
        includeNameHeuristicMatches: Bool
    ) -> LeftoverConfidence? {
        let name = url.lastPathComponent
        if root.lastPathComponent == "Group Containers" {
            return appGroupIdentifiers.contains(name) ? .exactBundleID : nil
        }

        if root.lastPathComponent == "CrashReporter" {
            return crashReporterMatchConfidence(
                for: name,
                app: app,
                includeNameHeuristicMatches: includeNameHeuristicMatches
            )
        }

        let plistTrimmed = name.hasSuffix(".plist") ? String(name.dropLast(6)) : name

        if name == app.bundleIdentifier || plistTrimmed == app.bundleIdentifier {
            return .exactBundleID
        }
        if name.hasPrefix("\(app.bundleIdentifier).")
            || plistTrimmed.hasPrefix("\(app.bundleIdentifier).") {
            return .bundleIDPrefix
        }
        if isLaunchServiceRoot(root), plistTrimmed.hasPrefix(app.bundleIdentifier) {
            return .bundleIDPrefix
        }

        guard includeNameHeuristicMatches else {
            return nil
        }

        if root.standardizedFileURL.path == temporaryDirectory.standardizedFileURL.path {
            return temporaryMatchConfidence(for: name, app: app)
        }

        let normalizedName = normalizeName(name)
        let normalizedAppName = normalizeName(app.name)
        if normalizedName == normalizedAppName {
            return .nameHeuristic
        }
        if let executableName = app.executableName,
           normalizedName == normalizeName(executableName) {
            return .nameHeuristic
        }
        return nil
    }

    private func temporaryMatchConfidence(
        for name: String,
        app: InstalledApp
    ) -> LeftoverConfidence? {
        let normalizedName = normalizeName(name)
        let appNames = heuristicNames(for: app)
        return appNames.contains { candidate in
            normalizedName == candidate || normalizedName.hasPrefix(candidate)
        } ? .nameHeuristic : nil
    }

    private func crashReporterMatchConfidence(
        for name: String,
        app: InstalledApp,
        includeNameHeuristicMatches: Bool
    ) -> LeftoverConfidence? {
        guard includeNameHeuristicMatches else {
            return nil
        }

        let plistTrimmed = name.hasSuffix(".plist") ? String(name.dropLast(6)) : name
        let processName = plistTrimmed.split(separator: "_", maxSplits: 1).first.map(String.init)
            ?? plistTrimmed
        let normalizedProcessName = normalizeName(processName)

        return crashReporterProcessNames(for: app).contains(normalizedProcessName)
            ? .nameHeuristic
            : nil
    }

    private func crashReporterProcessNames(for app: InstalledApp) -> Set<String> {
        var names = heuristicNames(for: app)
        if app.bundleIdentifier == "com.epicgames.EpicGamesLauncher" {
            names.formUnion([
                normalizeName("UnrealEditor"),
                normalizeName("UnrealEditorServices")
            ])
        }
        return names
    }

    private func heuristicNames(for app: InstalledApp) -> Set<String> {
        var names = [app.name]
        if let executableName = app.executableName {
            names.append(executableName)
        }
        return Set(names.map(normalizeName))
    }

    private func isLaunchServiceRoot(_ root: URL) -> Bool {
        let name = root.lastPathComponent
        return name == "LaunchAgents"
            || name == "LaunchDaemons"
            || name == "PrivilegedHelperTools"
    }

    private func normalizeName(_ name: String) -> String {
        name
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private func confidenceRank(_ confidence: LeftoverConfidence) -> Int {
        switch confidence {
        case .appBundle:
            0
        case .exactBundleID:
            1
        case .bundleIDPrefix:
            2
        case .nameHeuristic:
            3
        }
    }

    private func entitlementAppGroups(at bundleURL: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = [
            "-d",
            "--entitlements",
            ":-",
            bundleURL.path
        ]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ),
            let entitlements = plist as? [String: Any],
            let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else {
            return []
        }
        return groups
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            guard !seen.contains(value) else {
                return false
            }
            seen.insert(value)
            return true
        }
    }
}
