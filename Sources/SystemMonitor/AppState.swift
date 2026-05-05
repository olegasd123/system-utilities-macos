import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var settings: Settings {
        didSet {
            try? settingsStore.save(settings)
        }
    }

    private let settingsStore: SettingsStore
    private let metricsSampler = MetricsSampler()

    init(settingsStore: SettingsStore = .standard) {
        self.settingsStore = settingsStore
        settings = settingsStore.load()
        metricsSampler.start { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }
}
