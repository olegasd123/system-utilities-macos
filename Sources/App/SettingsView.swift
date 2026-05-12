import AppCore
import AppUI
import SwiftUI

struct SettingsView: View {
    @ObservedObject var generalSettings: SettingsModel<GeneralSettings>
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    let features: [any AppFeature]
    var focusedFeatureId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(visibleFeatures, id: \.id) { feature in
                    if let section = feature.makeSettingsSection() {
                        section
                    }
                }

                if focusedFeatureId == nil {
                    startupSection
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
            Toggle("Open when Mac starts", isOn: launchAtLoginBinding)
                .disabled(!launchAtLoginModel.status.canChange)

            if let message = launchAtLoginModel.status.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(launchAtLoginMessageColor)
            }

            if launchAtLoginModel.status.needsApproval {
                Button("Open Login Items") {
                    launchAtLoginModel.openLoginItemsSettings()
                }
                .controlSize(.small)
            }
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
