@testable import SystemMonitorCore
import XCTest

final class MetricsCollectorTests: XCTestCase {
    func testSamplesOnlyRequestedSources() {
        let sources = CountingSources()
        let collector = sources.makeCollector()

        let snapshot = collector.sample(request: [.cpu, .temperatures])

        XCTAssertEqual(sources.cpu.sampleCount, 1)
        XCTAssertEqual(sources.memory.sampleCount, 0)
        XCTAssertEqual(sources.disk.sampleCount, 0)
        XCTAssertEqual(sources.network.sampleCount, 0)
        XCTAssertEqual(sources.battery.sampleCount, 0)
        XCTAssertEqual(sources.sensors.sampleCount, 1)
        XCTAssertEqual(sources.sensors.includeFansRequests, [false])
        XCTAssertEqual(sources.sensors.includeBatteryTemperatureRequests, [false])
        XCTAssertEqual(snapshot.cpu.usagePercent, 42)
        XCTAssertEqual(snapshot.cpu.temperatureC, 55)
        XCTAssertEqual(snapshot.temperatures, [
            TemperatureSample(label: "Main Chip", temperatureC: 55)
        ])
    }

    func testFullRequestSamplesEverySource() {
        let sources = CountingSources()
        let collector = sources.makeCollector()

        let snapshot = collector.sample(request: .all)

        XCTAssertEqual(sources.cpu.sampleCount, 1)
        XCTAssertEqual(sources.memory.sampleCount, 1)
        XCTAssertEqual(sources.disk.sampleCount, 1)
        XCTAssertEqual(sources.network.sampleCount, 1)
        XCTAssertEqual(sources.battery.sampleCount, 1)
        XCTAssertEqual(sources.sensors.sampleCount, 1)
        XCTAssertEqual(sources.sensors.includeFansRequests, [true])
        XCTAssertEqual(sources.sensors.includeBatteryTemperatureRequests, [true])
        XCTAssertEqual(snapshot.memory.usedPercent, 50)
        XCTAssertEqual(snapshot.disks.count, 1)
        XCTAssertEqual(snapshot.network.totalRxBytes, 100)
        XCTAssertEqual(snapshot.battery?.temperatureC, 31)
        XCTAssertEqual(snapshot.fans, [FanSample(label: "Fan 1", rpm: 1_200)])
    }
}

private final class CountingSources {
    let cpu = CountingCpuSource()
    let memory = CountingMemorySource()
    let disk = CountingDiskSource()
    let network = CountingNetworkSource()
    let battery = CountingBatterySource()
    let sensors = CountingSensorSource()

    func makeCollector() -> MetricsCollector {
        MetricsCollector(
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            battery: battery,
            sensors: sensors
        )
    }
}

private final class CountingCpuSource: CpuMetricSource {
    var sampleCount = 0

    func sample() -> CpuSample {
        sampleCount += 1
        return CpuSample(usagePercent: 42, coreCount: 8, temperatureC: nil)
    }
}

private final class CountingMemorySource: MemoryMetricSource {
    var sampleCount = 0

    func sample() -> MemorySample {
        sampleCount += 1
        return MemorySample(usedBytes: 1, totalBytes: 2, usedPercent: 50)
    }
}

private final class CountingDiskSource: DiskMetricSource {
    var sampleCount = 0

    func sample() -> [DiskSample] {
        sampleCount += 1
        return [
            DiskSample(
                name: "Data",
                mountPoint: "/System/Volumes/Data",
                totalBytes: 100,
                availableBytes: 40,
                usedBytes: 60,
                usedPercent: 60,
                isRemovable: false
            )
        ]
    }
}

private final class CountingNetworkSource: NetworkMetricSource {
    var sampleCount = 0

    func sample() -> NetworkSample {
        sampleCount += 1
        return NetworkSample(
            rxBytesPerSec: 10,
            txBytesPerSec: 20,
            totalRxBytes: 100,
            totalTxBytes: 200,
            connectionType: "Wi-Fi"
        )
    }
}

private final class CountingBatterySource: BatteryMetricSource {
    var sampleCount = 0

    func sample() -> BatterySample? {
        sampleCount += 1
        return BatterySample(
            chargePercent: 80,
            state: .charging,
            timeToFullSecs: nil,
            timeToEmptySecs: nil
        )
    }
}

private final class CountingSensorSource: SensorMetricSource {
    var sampleCount = 0
    var includeFansRequests: [Bool] = []
    var includeBatteryTemperatureRequests: [Bool] = []

    func sample(
        includeFans: Bool,
        includeBatteryTemperature: Bool
    ) -> SensorSample {
        sampleCount += 1
        includeFansRequests.append(includeFans)
        includeBatteryTemperatureRequests.append(includeBatteryTemperature)
        return SensorSample(
            temperatures: [TemperatureSample(label: "Main Chip", temperatureC: 55)],
            fans: includeFans ? [FanSample(label: "Fan 1", rpm: 1_200)] : [],
            cpuTemperatureC: 55,
            batteryTemperatureC: includeBatteryTemperature ? 31 : nil
        )
    }
}
