import AppCore
import AppUI
import AppUninstallerCore
import AppUninstallerUI
import CleanDriveCore
import CleanDriveUI
import Foundation
import SystemMonitorCore
import SystemMonitorUI

@MainActor
final class AppComposer {
    let generalSettings: SettingsModel<GeneralSettings>
    let launchAtLoginModel: LaunchAtLoginModel
    let cleanDriveReminderService: CleanDriveReminderService
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
        let cleanDriveSettingsValue = raw.value(for: CleanDriveSettings.self)
        if raw.features[CleanDriveSettings.featureId] == nil {
            raw.setValue(cleanDriveSettingsValue)
            persist()
        }
        let cleanDriveSettings = SettingsModel<CleanDriveSettings>(
            initial: cleanDriveSettingsValue,
            onChange: { value in
                raw.setValue(value)
                persist()
            }
        )
        let appUninstallerSettingsValue = raw.value(for: AppUninstallerSettings.self)
        if raw.features[AppUninstallerSettings.featureId] == nil {
            raw.setValue(appUninstallerSettingsValue)
            persist()
        }
        let appUninstallerSettings = SettingsModel<AppUninstallerSettings>(
            initial: appUninstallerSettingsValue,
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
        let cleanDriveModel = CleanDriveModel(settings: cleanDriveSettings)
        let cleanDriveFeature = CleanDriveFeature(
            settings: cleanDriveSettings,
            model: cleanDriveModel
        )
        let appUninstallerModel = AppUninstallerModel(settings: appUninstallerSettings)
        let appUninstallerFeature = AppUninstallerFeature(
            settings: appUninstallerSettings,
            model: appUninstallerModel
        )
        let cleanDriveReminderService = CleanDriveReminderService(settings: cleanDriveSettings)

        self.generalSettings = general
        self.launchAtLoginModel = launchAtLogin
        self.cleanDriveReminderService = cleanDriveReminderService
        self.features = [monitorFeature, cleanDriveFeature, appUninstallerFeature]
    }
}
