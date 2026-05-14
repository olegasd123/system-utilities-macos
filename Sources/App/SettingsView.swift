import AppCore
import AppUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject var generalSettings: SettingsModel<GeneralSettings>
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    let features: [any AppFeature]
    var focusedFeatureId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if focusedFeatureId == nil {
                    languageSection
                    startupSection
                }

                ForEach(visibleFeatures, id: \.id) { feature in
                    if let section = feature.makeSettingsSection() {
                        section
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var visibleFeatures: [any AppFeature] {
        guard let focusedFeatureId else {
            return features
        }
        return features.filter { $0.id == focusedFeatureId }
    }

    private var startupSection: some View {
        SettingsSection("Startup") {
            Toggle(localization("Open when Mac starts"), isOn: launchAtLoginBinding)
                .disabled(!launchAtLoginModel.status.canChange)

            if let message = launchAtLoginModel.status.message {
                Text(localization(message))
                    .font(.system(size: 12))
                    .foregroundStyle(launchAtLoginMessageColor)
            }

            if launchAtLoginModel.status.needsApproval {
                Button(localization("Open Login Items")) {
                    launchAtLoginModel.openLoginItemsSettings()
                }
                .controlSize(.small)
            }
        }
    }

    private var languageSection: some View {
        SettingsSection("Language") {
            Picker(
                localization("Language"),
                selection: $generalSettings.settings.language
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(localization(language.displayNameKey)).tag(language)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { generalSettings.settings.launchAtLogin },
            set: { launchAtLoginModel.setRegistered($0) }
        )
    }

    private var launchAtLoginMessageColor: Color {
        launchAtLoginModel.status.canChange ? .secondary : .orange
    }
}
