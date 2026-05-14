import AppCore
@testable import AppUninstallerCore
import XCTest

final class AppUninstallerCoreTests: XCTestCase {
    private var rootURL: URL!
    private var trashURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        trashURL = rootURL.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        trashURL = nil
    }

    func testInstalledAppsScannerFindsValidAppsAndSkipsOwnBundle() throws {
        let applicationsURL = rootURL.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(
            at: applicationsURL,
            withIntermediateDirectories: true
        )
        _ = try makeApp(
            in: applicationsURL,
            name: "Demo",
            bundleIdentifier: "com.example.Demo"
        )
        _ = try makeApp(
            in: applicationsURL,
            name: "Self",
            bundleIdentifier: "dev.oleg-verhoglyad.SystemMonitor"
        )
        let brokenURL = applicationsURL.appendingPathComponent("Broken.app", isDirectory: true)
        try FileManager.default.createDirectory(at: brokenURL, withIntermediateDirectories: true)

        let scanner = InstalledAppsScanner(
            searchRoots: [applicationsURL],
            ownBundleIdentifier: "dev.oleg-verhoglyad.SystemMonitor"
        )

        let apps = try scanner.scan()

        XCTAssertEqual(apps.map(\.name), ["Demo"])
        XCTAssertEqual(apps.first?.bundleIdentifier, "com.example.Demo")
        XCTAssertGreaterThanOrEqual(apps.first?.bundleSize ?? 0, 1_024)
    }

    func testLeftoverScannerMatchesConfidenceTiers() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Demo App",
            bundleIdentifier: "com.example.Demo",
            executableName: "Demo"
        )
        let supportURL = rootURL.appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        try writeFile(supportURL.appendingPathComponent("com.example.Demo"))
        try writeFile(supportURL.appendingPathComponent("com.example.Demo.helper.plist"))
        try writeFile(supportURL.appendingPathComponent("DemoApp"))
        try writeFile(supportURL.appendingPathComponent("Other"))

        let app = InstalledApp(
            bundleIdentifier: "com.example.Demo",
            name: "Demo App",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            executableName: "Demo",
            isSystem: false
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL, userScanRoots: [supportURL])

        let conservative = try scanner.scan(app: app, settings: .defaultValue)
        XCTAssertEqual(
            conservative.leftovers.map { "\($0.url.lastPathComponent):\($0.confidence.rawValue)" },
            [
                "com.example.Demo:exactBundleID",
                "com.example.Demo.helper.plist:bundleIDPrefix"
            ]
        )

        let heuristic = try scanner.scan(
            app: app,
            settings: AppUninstallerSettings(
                includeNameHeuristicMatches: true,
                includeSystemLibraryPaths: false,
                defaultReclaimMode: .moveToTrash
            )
        )
        XCTAssertTrue(heuristic.leftovers.contains {
            $0.url.lastPathComponent == "DemoApp" && $0.confidence == .nameHeuristic
        })
    }

    func testAppBundleSizeIncludesNestedPackageContents() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Demo",
            bundleIdentifier: "com.example.Demo"
        )
        let frameworkURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("Nested.framework", isDirectory: true)
        try writeFile(frameworkURL.appendingPathComponent("Nested"), size: 20_000)

        let app = InstalledApp(
            bundleIdentifier: "com.example.Demo",
            name: "Demo",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            isSystem: false
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL, userScanRoots: [])

        let result = try scanner.scan(app: app, settings: .defaultValue)

        XCTAssertGreaterThanOrEqual(result.bundle.size, 21_024)
    }

    func testGroupContainersRequireExactAppGroupID() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Demo",
            bundleIdentifier: "com.example.Demo"
        )
        let groupURL = rootURL.appendingPathComponent("Group Containers", isDirectory: true)
        try FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true)
        try writeFile(groupURL.appendingPathComponent("TEAM.com.example.shared"))
        try writeFile(groupURL.appendingPathComponent("com.example.Demo.helper"))

        let app = InstalledApp(
            bundleIdentifier: "com.example.Demo",
            name: "Demo",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            isSystem: false,
            appGroupIdentifiers: ["TEAM.com.example.shared"]
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL, userScanRoots: [groupURL])

        let result = try scanner.scan(app: app, settings: .defaultValue)

        XCTAssertEqual(result.leftovers.map(\.url.lastPathComponent), ["TEAM.com.example.shared"])
    }

    func testLaunchAgentsMatchCompactBundleIDHelperNames() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Steam",
            bundleIdentifier: "com.valvesoftware.steam",
            executableName: "steam_osx"
        )
        let launchAgentsURL = rootURL.appendingPathComponent(
            "LaunchAgents",
            isDirectory: true
        )
        try writeFile(
            launchAgentsURL.appendingPathComponent("com.valvesoftware.steamclean.plist")
        )
        try writeFile(
            launchAgentsURL.appendingPathComponent("com.valvesoftware.other.plist")
        )

        let app = InstalledApp(
            bundleIdentifier: "com.valvesoftware.steam",
            name: "Steam",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            executableName: "steam_osx",
            isSystem: false
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL, userScanRoots: [launchAgentsURL])

        let result = try scanner.scan(app: app, settings: .defaultValue)

        XCTAssertEqual(result.leftovers.map(\.url.lastPathComponent), [
            "com.valvesoftware.steamclean.plist"
        ])
        XCTAssertEqual(result.leftovers.first?.confidence, .bundleIDPrefix)
    }

    func testApplicationScriptsMatchTeamPrefixedBundleIdentifiers() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Telegram",
            bundleIdentifier: "ru.keepcoder.Telegram"
        )
        let scriptsURL = rootURL.appendingPathComponent(
            "Application Scripts",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: scriptsURL.appendingPathComponent(
                "6N38VWS5BX.ru.keepcoder.Telegram",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: scriptsURL.appendingPathComponent(
                "6N38VWS5BX.ru.keepcoder.Telegram.FocusIntents",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: scriptsURL.appendingPathComponent(
                "6N38VWS5BX.ru.keepcoder.Other",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )

        let app = InstalledApp(
            bundleIdentifier: "ru.keepcoder.Telegram",
            name: "Telegram",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            isSystem: false
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL, userScanRoots: [scriptsURL])

        let result = try scanner.scan(app: app, settings: .defaultValue)

        XCTAssertEqual(result.leftovers.map(\.url.lastPathComponent), [
            "6N38VWS5BX.ru.keepcoder.Telegram",
            "6N38VWS5BX.ru.keepcoder.Telegram.FocusIntents"
        ])
        XCTAssertEqual(result.leftovers.map(\.confidence), [
            .exactBundleID,
            .bundleIDPrefix
        ])
    }

    func testDockerAliasesMatchDesktopSupportAndElectronPreference() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Docker",
            bundleIdentifier: "com.docker.docker"
        )
        let supportURL = rootURL.appendingPathComponent(
            "Application Support",
            isDirectory: true
        )
        let preferencesURL = rootURL.appendingPathComponent("Preferences", isDirectory: true)
        try FileManager.default.createDirectory(
            at: supportURL.appendingPathComponent("Docker Desktop", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writeFile(preferencesURL.appendingPathComponent("com.electron.dockerdesktop.plist"))

        let app = InstalledApp(
            bundleIdentifier: "com.docker.docker",
            name: "Docker",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            isSystem: false
        )
        let scanner = LeftoverScanner(
            homeDirectory: rootURL,
            userScanRoots: [supportURL, preferencesURL]
        )

        let result = try scanner.scan(app: app, settings: .defaultValue)

        XCTAssertEqual(result.leftovers.map(\.url.lastPathComponent), [
            "Docker Desktop",
            "com.electron.dockerdesktop.plist"
        ])
        XCTAssertTrue(result.leftovers.allSatisfy { $0.confidence == .bundleIDPrefix })
    }

    func testUserHomeLeftoversAreOptInAndNotSelectedByDefault() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "LM Studio",
            bundleIdentifier: "ai.elementlabs.lmstudio"
        )
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent(".lmstudio", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writeFile(rootURL.appendingPathComponent(".lmstudio-home-pointer"))

        let app = InstalledApp(
            bundleIdentifier: "ai.elementlabs.lmstudio",
            name: "LM Studio",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            isSystem: false
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL)

        let defaultResult = try scanner.scan(app: app, settings: .defaultValue)
        XCTAssertTrue(defaultResult.leftovers.isEmpty)

        let optInResult = try scanner.scan(
            app: app,
            settings: AppUninstallerSettings(
                includeNameHeuristicMatches: false,
                includeSystemLibraryPaths: false,
                includeUserHomePaths: true,
                defaultReclaimMode: .moveToTrash
            )
        )

        XCTAssertEqual(optInResult.leftovers.map(\.url.lastPathComponent), [
            ".lmstudio",
            ".lmstudio-home-pointer"
        ])
        XCTAssertTrue(optInResult.leftovers.allSatisfy { $0.confidence == .userHome })
        XCTAssertTrue(optInResult.leftovers.allSatisfy { !$0.isSelectedByDefault })
    }

    func testUserHomeLeftoversMatchNormalizedAppNamePatterns() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Demo App",
            bundleIdentifier: "com.example.demo-app"
        )
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent(".demoapp", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writeFile(rootURL.appendingPathComponent(".demoapp.json"))
        try writeFile(rootURL.appendingPathComponent(".demoapp.settings.json"))

        let app = InstalledApp(
            bundleIdentifier: "com.example.demo-app",
            name: "Demo App",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            isSystem: false
        )
        let scanner = LeftoverScanner(homeDirectory: rootURL)

        let defaultResult = try scanner.scan(app: app, settings: .defaultValue)
        XCTAssertTrue(defaultResult.leftovers.isEmpty)

        let optInResult = try scanner.scan(
            app: app,
            settings: AppUninstallerSettings(
                includeNameHeuristicMatches: false,
                includeSystemLibraryPaths: false,
                includeUserHomePaths: true,
                defaultReclaimMode: .moveToTrash
            )
        )

        XCTAssertEqual(optInResult.leftovers.map(\.url.lastPathComponent), [
            ".demoapp",
            ".demoapp.json"
        ])
        XCTAssertTrue(optInResult.leftovers.allSatisfy { $0.confidence == .userHome })
        XCTAssertTrue(optInResult.leftovers.allSatisfy { !$0.isSelectedByDefault })
    }

    func testKnownUserHomeAliasesMatchGivenApps() throws {
        let apps: [(name: String, bundleIdentifier: String, leftoverName: String)] = [
            ("Docker", "com.docker.docker", ".docker"),
            ("Claude", "com.anthropic.claudefordesktop", ".claude.json"),
            ("Claude", "com.anthropic.claudefordesktop", ".claude"),
            ("Epic Games Launcher", "com.epicgames.EpicGamesLauncher", "UnrealEngine"),
            ("Parallels Desktop", "com.parallels.desktop.console", "Parallels")
        ]

        for appData in apps {
            let appRoot = rootURL.appendingPathComponent(appData.name, isDirectory: true)
            let appURL = try makeApp(
                in: appRoot,
                name: appData.name,
                bundleIdentifier: appData.bundleIdentifier
            )
            try writeFile(rootURL.appendingPathComponent(appData.leftoverName))

            let app = InstalledApp(
                bundleIdentifier: appData.bundleIdentifier,
                name: appData.name,
                bundleURL: appURL,
                sourceLocation: appRoot.path,
                isSystem: false
            )
            let scanner = LeftoverScanner(homeDirectory: rootURL)

            let result = try scanner.scan(
                app: app,
                settings: AppUninstallerSettings(
                    includeNameHeuristicMatches: false,
                    includeSystemLibraryPaths: false,
                    includeUserHomePaths: true,
                    defaultReclaimMode: .moveToTrash
                )
            )

            XCTAssertTrue(result.leftovers.contains {
                $0.url.lastPathComponent == appData.leftoverName && $0.confidence == .userHome
            })
            try FileManager.default.removeItem(at: rootURL.appendingPathComponent(appData.leftoverName))
        }
    }

    func testTemporaryDirectoryMatchesAppNamePrefixesAsPossibleLeftovers() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Steam",
            bundleIdentifier: "com.valvesoftware.steam",
            executableName: "steam_osx"
        )
        let temporaryURL = rootURL.appendingPathComponent("T", isDirectory: true)
        try writeFile(temporaryURL.appendingPathComponent("steam"), size: 0)
        try writeFile(temporaryURL.appendingPathComponent("steamittkMu"), size: 0)
        try writeFile(temporaryURL.appendingPathComponent("other"), size: 0)

        let app = InstalledApp(
            bundleIdentifier: "com.valvesoftware.steam",
            name: "Steam",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            executableName: "steam_osx",
            isSystem: false
        )
        let scanner = LeftoverScanner(
            homeDirectory: rootURL,
            temporaryDirectory: temporaryURL
        )

        let conservative = try scanner.scan(app: app, settings: .defaultValue)
        XCTAssertTrue(conservative.leftovers.isEmpty)

        let heuristic = try scanner.scan(
            app: app,
            settings: AppUninstallerSettings(
                includeNameHeuristicMatches: true,
                includeSystemLibraryPaths: false,
                defaultReclaimMode: .moveToTrash
            )
        )

        XCTAssertEqual(Set(heuristic.leftovers.map(\.url.lastPathComponent)), [
            "steam",
            "steamittkMu"
        ])
        XCTAssertTrue(heuristic.leftovers.allSatisfy { $0.confidence == .nameHeuristic })
    }

    func testCrashReporterMatchesProcessNamesAsPossibleLeftovers() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Demo App",
            bundleIdentifier: "com.example.Demo",
            executableName: "DemoApp"
        )
        let supportURL = rootURL.appendingPathComponent(
            "Application Support",
            isDirectory: true
        )
        let crashReporterURL = supportURL.appendingPathComponent(
            "CrashReporter",
            isDirectory: true
        )
        try writeFile(
            crashReporterURL.appendingPathComponent(
                "DemoApp_4FB707EB-00B3-5077-A850-C63680C3F280.plist"
            )
        )
        try writeFile(
            crashReporterURL.appendingPathComponent(
                "Other_4FB707EB-00B3-5077-A850-C63680C3F280.plist"
            )
        )

        let app = InstalledApp(
            bundleIdentifier: "com.example.Demo",
            name: "Demo App",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            executableName: "DemoApp",
            isSystem: false
        )
        let scanner = LeftoverScanner(
            homeDirectory: rootURL,
            userScanRoots: [supportURL, crashReporterURL]
        )

        let conservative = try scanner.scan(app: app, settings: .defaultValue)
        XCTAssertTrue(conservative.leftovers.isEmpty)

        let heuristic = try scanner.scan(
            app: app,
            settings: AppUninstallerSettings(
                includeNameHeuristicMatches: true,
                includeSystemLibraryPaths: false,
                defaultReclaimMode: .moveToTrash
            )
        )

        XCTAssertEqual(heuristic.leftovers.map(\.url.lastPathComponent), [
            "DemoApp_4FB707EB-00B3-5077-A850-C63680C3F280.plist"
        ])
        XCTAssertEqual(heuristic.leftovers.first?.confidence, .nameHeuristic)
    }

    func testCrashReporterMatchesEpicUnrealProcessNamesAsPossibleLeftovers() throws {
        let appURL = try makeApp(
            in: rootURL,
            name: "Epic Games Launcher",
            bundleIdentifier: "com.epicgames.EpicGamesLauncher",
            executableName: "EpicGamesLauncher-Mac-Shipping"
        )
        let crashReporterURL = rootURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CrashReporter", isDirectory: true)
        try writeFile(
            crashReporterURL.appendingPathComponent(
                "UnrealEditorServices_4FB707EB-00B3-5077-A850-C63680C3F280.plist"
            )
        )

        let app = InstalledApp(
            bundleIdentifier: "com.epicgames.EpicGamesLauncher",
            name: "Epic Games Launcher",
            bundleURL: appURL,
            sourceLocation: rootURL.path,
            executableName: "EpicGamesLauncher-Mac-Shipping",
            isSystem: false
        )
        let scanner = LeftoverScanner(
            homeDirectory: rootURL,
            temporaryDirectory: rootURL.appendingPathComponent("T", isDirectory: true)
        )

        let result = try scanner.scan(
            app: app,
            settings: AppUninstallerSettings(
                includeNameHeuristicMatches: true,
                includeSystemLibraryPaths: false,
                defaultReclaimMode: .moveToTrash
            )
        )

        XCTAssertEqual(result.leftovers.map(\.url.lastPathComponent), [
            "UnrealEditorServices_4FB707EB-00B3-5077-A850-C63680C3F280.plist"
        ])
        XCTAssertEqual(result.leftovers.first?.confidence, .nameHeuristic)
    }

    func testPathSafetyRejectsRootsAndEscapedPaths() {
        let appURL = rootURL.appendingPathComponent("Demo.app", isDirectory: true)
        let scanRoot = rootURL.appendingPathComponent("Library", isDirectory: true)
        let safety = AppUninstallerPathSafety(
            appBundleURL: appURL,
            scanRoots: [scanRoot],
            homeDirectory: rootURL
        )

        XCTAssertTrue(safety.canRemove(appURL))
        XCTAssertTrue(safety.canRemove(scanRoot.appendingPathComponent("com.example.Demo")))
        XCTAssertFalse(safety.canRemove(rootURL))
        XCTAssertFalse(safety.canRemove(scanRoot))
        XCTAssertFalse(safety.canRemove(scanRoot.appendingPathComponent("../Escaped")))
        XCTAssertFalse(safety.canRemove(URL(fileURLWithPath: "/Library")))
    }

    func testAppUninstallerMovesBundleAndLeftoversToTrash() async throws {
        let appsURL = rootURL.appendingPathComponent("Applications", isDirectory: true)
        let libraryURL = rootURL.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: appsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)

        let appURL = try makeApp(
            in: appsURL,
            name: "Demo",
            bundleIdentifier: "com.example.Demo"
        )
        let leftoverURL = libraryURL.appendingPathComponent("com.example.Demo")
        try writeFile(leftoverURL)

        let app = InstalledApp(
            bundleIdentifier: "com.example.Demo",
            name: "Demo",
            bundleURL: appURL,
            sourceLocation: appsURL.path,
            isSystem: false
        )
        let leftover = LeftoverCandidate(
            url: leftoverURL,
            size: 1_024,
            kind: .file,
            confidence: .exactBundleID
        )
        let uninstaller = AppUninstaller(
            trasher: DirectoryTrash(trashDirectory: trashURL),
            homeDirectory: rootURL,
            scanRoots: [libraryURL]
        )

        let report = try await uninstaller.uninstall(
            app,
            leftovers: [leftover],
            mode: .moveToTrash
        )

        XCTAssertEqual(report.reclaimedItemCount, 2)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: appURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftoverURL.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: trashURL.appendingPathComponent("Demo.app").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: trashURL.appendingPathComponent("com.example.Demo").path
            )
        )
    }

    func testAppUninstallerMovesSelectedUserHomeLeftoversToTrash() async throws {
        let appsURL = rootURL.appendingPathComponent("Applications", isDirectory: true)
        let libraryURL = rootURL.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: appsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)

        let appURL = try makeApp(
            in: appsURL,
            name: "Docker",
            bundleIdentifier: "com.docker.docker"
        )
        let leftoverURL = rootURL.appendingPathComponent(".docker")
        try writeFile(leftoverURL)

        let app = InstalledApp(
            bundleIdentifier: "com.docker.docker",
            name: "Docker",
            bundleURL: appURL,
            sourceLocation: appsURL.path,
            isSystem: false
        )
        let leftover = LeftoverCandidate(
            url: leftoverURL,
            size: 1_024,
            kind: .file,
            confidence: .userHome
        )
        let uninstaller = AppUninstaller(
            trasher: DirectoryTrash(trashDirectory: trashURL),
            homeDirectory: rootURL,
            scanRoots: [libraryURL]
        )

        let report = try await uninstaller.uninstall(
            app,
            leftovers: [leftover],
            mode: .moveToTrash
        )

        XCTAssertEqual(report.reclaimedItemCount, 2)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftoverURL.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: trashURL.appendingPathComponent(".docker").path
            )
        )
    }

    @MainActor
    func testRefreshingAppsClearsCurrentLeftoversDuringScan() async throws {
        let appsURL = rootURL.appendingPathComponent("Applications", isDirectory: true)
        let libraryURL = rootURL.appendingPathComponent("Library", isDirectory: true)
        let supportURL = libraryURL.appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: appsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)

        let appURL = try makeApp(
            in: appsURL,
            name: "Demo",
            bundleIdentifier: "com.example.Demo"
        )
        try writeFile(supportURL.appendingPathComponent("com.example.Demo"))

        let app = InstalledApp(
            bundleIdentifier: "com.example.Demo",
            name: "Demo",
            bundleURL: appURL,
            sourceLocation: appsURL.path,
            isSystem: false
        )
        let gate = AppScanGate(app: app)
        let model = AppUninstallerModel(
            appScanner: InstalledAppsScanner(scan: gate.scan),
            leftoverScanner: LeftoverScanner(homeDirectory: rootURL, userScanRoots: [supportURL])
        )

        await model.loadApps()
        XCTAssertEqual(model.scanResult?.leftovers.count, 1)
        XCTAssertFalse(model.selectedLeftoverIDs.isEmpty)

        let refreshTask = Task {
            await model.loadApps()
        }
        await gate.waitForBlockedRefresh()

        XCTAssertTrue(model.isLoadingApps)
        XCTAssertNil(model.scanResult)
        XCTAssertTrue(model.selectedLeftoverIDs.isEmpty)

        gate.finishRefresh()
        await refreshTask.value
        XCTAssertEqual(model.scanResult?.leftovers.count, 1)
    }

    private func makeApp(
        in directory: URL,
        name: String,
        bundleIdentifier: String,
        executableName: String? = nil
    ) throws -> URL {
        let appURL = directory.appendingPathComponent("\(name).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleShortVersionString": "1.0",
            "CFBundleExecutable": executableName ?? name
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        try writeFile(contentsURL.appendingPathComponent(executableName ?? name))
        return appURL
    }

    private func writeFile(_ url: URL, size: Int = 1_024) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: size).write(to: url)
    }
}

private final class AppScanGate: @unchecked Sendable {
    private let app: InstalledApp
    private let lock = NSLock()
    private let blockedRefresh = DispatchSemaphore(value: 0)
    private let releaseRefresh = DispatchSemaphore(value: 0)
    private var callCount = 0

    init(app: InstalledApp) {
        self.app = app
    }

    func scan() throws -> [InstalledApp] {
        lock.lock()
        callCount += 1
        let currentCall = callCount
        lock.unlock()

        if currentCall == 2 {
            blockedRefresh.signal()
            releaseRefresh.wait()
        }

        return [app]
    }

    func waitForBlockedRefresh() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.blockedRefresh.wait()
                continuation.resume()
            }
        }
    }

    func finishRefresh() {
        releaseRefresh.signal()
    }
}
