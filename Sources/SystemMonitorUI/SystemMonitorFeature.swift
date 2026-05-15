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

        let generalStream: AnyPublisher<MenuBarGeneralContext, Never> = general.publisher
            .map { settings in
                MenuBarGeneralContext(
                    temperatureUnit: settings.temperatureUnit,
                    language: settings.language
                )
            }
            .removeDuplicates()
            .eraseToAnyPublisher()

        Publishers.CombineLatest3(model.$snapshot, settings.publisher, generalStream)
            .map { snapshot, settings, general in
                MenuBarFormatter.statusLines(
                    snapshot: snapshot,
                    settings: settings,
                    temperatureUnit: general.temperatureUnit,
                    localization: AppLocalization(selection: general.language)
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
                Self.samplingRequest(active: active, settings: settings)
            }
            .removeDuplicates()
            .sink { [weak self] request in
                guard let self else {
                    return
                }
                if request.isEmpty {
                    self.model.stopSampling()
                } else {
                    self.model.startSampling(request: request)
                }
            }
            .store(in: &cancellables)
    }

    public func setActive(_ active: Bool) {
        isActive = active
    }

    private static func samplingRequest(
        active: Bool,
        settings: SystemMonitorSettings
    ) -> MetricSampleRequest {
        if active {
            return .all
        }

        var request: MetricSampleRequest = []
        let menuBar = settings.menuBar
        if menuBar.showCpuLoad {
            request.insert(.cpu)
        }
        if menuBar.showTemperature {
            request.insert(.temperatures)
        }
        if menuBar.showMemoryUsage {
            request.insert(.memory)
        }
        if menuBar.showDiskFree {
            request.insert(.disk)
        }
        if menuBar.showBattery {
            request.insert(.battery)
        }
        if menuBar.showNetworkSpeed {
            request.insert(.network)
        }

        guard settings.warningsEnabled else {
            return request
        }

        let thresholds = settings.warningThresholds
        if thresholds.cpuEnabled {
            request.insert(.cpu)
        }
        if thresholds.memoryEnabled {
            request.insert(.memory)
        }
        if thresholds.diskEnabled {
            request.insert(.disk)
        }
        if thresholds.batteryEnabled {
            request.insert(.battery)
        }
        if thresholds.temperatureEnabled {
            request.insert(.temperatures)
        }
        return request
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
                settings: settings,
                generalSettings: general
            )
        )
    }
}

private struct MenuBarGeneralContext: Equatable {
    var temperatureUnit: TemperatureUnit
    var language: AppLanguage
}
