import AppCore
import AppKit
import AppUI
import SwiftUI
import SystemMonitor

struct RootPopoverView: View {
    @ObservedObject var router: PopoverRouter
    @ObservedObject var settingsModel: SettingsModel
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    @ObservedObject var monitorModel: SystemMonitorModel
    let onQuit: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            switch router.route {
            case .dashboard:
                DashboardView(
                    model: monitorModel,
                    settings: settingsModel.settings,
                    onOpenSettings: { router.route = .settings },
                    onQuit: onQuit
                )
            case .settings:
                SettingsView(
                    settingsModel: settingsModel,
                    launchAtLoginModel: launchAtLoginModel,
                    onClose: { router.route = .dashboard }
                )
            }
        }
        .frame(
            width: PopoverLayout.contentSize.width,
            height: PopoverLayout.contentSize.height
        )
    }
}
