import Foundation

@MainActor
public final class SettingsModel: ObservableObject {
    @Published public var settings: Settings {
        didSet {
            try? store.save(settings)
        }
    }

    public let initialLoadResult: SettingsLoadResult

    private let store: SettingsStore

    public init(store: SettingsStore = .standard) {
        self.store = store
        let result = store.loadResult()
        self.initialLoadResult = result
        self.settings = result.settings
    }
}
