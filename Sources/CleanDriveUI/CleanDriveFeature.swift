import AppCore
import AppUI
import CleanDriveCore
import Foundation
import SwiftUI

@MainActor
public final class CleanDriveFeature: ObservableObject, PopoverFeature {
    public let id = CleanDriveSettings.featureId
    public let displayName = "Clean Drive"
    public let symbolName = "internaldrive"

    public let model: CleanDriveModel

    private let settings: SettingsModel<CleanDriveSettings>

    public init(
        settings: SettingsModel<CleanDriveSettings>,
        model: CleanDriveModel
    ) {
        self.settings = settings
        self.model = model
    }

    public func makeRootView() -> AnyView {
        AnyView(CleanDriveView(model: model, settingsModel: settings))
    }

    public func makeSettingsSection() -> AnyView? {
        AnyView(CleanDriveSettingsView(settings: settings, model: model))
    }
}
