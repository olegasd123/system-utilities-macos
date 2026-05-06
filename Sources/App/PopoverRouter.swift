import Foundation

@MainActor
final class PopoverRouter: ObservableObject {
    @Published var route: PopoverRoute = .dashboard
}

enum PopoverRoute {
    case dashboard
    case settings
}
