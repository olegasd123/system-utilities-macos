import AppCore
import AppUI
import SwiftUI
import SystemMonitor

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel<AppSettings>
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    let onClose: () -> Void

    private var general: Binding<GeneralSettings> {
        $settingsModel.settings.general
    }

    private var monitor: Binding<SystemMonitorSettings> {
        $settingsModel.settings.systemMonitor
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
                        Picker("Menu bar layout", selection: monitor.menuBar.displayMode) {
                            Text("Single line").tag(MenuBarDisplayMode.singleLine)
                            Text("Two lines").tag(MenuBarDisplayMode.twoLine)
                        }
                        .pickerStyle(.segmented)

                        Toggle("CPU load", isOn: monitor.menuBar.showCpuLoad)
                        Toggle("CPU temperature", isOn: monitor.menuBar.showTemperature)
                        Toggle("Memory usage", isOn: monitor.menuBar.showMemoryUsage)
                        Toggle("Free disk space", isOn: monitor.menuBar.showDiskFree)
                        Toggle("Battery status", isOn: monitor.menuBar.showBattery)
                        Toggle("Network speed", isOn: monitor.menuBar.showNetworkSpeed)
                        if enabledMenuBarItemCount > 5 {
                            Text("Lots of modules enabled. The menu bar may run out of room.")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    }

                    settingsSection("Temperature unit") {
                        Picker("Temperature unit", selection: general.temperatureUnit) {
                            Text("Celsius").tag(TemperatureUnit.celsius)
                            Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    settingsSection("Notifications") {
                        Toggle("Enable warning notifications", isOn: monitor.warningsEnabled)
                            .onChange(of: settingsModel.settings.systemMonitor.warningsEnabled) { _, enabled in
                                if enabled {
                                    NotificationPermissionService.requestPermission()
                                }
                            }

                        if settingsModel.settings.systemMonitor.warningsEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                ThresholdRowView(
                                    label: "CPU",
                                    enabled: monitor.warningThresholds.cpuEnabled,
                                    value: monitor.warningThresholds.cpuPercent,
                                    unit: "%",
                                    range: 1...100
                                )
                                ThresholdRowView(
                                    label: "Temperature",
                                    enabled: monitor.warningThresholds.temperatureEnabled,
                                    value: temperatureThresholdBinding,
                                    unit: temperatureThresholdUnit,
                                    range: temperatureThresholdRange
                                )
                                ThresholdRowView(
                                    label: "Memory",
                                    enabled: monitor.warningThresholds.memoryEnabled,
                                    value: monitor.warningThresholds.memoryPercent,
                                    unit: "%",
                                    range: 1...100
                                )
                                ThresholdRowView(
                                    label: "Disk free below",
                                    enabled: monitor.warningThresholds.diskEnabled,
                                    value: monitor.warningThresholds.diskFreePercent,
                                    unit: "%",
                                    range: 1...99
                                )
                                ThresholdRowView(
                                    label: "Battery below",
                                    enabled: monitor.warningThresholds.batteryEnabled,
                                    value: monitor.warningThresholds.batteryPercent,
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
        let menuBar = settingsModel.settings.systemMonitor.menuBar
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
        settingsModel.settings.general.temperatureUnit == .fahrenheit ? "F" : "C"
    }

    private var temperatureThresholdRange: ClosedRange<Double> {
        settingsModel.settings.general.temperatureUnit == .fahrenheit ? 34...230 : 1...110
    }

    private var temperatureThresholdBinding: Binding<Double> {
        Binding(
            get: {
                let monitor = settingsModel.settings.systemMonitor
                let unit = settingsModel.settings.general.temperatureUnit
                return unit == .fahrenheit
                    ? monitor.warningThresholds.temperatureC * 1.8 + 32
                    : monitor.warningThresholds.temperatureC
            },
            set: { newValue in
                let unit = settingsModel.settings.general.temperatureUnit
                let celsius = unit == .fahrenheit
                    ? (newValue - 32) / 1.8
                    : newValue
                settingsModel.settings.systemMonitor.warningThresholds.temperatureC = celsius
            }
        )
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
