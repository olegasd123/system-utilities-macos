import Foundation

public struct NetworkTotalsStore: Sendable {
    public static let standard = NetworkTotalsStore()

    private let bundleId: String

    public init(bundleId: String = "dev.oleg-verhoglyad.SystemMonitor") {
        self.bundleId = bundleId
    }

    public func load() -> NetworkDailyBaseline? {
        guard let data = try? Data(contentsOf: baselineURL) else {
            return nil
        }
        return try? JSONDecoder().decode(NetworkDailyBaseline.self, from: data)
    }

    public func save(_ baseline: NetworkDailyBaseline) throws {
        let directory = baselineURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(baseline)
        try data.write(to: baselineURL, options: .atomic)
    }

    private var baselineURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("network-daily-baseline.json")
    }
}
