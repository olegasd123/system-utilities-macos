import AppCore
@testable import SystemMonitorCore
import XCTest

final class SystemMonitorModelTests: XCTestCase {
    private var bundleIds: [String] = []

    override func tearDownWithError() throws {
        for bundleId in bundleIds {
            try? FileManager.default.removeItem(at: storeDirectory(bundleId: bundleId))
        }
        bundleIds = []
        try super.tearDownWithError()
    }

    @MainActor
    func testFirstSampleCreatesDailyBaselineAndLaterSamplesReportDeltas() {
        let bundleId = uniqueBundleId()
        let store = NetworkTotalsStore(bundleId: bundleId)
        let model = makeModel(store: store, date: date("2026-05-08"))

        model.apply(snapshot: snapshot(totalRxBytes: 1_000, totalTxBytes: 200))

        XCTAssertEqual(model.networkTotals, NetworkTotals(rxBytes: 0, txBytes: 0))
        XCTAssertEqual(store.load(), NetworkDailyBaseline(date: "2026-05-08", rxBytes: 1_000, txBytes: 200))

        model.apply(snapshot: snapshot(totalRxBytes: 1_500, totalTxBytes: 260))

        XCTAssertEqual(model.networkTotals, NetworkTotals(rxBytes: 500, txBytes: 60))
        XCTAssertEqual(store.load(), NetworkDailyBaseline(date: "2026-05-08", rxBytes: 1_000, txBytes: 200))
    }

    @MainActor
    func testExistingSameDayBaselineIsLoaded() throws {
        let bundleId = uniqueBundleId()
        let store = NetworkTotalsStore(bundleId: bundleId)
        try store.save(NetworkDailyBaseline(date: "2026-05-08", rxBytes: 100, txBytes: 40))
        let model = makeModel(store: store, date: date("2026-05-08"))

        model.apply(snapshot: snapshot(totalRxBytes: 175, totalTxBytes: 90))

        XCTAssertEqual(model.networkTotals, NetworkTotals(rxBytes: 75, txBytes: 50))
    }

    @MainActor
    func testNewDayCreatesNewBaseline() throws {
        let bundleId = uniqueBundleId()
        let store = NetworkTotalsStore(bundleId: bundleId)
        try store.save(NetworkDailyBaseline(date: "2026-05-07", rxBytes: 100, txBytes: 40))
        let model = makeModel(store: store, date: date("2026-05-08"))

        model.apply(snapshot: snapshot(totalRxBytes: 175, totalTxBytes: 90))

        XCTAssertEqual(model.networkTotals, NetworkTotals(rxBytes: 0, txBytes: 0))
        XCTAssertEqual(store.load(), NetworkDailyBaseline(date: "2026-05-08", rxBytes: 175, txBytes: 90))
    }

    @MainActor
    func testCounterResetCreatesNewBaseline() throws {
        let bundleId = uniqueBundleId()
        let store = NetworkTotalsStore(bundleId: bundleId)
        try store.save(NetworkDailyBaseline(date: "2026-05-08", rxBytes: 10_000, txBytes: 9_000))
        let model = makeModel(store: store, date: date("2026-05-08"))

        model.apply(snapshot: snapshot(totalRxBytes: 100, totalTxBytes: 50))

        XCTAssertEqual(model.networkTotals, NetworkTotals(rxBytes: 0, txBytes: 0))
        XCTAssertEqual(store.load(), NetworkDailyBaseline(date: "2026-05-08", rxBytes: 100, txBytes: 50))
    }

    @MainActor
    func testResetNetworkTotalsUsesCurrentSnapshotAsNewBaseline() {
        let bundleId = uniqueBundleId()
        let store = NetworkTotalsStore(bundleId: bundleId)
        let model = makeModel(store: store, date: date("2026-05-08"))
        model.apply(snapshot: snapshot(totalRxBytes: 1_000, totalTxBytes: 200))
        model.apply(snapshot: snapshot(totalRxBytes: 1_250, totalTxBytes: 300))

        model.resetNetworkTotals()

        XCTAssertEqual(model.networkTotals, NetworkTotals(rxBytes: 0, txBytes: 0))
        XCTAssertEqual(store.load(), NetworkDailyBaseline(date: "2026-05-08", rxBytes: 1_250, txBytes: 300))
    }

    @MainActor
    private func makeModel(store: NetworkTotalsStore, date: Date) -> SystemMonitorModel {
        SystemMonitorModel(
            settings: SettingsModel(initial: .defaultValue) { _ in },
            networkTotalsStore: store,
            dateProvider: { date }
        )
    }

    private func snapshot(totalRxBytes: UInt64, totalTxBytes: UInt64) -> Snapshot {
        Snapshot(
            cpu: CpuSample(usagePercent: 10, coreCount: 8, temperatureC: 40),
            memory: MemorySample(usedBytes: 1, totalBytes: 2, usedPercent: 50),
            disks: [],
            network: NetworkSample(
                rxBytesPerSec: 0,
                txBytesPerSec: 0,
                totalRxBytes: totalRxBytes,
                totalTxBytes: totalTxBytes,
                connectionType: nil
            ),
            battery: nil,
            temperatures: [],
            fans: []
        )
    }

    private func uniqueBundleId() -> String {
        let bundleId = "dev.oleg-verhoglyad.SystemMonitorModelTests.\(UUID().uuidString)"
        bundleIds.append(bundleId)
        return bundleId
    }

    private func storeDirectory(bundleId: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bundleId, isDirectory: true)
    }

    private func date(_ string: String) -> Date {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        return Calendar.current.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
        )!
    }
}
