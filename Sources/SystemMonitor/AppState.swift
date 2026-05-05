import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var networkTotals: NetworkTotals?
    @Published var launchAtLoginStatus: LaunchAtLoginStatus
    @Published var settings: Settings {
        didSet {
            try? settingsStore.save(settings)
        }
    }

    private let settingsStore: SettingsStore
    private let networkTotalsStore: NetworkTotalsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let metricsSampler = MetricsSampler()
    private let warningService = WarningService()
    private var networkBaseline: NetworkDailyBaseline?

    init(
        settingsStore: SettingsStore = .standard,
        networkTotalsStore: NetworkTotalsStore = .standard,
        launchAtLoginService: LaunchAtLoginService = .standard
    ) {
        self.settingsStore = settingsStore
        self.networkTotalsStore = networkTotalsStore
        self.launchAtLoginService = launchAtLoginService
        let currentLaunchAtLoginStatus = launchAtLoginService.status()
        launchAtLoginStatus = currentLaunchAtLoginStatus
        var loadedSettings = settingsStore.load()
        loadedSettings.launchAtLogin = currentLaunchAtLoginStatus.isRegistered
        settings = loadedSettings
        networkBaseline = networkTotalsStore.load()
        metricsSampler.start { [weak self] snapshot in
            self?.apply(snapshot: snapshot)
        }
    }

    func resetNetworkTotals() {
        guard let snapshot else {
            return
        }

        let baseline = createNetworkBaseline(from: snapshot, date: localDateKey())
        networkBaseline = baseline
        networkTotals = NetworkTotals(rxBytes: 0, txBytes: 0)
        try? networkTotalsStore.save(baseline)
    }

    func setLaunchAtLogin(_ isRegistered: Bool) {
        launchAtLoginStatus = launchAtLoginService.setRegistered(isRegistered)
        settings.launchAtLogin = launchAtLoginStatus.isRegistered
    }

    func openLoginItemsSettings() {
        launchAtLoginService.openLoginItemsSettings()
        launchAtLoginStatus = launchAtLoginService.status()
        settings.launchAtLogin = launchAtLoginStatus.isRegistered
    }

    private func apply(snapshot: Snapshot) {
        self.snapshot = snapshot
        updateNetworkTotals(snapshot: snapshot)
        warningService.evaluate(snapshot: snapshot, settings: settings)
    }

    private func updateNetworkTotals(snapshot: Snapshot) {
        let baseline = normalizedNetworkBaseline(for: snapshot)
        networkBaseline = baseline
        networkTotals = NetworkTotals(
            rxBytes: snapshot.network.totalRxBytes.saturatingSubtract(baseline.rxBytes),
            txBytes: snapshot.network.totalTxBytes.saturatingSubtract(baseline.txBytes)
        )
    }

    private func normalizedNetworkBaseline(for snapshot: Snapshot) -> NetworkDailyBaseline {
        let today = localDateKey()
        let countersReset = networkBaseline.map {
            snapshot.network.totalRxBytes < $0.rxBytes
                || snapshot.network.totalTxBytes < $0.txBytes
        } ?? false

        if let networkBaseline, networkBaseline.date == today, !countersReset {
            return networkBaseline
        }

        let baseline = createNetworkBaseline(from: snapshot, date: today)
        try? networkTotalsStore.save(baseline)
        return baseline
    }

    private func createNetworkBaseline(from snapshot: Snapshot, date: String) -> NetworkDailyBaseline {
        NetworkDailyBaseline(
            date: date,
            rxBytes: snapshot.network.totalRxBytes,
            txBytes: snapshot.network.totalTxBytes
        )
    }

    private func localDateKey(date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

private extension UInt64 {
    func saturatingSubtract(_ value: UInt64) -> UInt64 {
        self >= value ? self - value : 0
    }
}
