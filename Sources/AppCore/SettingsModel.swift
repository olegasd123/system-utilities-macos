import Foundation

@MainActor
public final class SettingsModel<Settings: Equatable & Sendable>: ObservableObject {
    @Published public var settings: Settings {
        didSet {
            guard settings != oldValue else {
                return
            }
            onChange(settings)
        }
    }

    private let onChange: (Settings) -> Void

    public init(initial: Settings, onChange: @escaping (Settings) -> Void) {
        self.settings = initial
        self.onChange = onChange
    }
}
