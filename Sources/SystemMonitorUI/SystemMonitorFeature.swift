import AppCore
import AppUI
import Combine
import Foundation
import SwiftUI
import SystemMonitorCore

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

    private let settings: SettingsModel<SystemMonitorSettings>
    private let general: SettingsModel<GeneralSettings>

    private var cancellables: Set<AnyCancellable> = []

    public init(
        settings: SettingsModel<SystemMonitorSettings>,
        general: SettingsModel<GeneralSettings>,
        model: SystemMonitorModel
    ) {
        self.settings = settings
        self.general = general
        self.model = model

        let unitStream = general.publisher
            .map(\.temperatureUnit)
            .removeDuplicates()
            .eraseToAnyPublisher()

        Publishers.CombineLatest3(model.$snapshot, settings.publisher, unitStream)
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

        Publishers.CombineLatest($isActive, settings.publisher)
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
                settings: settings.settings,
                temperatureUnit: general.settings.temperatureUnit
            )
        )
    }

    public func makeSettingsSection() -> AnyView? {
        AnyView(
            SystemMonitorSettingsView(
                settings: settings.binding,
                temperatureUnit: temperatureUnitBinding
            )
        )
    }

    private var temperatureUnitBinding: Binding<TemperatureUnit> {
        Binding(
            get: { [unowned self] in general.settings.temperatureUnit },
            set: { [unowned self] in general.settings.temperatureUnit = $0 }
        )
    }
}
