import AppCore
import AppUI
import AppUninstallerCore
import SwiftUI

struct AppUninstallerSettingsView: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject var settings: SettingsModel<AppUninstallerSettings>

    var body: some View {
        SettingsSection("App Uninstaller") {
            Toggle(
                localization("Show possible name matches"),
                isOn: $settings.settings.includeNameHeuristicMatches
            )

            Toggle(
                localization("Scan /Library paths"),
                isOn: $settings.settings.includeSystemLibraryPaths
            )

            Toggle(
                localization("Scan user folder leftovers"),
                isOn: $settings.settings.includeUserHomePaths
            )

            Picker(localization("Default uninstall mode"), selection: $settings.settings.defaultReclaimMode) {
                Text(localization("Move to Trash")).tag(ReclaimMode.moveToTrash)
                Text(localization("Permanently delete")).tag(ReclaimMode.hardDelete)
            }
            .pickerStyle(.radioGroup)

            if settings.settings.defaultReclaimMode == .hardDelete {
                Text(localization("Items are removed right away. This cannot be undone."))
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
    }
}
