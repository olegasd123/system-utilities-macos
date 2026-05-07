import AppCore
import AppUI
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel<AppSettings>
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    let features: [any AppFeature]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                temperatureSection

                ForEach(features, id: \.id) { feature in
                    if let section = feature.makeSettingsSection() {
                        section
                    }
                }

                startupSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var temperatureSection: some View {
        SettingsSection("Temperature unit") {
            Picker(
                "Temperature unit",
                selection: $settingsModel.settings.general.temperatureUnit
            ) {
                Text("Celsius").tag(TemperatureUnit.celsius)
                Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
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
            get: { settingsModel.settings.general.launchAtLogin },
            set: { launchAtLoginModel.setRegistered($0) }
        )
    }

    private var launchAtLoginMessageColor: Color {
        launchAtLoginModel.status.canChange ? .secondary : .orange
    }
}
