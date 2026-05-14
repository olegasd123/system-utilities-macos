import AppCore
import AppUI
import AppUninstallerCore
import SwiftUI

struct AppUninstallerSettingsView: View {
    @ObservedObject var settings: SettingsModel<AppUninstallerSettings>

    var body: some View {
        SettingsSection("App Uninstaller") {
            Toggle(
                "Show possible name matches",
                isOn: $settings.settings.includeNameHeuristicMatches
            )

            Toggle(
                "Scan /Library paths",
                isOn: $settings.settings.includeSystemLibraryPaths
            )

            Toggle(
                "Scan user folder leftovers",
                isOn: $settings.settings.includeUserHomePaths
            )

            Picker("Default uninstall mode", selection: $settings.settings.defaultReclaimMode) {
                Text("Move to Trash").tag(ReclaimMode.moveToTrash)
                Text("Permanently delete").tag(ReclaimMode.hardDelete)
            }
            .pickerStyle(.radioGroup)

            if settings.settings.defaultReclaimMode == .hardDelete {
                Text("Items are removed right away. This cannot be undone.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
    }
}
