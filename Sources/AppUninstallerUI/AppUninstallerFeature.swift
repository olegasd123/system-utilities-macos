import AppCore
import AppUI
import AppUninstallerCore
import Foundation
import SwiftUI

@MainActor
public final class AppUninstallerFeature: ObservableObject, PopoverFeature {
    public let id = AppUninstallerSettings.featureId
    public let displayName = "App Uninstaller"
    public let symbolName = "app.badge"

    public let model: AppUninstallerModel
    private let settings: SettingsModel<AppUninstallerSettings>

    public init(
        settings: SettingsModel<AppUninstallerSettings>,
        model: AppUninstallerModel
    ) {
        self.settings = settings
        self.model = model
    }

    public func makeRootView() -> AnyView {
        AnyView(AppUninstallerView(model: model, settingsModel: settings))
    }

    public func makeSettingsSection() -> AnyView? {
        AnyView(AppUninstallerSettingsView(settings: settings))
    }
}
