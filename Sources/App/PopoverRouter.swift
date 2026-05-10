import Foundation

@MainActor
final class PopoverRouter: ObservableObject {
    @Published private(set) var route: PopoverRoute
    private var activeFeatureId: String

    init(initialFeatureId: String) {
        self.activeFeatureId = initialFeatureId
        self.route = .feature(id: initialFeatureId)
    }

    func showFeature(_ featureId: String) {
        activeFeatureId = featureId
        route = .feature(id: featureId)
    }

    func showSettings() {
        if case .feature(let id) = route {
            activeFeatureId = id
        }
        route = .settings(featureId: nil)
    }

    func showSettings(for featureId: String) {
        activeFeatureId = featureId
        route = .settings(featureId: featureId)
    }

    func dismissSettings() {
        route = .feature(id: activeFeatureId)
    }
}

enum PopoverRoute: Equatable {
    case feature(id: String)
    case settings(featureId: String?)
}
