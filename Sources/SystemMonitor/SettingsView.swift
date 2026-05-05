import SwiftUI

struct SettingsView: View {
    @Binding var settings: Settings
    let launchAtLoginStatus: LaunchAtLoginStatus
    let onSetLaunchAtLogin: (Bool) -> Void
    let onOpenLoginItems: () -> Void
    let onClose: () -> Void

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
                        Picker("Menu bar layout", selection: $settings.menuBar.displayMode) {
                            Text("Single line").tag(MenuBarDisplayMode.singleLine)
                            Text("Two lines").tag(MenuBarDisplayMode.twoLine)
                        }
                        .pickerStyle(.segmented)

                        Toggle("CPU load", isOn: $settings.menuBar.showCpuLoad)
                        Toggle("CPU temperature", isOn: $settings.menuBar.showTemperature)
                        Toggle("Memory usage", isOn: $settings.menuBar.showMemoryUsage)
                        Toggle("Free disk space", isOn: $settings.menuBar.showDiskFree)
                        Toggle("Battery status", isOn: $settings.menuBar.showBattery)
                        Toggle("Network speed", isOn: $settings.menuBar.showNetworkSpeed)
                        if enabledMenuBarItemCount > 5 {
                            Text("Lots of modules enabled. The menu bar may run out of room.")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    }

                    settingsSection("Temperature unit") {
                        Picker("Temperature unit", selection: $settings.temperatureUnit) {
                            Text("Celsius").tag(TemperatureUnit.celsius)
                            Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    settingsSection("Notifications") {
                        Toggle("Enable warning notifications", isOn: $settings.warningsEnabled)
                            .onChange(of: settings.warningsEnabled) { _, enabled in
                                if enabled {
                                    NotificationPermissionService.requestPermission()
                                }
                            }
                        ThresholdRowView(
                            label: "CPU",
                            enabled: $settings.warningThresholds.cpuEnabled,
                            value: $settings.warningThresholds.cpuPercent,
                            unit: "%",
                            range: 1...100
                        )
                        ThresholdRowView(
                            label: "Temperature",
                            enabled: $settings.warningThresholds.temperatureEnabled,
                            value: temperatureThresholdBinding,
                            unit: temperatureThresholdUnit,
                            range: temperatureThresholdRange
                        )
                        ThresholdRowView(
                            label: "Memory",
                            enabled: $settings.warningThresholds.memoryEnabled,
                            value: $settings.warningThresholds.memoryPercent,
                            unit: "%",
                            range: 1...100
                        )
                        ThresholdRowView(
                            label: "Disk free below",
                            enabled: $settings.warningThresholds.diskEnabled,
                            value: $settings.warningThresholds.diskFreePercent,
                            unit: "%",
                            range: 1...99
                        )
                        ThresholdRowView(
                            label: "Battery below",
                            enabled: $settings.warningThresholds.batteryEnabled,
                            value: $settings.warningThresholds.batteryPercent,
                            unit: "%",
                            range: 1...99
                        )
                    }

                    settingsSection("Startup") {
                        Toggle("Open when Mac starts", isOn: launchAtLoginBinding)
                            .disabled(!launchAtLoginStatus.canChange)

                        if let message = launchAtLoginStatus.message {
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundStyle(launchAtLoginMessageColor)
                        }

                        if launchAtLoginStatus.needsApproval {
                            Button("Open Login Items", action: onOpenLoginItems)
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
        [
            settings.menuBar.showCpuLoad,
            settings.menuBar.showTemperature,
            settings.menuBar.showMemoryUsage,
            settings.menuBar.showDiskFree,
            settings.menuBar.showBattery,
            settings.menuBar.showNetworkSpeed
        ].filter { $0 }.count
    }

    private var temperatureThresholdUnit: String {
        settings.temperatureUnit == .fahrenheit ? "F" : "C"
    }

    private var temperatureThresholdRange: ClosedRange<Double> {
        settings.temperatureUnit == .fahrenheit ? 34...230 : 1...110
    }

    private var temperatureThresholdBinding: Binding<Double> {
        Binding(
            get: {
                settings.temperatureUnit == .fahrenheit
                    ? settings.warningThresholds.temperatureC * 1.8 + 32
                    : settings.warningThresholds.temperatureC
            },
            set: { newValue in
                settings.warningThresholds.temperatureC = settings.temperatureUnit == .fahrenheit
                    ? (newValue - 32) / 1.8
                    : newValue
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { onSetLaunchAtLogin($0) }
        )
    }

    private var launchAtLoginMessageColor: Color {
        launchAtLoginStatus.canChange ? .secondary : .orange
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                content()
            }
        }
    }
}
