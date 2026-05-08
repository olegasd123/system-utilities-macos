import AppCore
import Foundation

@MainActor
public final class SystemMonitorModel: ObservableObject {
    @Published public private(set) var snapshot: Snapshot?
    @Published public private(set) var networkTotals: NetworkTotals?

    private let settings: SettingsModel<SystemMonitorSettings>
    private let networkTotalsStore: NetworkTotalsStore
    private let metricsSampler = MetricsSampler()
    private let warningService = WarningService()
    private let dateProvider: () -> Date
    private var networkBaseline: NetworkDailyBaseline?
    private var isSampling = false

    public convenience init(
        settings: SettingsModel<SystemMonitorSettings>,
        networkTotalsStore: NetworkTotalsStore = .standard
    ) {
        self.init(
            settings: settings,
            networkTotalsStore: networkTotalsStore,
            dateProvider: Date.init
        )
    }

    init(
        settings: SettingsModel<SystemMonitorSettings>,
        networkTotalsStore: NetworkTotalsStore,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.settings = settings
        self.networkTotalsStore = networkTotalsStore
        self.dateProvider = dateProvider
        self.networkBaseline = networkTotalsStore.load()
    }

    public func startSampling() {
        guard !isSampling else {
            return
        }
        isSampling = true
        metricsSampler.start { [weak self] snapshot in
            self?.apply(snapshot: snapshot)
        }
    }

    public func stopSampling() {
        guard isSampling else {
            return
        }
        isSampling = false
        metricsSampler.stop()
    }

    public func resetNetworkTotals() {
        guard let snapshot else {
            return
        }

        let baseline = createNetworkBaseline(from: snapshot, date: localDateKey())
        networkBaseline = baseline
        networkTotals = NetworkTotals(rxBytes: 0, txBytes: 0)
        try? networkTotalsStore.save(baseline)
    }

    func apply(snapshot: Snapshot) {
        self.snapshot = snapshot
        updateNetworkTotals(snapshot: snapshot)
        warningService.evaluate(snapshot: snapshot, settings: settings.settings)
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

    private func localDateKey() -> String {
        let date = dateProvider()
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
