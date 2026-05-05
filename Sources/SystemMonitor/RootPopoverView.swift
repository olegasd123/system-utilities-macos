import SwiftUI

struct RootPopoverView: View {
    @ObservedObject var router: PopoverRouter
    @ObservedObject var appState: AppState
    let onQuit: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            switch router.route {
            case .dashboard:
                DashboardView(
                    snapshot: appState.snapshot,
                    networkTotals: appState.networkTotals,
                    settings: appState.settings,
                    onResetNetworkTotals: { appState.resetNetworkTotals() },
                    onOpenSettings: { router.route = .settings },
                    onQuit: onQuit
                )
            case .settings:
                SettingsView(
                    settings: $appState.settings,
                    launchAtLoginStatus: appState.launchAtLoginStatus,
                    onSetLaunchAtLogin: { appState.setLaunchAtLogin($0) },
                    onOpenLoginItems: { appState.openLoginItemsSettings() },
                    onClose: { router.route = .dashboard }
                )
            }
        }
        .frame(
            width: PopoverLayout.width,
            height: PopoverLayout.height(
                for: router.route,
                hasBattery: appState.snapshot?.battery != nil
            )
        )
    }
}
