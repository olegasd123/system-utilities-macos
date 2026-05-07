import AppCore
import AppUI
import Foundation
import SystemMonitorCore
import SystemMonitorUI

@MainActor
final class AppComposer {
    let generalSettings: SettingsModel<GeneralSettings>
    let launchAtLoginModel: LaunchAtLoginModel
    let features: [any AppFeature]

    init(store: AppSettingsStore = .standard) {
        let result = store.load()
        var raw = result.value
        let persist: () -> Void = {
            try? store.save(raw)
        }

        let general = SettingsModel<GeneralSettings>(
            initial: result.value.general,
            onChange: { value in
                raw.general = value
                persist()
            }
        )
        let monitorSettings = SettingsModel<SystemMonitorSettings>(
            initial: result.value.value(for: SystemMonitorSettings.self),
            onChange: { value in
                raw.setValue(value)
                persist()
            }
        )

        let launchAtLogin = LaunchAtLoginModel(
            initiallyLoadedFromDisk: result.loadedFromDisk,
            initialLaunchAtLogin: general.settings.launchAtLogin,
            persist: { isRegistered in
                general.settings.launchAtLogin = isRegistered
            }
        )

        let monitorModel = SystemMonitorModel(settings: monitorSettings)
        let monitorFeature = SystemMonitorFeature(
            settings: monitorSettings,
            general: general,
            model: monitorModel
        )

        self.generalSettings = general
        self.launchAtLoginModel = launchAtLogin
        self.features = [monitorFeature]
    }
}
