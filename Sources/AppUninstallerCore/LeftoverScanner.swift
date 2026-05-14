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
        let userHomeCandidateURLs = settings.includeUserHomePaths
            ? userHomeLeftoverURLs(for: app)
            : []
        let safety = AppUninstallerPathSafety(
            appBundleURL: app.bundleURL,
            scanRoots: roots,
            directAllowedPaths: userHomeCandidateURLs,
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

        for url in userHomeCandidateURLs {
            try Task.checkCancellation()
            guard
                FileManager.default.fileExists(atPath: url.path),
                safety.canShowCandidate(url)
            else {
                continue
            }

            do {
                leftovers.append(
                    try candidate(for: url, confidence: .userHome)
                )
            } catch {
                notes.append("Skipped \(url.path): \(error.localizedDescription)")
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

        if root.lastPathComponent == "Application Scripts",
           let confidence = applicationScriptsMatchConfidence(for: name, app: app) {
            return confidence
        }

        if let confidence = appAliasMatchConfidence(
            for: name,
            plistTrimmed: plistTrimmed,
            root: root,
            app: app
        ) {
            return confidence
        }

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

    private func appAliasMatchConfidence(
        for name: String,
        plistTrimmed: String,
        root: URL,
        app: InstalledApp
    ) -> LeftoverConfidence? {
        let aliases = appLeftoverAliases(for: app)
        for bundleIdentifier in aliases.bundleIdentifiers {
            if name == bundleIdentifier || plistTrimmed == bundleIdentifier {
                return .bundleIDPrefix
            }
            if name.hasPrefix("\(bundleIdentifier).")
                || plistTrimmed.hasPrefix("\(bundleIdentifier).") {
                return .bundleIDPrefix
            }
        }

        guard root.lastPathComponent == "Application Support" else {
            return nil
        }
        return aliases.applicationSupportNames.contains(name) ? .bundleIDPrefix : nil
    }

    private func appLeftoverAliases(for app: InstalledApp) -> AppLeftoverAliases {
        var aliases = AppLeftoverAliases()
        let normalizedAppName = normalizeName(app.name)
        if !normalizedAppName.isEmpty {
            aliases.userHomeNames += [
                ".\(normalizedAppName)",
                ".\(normalizedAppName).json"
            ]
        }

        switch app.bundleIdentifier {
        case "com.docker.docker":
            aliases.bundleIdentifiers.append("com.electron.dockerdesktop")
            aliases.applicationSupportNames.append("Docker Desktop")
        default:
            break
        }

        if app.matchesAppAlias("docker") {
            aliases.userHomeNames.append(".docker")
        }
        if app.matchesAppAlias("lmstudio") {
            aliases.userHomeNames += [".lmstudio-home-pointer"]
        }
        if app.bundleIdentifier == "com.parallels.desktop.console" {
            aliases.userHomeNames.append("Parallels")
        }
        if app.bundleIdentifier == "com.epicgames.EpicGamesLauncher"
            || app.matchesAppAlias("unrealengine") {
            aliases.userHomeNames.append("UnrealEngine")
        }

        aliases.bundleIdentifiers = uniqueStrings(aliases.bundleIdentifiers)
        aliases.applicationSupportNames = uniqueStrings(aliases.applicationSupportNames)
        aliases.userHomeNames = uniqueStrings(aliases.userHomeNames)
        return aliases
    }

    private func applicationScriptsMatchConfidence(
        for name: String,
        app: InstalledApp
    ) -> LeftoverConfidence? {
        if name == app.bundleIdentifier {
            return .exactBundleID
        }
        if name.hasPrefix("\(app.bundleIdentifier).") {
            return .bundleIDPrefix
        }
        guard
            let bundleSuffix = bundleIdentifierSuffixAfterTeamID(in: name)
        else {
            return nil
        }
        if bundleSuffix == app.bundleIdentifier {
            return .exactBundleID
        }
        if bundleSuffix.hasPrefix("\(app.bundleIdentifier).") {
            return .bundleIDPrefix
        }
        return nil
    }

    private func bundleIdentifierSuffixAfterTeamID(in name: String) -> String? {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        guard
            parts.count == 2,
            isAppleTeamIdentifier(parts[0])
        else {
            return nil
        }
        return parts[1]
    }

    private func isAppleTeamIdentifier(_ value: String) -> Bool {
        value.count == 10 && value.allSatisfy {
            $0.isASCII && ($0.isNumber || $0.isUppercase)
        }
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
        case .userHome:
            4
        }
    }

    private struct AppLeftoverAliases {
        var bundleIdentifiers: [String] = []
        var applicationSupportNames: [String] = []
        var userHomeNames: [String] = []
    }

    private func userHomeLeftoverURLs(for app: InstalledApp) -> [URL] {
        appLeftoverAliases(for: app).userHomeNames.map {
            homeDirectory.appendingPathComponent($0)
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

private extension InstalledApp {
    func matchesAppAlias(_ alias: String) -> Bool {
        let normalizedAlias = alias
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let normalizedName = name
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        return normalizedName == normalizedAlias
            || bundleIdentifier.localizedCaseInsensitiveContains(alias)
    }
}
