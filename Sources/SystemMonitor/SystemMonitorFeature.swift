import AppCore
import AppUI
import Combine
import Foundation
import SwiftUI

@MainActor
public final class SystemMonitorFeature: ObservableObject, PopoverFeature, MenuBarFeature {
    public let id = "system-monitor"
    public let displayName = "System Monitor"
    public let symbolName = "gauge.with.dots.needle.67percent"

    public let model: SystemMonitorModel

    @Published public private(set) var menuBarLines: [MenuBarStatusLine] = []
    @Published private var isActive = false

    public var currentMenuBarLines: [MenuBarStatusLine] { menuBarLines }
    public var menuBarLinesPublisher: AnyPublisher<[MenuBarStatusLine], Never> {
        $menuBarLines.eraseToAnyPublisher()
    }

    private let currentSettings: () -> SystemMonitorSettings
    private let currentTemperatureUnit: () -> TemperatureUnit
    private let settingsBinding: Binding<SystemMonitorSettings>

    private var cancellables: Set<AnyCancellable> = []

    public init(
        model: SystemMonitorModel,
        currentSettings: @escaping () -> SystemMonitorSettings,
        currentTemperatureUnit: @escaping () -> TemperatureUnit,
        settingsBinding: Binding<SystemMonitorSettings>,
        settingsChanges: AnyPublisher<SystemMonitorSettings, Never>,
        temperatureUnitChanges: AnyPublisher<TemperatureUnit, Never>
    ) {
        self.model = model
        self.currentSettings = currentSettings
        self.currentTemperatureUnit = currentTemperatureUnit
        self.settingsBinding = settingsBinding

        let settingsStream = settingsChanges
            .prepend(currentSettings())
            .eraseToAnyPublisher()
        let unitStream = temperatureUnitChanges
            .prepend(currentTemperatureUnit())
            .eraseToAnyPublisher()

        Publishers.CombineLatest3(model.$snapshot, settingsStream, unitStream)
            .map { snapshot, settings, unit in
                MenuBarFormatter.statusLines(
                    snapshot: snapshot,
                    settings: settings,
                    temperatureUnit: unit
                )
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] lines in
                self?.menuBarLines = lines
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($isActive, settingsStream)
            .map { active, settings in
                active || Self.menuBarOrWarningsNeedSampling(settings)
            }
            .removeDuplicates()
            .sink { [weak self] needsSampling in
                guard let self else {
                    return
                }
                if needsSampling {
                    self.model.startSampling()
                } else {
                    self.model.stopSampling()
                }
            }
            .store(in: &cancellables)
    }

    public func setActive(_ active: Bool) {
        isActive = active
    }

    private static func menuBarOrWarningsNeedSampling(_ settings: SystemMonitorSettings) -> Bool {
        let menuBar = settings.menuBar
        return menuBar.showCpuLoad
            || menuBar.showTemperature
            || menuBar.showMemoryUsage
            || menuBar.showDiskFree
            || menuBar.showBattery
            || menuBar.showNetworkSpeed
            || settings.warningsEnabled
    }

    public func makeRootView() -> AnyView {
        AnyView(
            DashboardView(
                model: model,
                settings: currentSettings(),
                temperatureUnit: currentTemperatureUnit()
            )
        )
    }

    public func makeSettingsSection() -> AnyView? {
        AnyView(
            SystemMonitorSettingsSection(
                settings: settingsBinding,
                temperatureUnit: currentTemperatureUnit()
            )
        )
    }
}
