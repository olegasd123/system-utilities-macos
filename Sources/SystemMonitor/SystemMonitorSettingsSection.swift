import AppCore
import AppUI
import SwiftUI

public struct SystemMonitorSettingsSection: View {
    @Binding private var settings: SystemMonitorSettings
    @Binding private var temperatureUnit: TemperatureUnit

    public init(
        settings: Binding<SystemMonitorSettings>,
        temperatureUnit: Binding<TemperatureUnit>
    ) {
        self._settings = settings
        self._temperatureUnit = temperatureUnit
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
    }

    private var temperatureSection: some View {
        SettingsSection("Temperature unit") {
            Picker(
                "Temperature unit",
                selection: $temperatureUnit
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
            Toggle("Enable warning notifications", isOn: $settings.warningsEnabled)
                .onChange(of: settings.warningsEnabled) { _, enabled in
                    if enabled {
                        NotificationPermissionService.requestPermission()
                    }
                }

            if settings.warningsEnabled {
                VStack(alignment: .leading, spacing: 10) {
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
                .padding(.top, 4)
            }
        }
    }

    private var enabledMenuBarItemCount: Int {
        let menuBar = settings.menuBar
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
        temperatureUnit == .fahrenheit ? "F" : "C"
    }

    private var temperatureThresholdRange: ClosedRange<Double> {
        temperatureUnit == .fahrenheit ? 34...230 : 1...110
    }

    private var temperatureThresholdBinding: Binding<Double> {
        Binding(
            get: {
                let celsius = settings.warningThresholds.temperatureC
                return temperatureUnit == .fahrenheit ? celsius * 1.8 + 32 : celsius
            },
            set: { newValue in
                let celsius = temperatureUnit == .fahrenheit ? (newValue - 32) / 1.8 : newValue
                settings.warningThresholds.temperatureC = celsius
            }
        )
    }
}
