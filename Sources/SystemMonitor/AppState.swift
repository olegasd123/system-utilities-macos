import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings: Settings {
        didSet {
            try? settingsStore.save(settings)
        }
    }

    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore = .standard) {
        self.settingsStore = settingsStore
        settings = settingsStore.load()
    }
}
