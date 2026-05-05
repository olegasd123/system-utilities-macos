import SwiftUI

struct RootPopoverView: View {
    @ObservedObject var router: PopoverRouter
    @ObservedObject var appState: AppState
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            switch router.route {
            case .dashboard:
                DashboardView(
                    settings: appState.settings,
                    onOpenSettings: { router.route = .settings },
                    onQuit: onQuit
                )
            case .settings:
                SettingsView(
                    settings: $appState.settings,
                    onClose: { router.route = .dashboard }
                )
            }
        }
        .frame(width: 450, height: 620)
    }
}
