import Foundation

struct SettingsStore: Sendable {
    static let standard = SettingsStore()

    func load() -> Settings {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return .defaultValue
        }

        let decoder = JSONDecoder()
        if let settings = try? decoder.decode(Settings.self, from: data) {
            return settings
        }

        if let envelope = try? decoder.decode(SettingsEnvelope.self, from: data) {
            return envelope.settings
        }

        return .defaultValue
    }

    func save(_ settings: Settings) throws {
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

private struct SettingsEnvelope: Codable {
    let settings: Settings
}
