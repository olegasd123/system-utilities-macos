import AppCore
import AppUI
import SwiftUI
import SystemMonitorCore

public struct SystemMonitorSettingsView: View {
    @ObservedObject private var settingsModel: SettingsModel<SystemMonitorSettings>
    @ObservedObject private var generalSettings: SettingsModel<GeneralSettings>

    public init(
        settings: SettingsModel<SystemMonitorSettings>,
        generalSettings: SettingsModel<GeneralSettings>
    ) {
        self.settingsModel = settings
        self.generalSettings = generalSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            menuBarSection
            temperatureSection
            notificationsSection
        }
    }

    private var menuBarSection: some View {
        SettingsSection("Show in the menu bar") {
            Picker("Menu bar layout", selection: $settingsModel.settings.menuBar.displayMode) {
                Text("Single line").tag(MenuBarDisplayMode.singleLine)
                Text("Two lines").tag(MenuBarDisplayMode.twoLine)
            }
            .pickerStyle(.segmented)

            Toggle("CPU load", isOn: $settingsModel.settings.menuBar.showCpuLoad)
            Toggle("CPU temperature", isOn: $settingsModel.settings.menuBar.showTemperature)
            Toggle("Memory usage", isOn: $settingsModel.settings.menuBar.showMemoryUsage)
            Toggle("Free disk space", isOn: $settingsModel.settings.menuBar.showDiskFree)
            Toggle("Battery status", isOn: $settingsModel.settings.menuBar.showBattery)
            Toggle("Network speed", isOn: $settingsModel.settings.menuBar.showNetworkSpeed)
            if enabledMenuBarItemCount > 5 {
                Text("Lots of modules enabled. The menu bar may run out of room.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var temperatureSection: some View {
        SettingsSection("Temperature unit") {
            Picker(
                "Temperature unit",
                selection: $generalSettings.settings.temperatureUnit
            ) {
                Text("Celsius").tag(TemperatureUnit.celsius)
                Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    private var notificationsSection: some View {
        SettingsSection("Notifications") {
            Toggle("Enable warning notifications", isOn: $settingsModel.settings.warningsEnabled)
                .onChange(of: settingsModel.settings.warningsEnabled) { _, enabled in
                    if enabled {
                        NotificationPermissionService.requestPermission()
                    }
                }

            if settingsModel.settings.warningsEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    ThresholdRowView(
                        label: "CPU",
                        enabled: $settingsModel.settings.warningThresholds.cpuEnabled,
                        value: $settingsModel.settings.warningThresholds.cpuPercent,
                        unit: "%",
                        range: 1...100
                    )
                    ThresholdRowView(
                        label: "Temperature",
                        enabled: $settingsModel.settings.warningThresholds.temperatureEnabled,
                        value: temperatureThresholdBinding,
                        unit: temperatureThresholdUnit,
                        range: temperatureThresholdRange
                    )
                    ThresholdRowView(
                        label: "Memory",
                        enabled: $settingsModel.settings.warningThresholds.memoryEnabled,
                        value: $settingsModel.settings.warningThresholds.memoryPercent,
                        unit: "%",
                        range: 1...100
                    )
                    ThresholdRowView(
                        label: "Disk free below",
                        enabled: $settingsModel.settings.warningThresholds.diskEnabled,
                        value: $settingsModel.settings.warningThresholds.diskFreePercent,
                        unit: "%",
                        range: 1...99
                    )
                    ThresholdRowView(
                        label: "Battery below",
                        enabled: $settingsModel.settings.warningThresholds.batteryEnabled,
                        value: $settingsModel.settings.warningThresholds.batteryPercent,
                        unit: "%",
                        range: 1...99
                    )
                }
                .padding(.top, 4)
            }
        }
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
        generalSettings.settings.temperatureUnit == .fahrenheit ? "F" : "C"
    }

    private var temperatureThresholdRange: ClosedRange<Double> {
        generalSettings.settings.temperatureUnit == .fahrenheit ? 34...230 : 1...110
    }

    private var temperatureThresholdBinding: Binding<Double> {
        Binding(
            get: {
                let celsius = settingsModel.settings.warningThresholds.temperatureC
                return generalSettings.settings.temperatureUnit == .fahrenheit ? celsius * 1.8 + 32 : celsius
            },
            set: { newValue in
                let celsius = generalSettings.settings.temperatureUnit == .fahrenheit ? (newValue - 32) / 1.8 : newValue
                settingsModel.settings.warningThresholds.temperatureC = celsius
            }
        )
    }
}
