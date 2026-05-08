import Combine
import SwiftUI

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

    public var binding: Binding<Settings> {
        Binding(
            get: { [unowned self] in settings },
            set: { [unowned self] in settings = $0 }
        )
    }

    public var publisher: AnyPublisher<Settings, Never> {
        $settings.eraseToAnyPublisher()
    }
}
