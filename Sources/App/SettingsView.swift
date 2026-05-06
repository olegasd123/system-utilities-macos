import AppCore
import AppUI
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    let onClose: () -> Void

    private var settings: Binding<AppCore.Settings> {
        $settingsModel.settings
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: PopoverLayout.titleHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back")
                .accessibilityLabel("Back")

                Spacer()

                Text("Preferences")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Color.clear.frame(width: 28, height: PopoverLayout.titleHeight)
            }
            .frame(height: PopoverLayout.titleHeight)
            .padding(.bottom, PopoverLayout.titleSpacing)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsSection("Show in the menu bar") {
                        Picker("Menu bar layout", selection: settings.menuBar.displayMode) {
                            Text("Single line").tag(MenuBarDisplayMode.singleLine)
                            Text("Two lines").tag(MenuBarDisplayMode.twoLine)
                        }
                        .pickerStyle(.segmented)

                        Toggle("CPU load", isOn: settings.menuBar.showCpuLoad)
                        Toggle("CPU temperature", isOn: settings.menuBar.showTemperature)
                        Toggle("Memory usage", isOn: settings.menuBar.showMemoryUsage)
                        Toggle("Free disk space", isOn: settings.menuBar.showDiskFree)
                        Toggle("Battery status", isOn: settings.menuBar.showBattery)
                        Toggle("Network speed", isOn: settings.menuBar.showNetworkSpeed)
                        if enabledMenuBarItemCount > 5 {
                            Text("Lots of modules enabled. The menu bar may run out of room.")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    }

                    settingsSection("Temperature unit") {
                        Picker("Temperature unit", selection: settings.temperatureUnit) {
                            Text("Celsius").tag(TemperatureUnit.celsius)
                            Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    settingsSection("Notifications") {
                        Toggle("Enable warning notifications", isOn: settings.warningsEnabled)
                            .onChange(of: settingsModel.settings.warningsEnabled) { _, enabled in
                                if enabled {
                                    NotificationPermissionService.requestPermission()
                                }
                            }

                        if settingsModel.settings.warningsEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                ThresholdRowView(
                                    label: "CPU",
                                    enabled: settings.warningThresholds.cpuEnabled,
                                    value: settings.warningThresholds.cpuPercent,
                                    unit: "%",
                                    range: 1...100
                                )
                                ThresholdRowView(
                                    label: "Temperature",
                                    enabled: settings.warningThresholds.temperatureEnabled,
                                    value: temperatureThresholdBinding,
                                    unit: temperatureThresholdUnit,
                                    range: temperatureThresholdRange
                                )
                                ThresholdRowView(
                                    label: "Memory",
                                    enabled: settings.warningThresholds.memoryEnabled,
                                    value: settings.warningThresholds.memoryPercent,
                                    unit: "%",
                                    range: 1...100
                                )
                                ThresholdRowView(
                                    label: "Disk free below",
                                    enabled: settings.warningThresholds.diskEnabled,
                                    value: settings.warningThresholds.diskFreePercent,
                                    unit: "%",
                                    range: 1...99
                                )
                                ThresholdRowView(
                                    label: "Battery below",
                                    enabled: settings.warningThresholds.batteryEnabled,
                                    value: settings.warningThresholds.batteryPercent,
                                    unit: "%",
                                    range: 1...99
                                )
                            }
                            .padding(.top, 4)
                        }
                    }

                    settingsSection("Startup") {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(PopoverLayout.contentPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var enabledMenuBarItemCount: Int {
        let menuBar = settingsModel.settings.menuBar
        return [
            menuBar.showCpuLoad,
            menuBar.showTemperature,
            menuBar.showMemoryUsage,
            menuBar.showDiskFree,
            menuBar.showBattery,
            menuBar.showNetworkSpeed
        ].filter { $0 }.count
    }

    private var temperatureThresholdUnit: String {
        settingsModel.settings.temperatureUnit == .fahrenheit ? "F" : "C"
    }

    private var temperatureThresholdRange: ClosedRange<Double> {
        settingsModel.settings.temperatureUnit == .fahrenheit ? 34...230 : 1...110
    }

    private var temperatureThresholdBinding: Binding<Double> {
        Binding(
            get: {
                settingsModel.settings.temperatureUnit == .fahrenheit
                    ? settingsModel.settings.warningThresholds.temperatureC * 1.8 + 32
                    : settingsModel.settings.warningThresholds.temperatureC
            },
            set: { newValue in
                let celsius = settingsModel.settings.temperatureUnit == .fahrenheit
                    ? (newValue - 32) / 1.8
                    : newValue
                settingsModel.settings.warningThresholds.temperatureC = celsius
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsModel.settings.launchAtLogin },
            set: { launchAtLoginModel.setRegistered($0) }
        )
    }

    private var launchAtLoginMessageColor: Color {
        launchAtLoginModel.status.canChange ? .secondary : .orange
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }
}
