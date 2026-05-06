import Foundation

public struct SettingsStore: Sendable {
    public static let standard = SettingsStore()

    public init() {}

    public func load() -> Settings {
        loadResult().settings
    }

    public func loadResult() -> SettingsLoadResult {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return SettingsLoadResult(settings: .defaultValue, loadedFromDisk: false)
        }

        let decoder = JSONDecoder()
        if let settings = try? decoder.decode(Settings.self, from: data) {
            return SettingsLoadResult(settings: settings, loadedFromDisk: true)
        }

        if let envelope = try? decoder.decode(SettingsEnvelope.self, from: data) {
            return SettingsLoadResult(settings: envelope.settings, loadedFromDisk: true)
        }

        return SettingsLoadResult(settings: .defaultValue, loadedFromDisk: false)
    }

    public func save(_ settings: Settings) throws {
        let directory = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    private var settingsURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("dev.olegoleg.system-monitor", isDirectory: true)
            .appendingPathComponent("settings.json")
    }
}

public struct SettingsLoadResult: Equatable, Sendable {
    public let settings: Settings
    public let loadedFromDisk: Bool

    public init(settings: Settings, loadedFromDisk: Bool) {
        self.settings = settings
        self.loadedFromDisk = loadedFromDisk
    }
}

private struct SettingsEnvelope: Codable {
    let settings: Settings
}
