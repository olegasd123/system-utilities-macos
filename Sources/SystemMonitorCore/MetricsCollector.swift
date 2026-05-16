import Foundation

final class MetricsCollector: @unchecked Sendable {
    private let cpu: CpuMetricSource
    private let memory: MemoryMetricSource
    private let disk: DiskMetricSource
    private let network: NetworkMetricSource
    private let battery: BatteryMetricSource
    private let sensors: SensorMetricSource
    private let dateProvider: () -> Date
    private let sampleIntervals: MetricSampleIntervals
    private var lastCpu = CpuSample(
        usagePercent: 0,
        coreCount: ProcessInfo.processInfo.processorCount,
        temperatureC: nil
    )
    private var lastMemory = MemorySample(usedBytes: 0, totalBytes: 0, usedPercent: 0)
    private var lastDisks: [DiskSample] = []
    private var lastNetwork = NetworkSample(
        rxBytesPerSec: 0,
        txBytesPerSec: 0,
        totalRxBytes: 0,
        totalTxBytes: 0,
        connectionType: nil
    )
    private var lastBattery: BatterySample?
    private var lastTemperatures: [TemperatureSample] = []
    private var lastFans: [FanSample] = []
    private var lastDiskSampleDate: Date?
    private var lastBatterySampleDate: Date?
    private var lastSensorSampleDate: Date?
    private var lastSensorSampleIncludedFans = false
    private var lastSensorSampleIncludedBatteryTemperature = false

    init(
        cpu: CpuMetricSource = CpuCollector(),
        memory: MemoryMetricSource = MemoryCollector(),
        disk: DiskMetricSource = DiskCollector(),
        network: NetworkMetricSource = NetworkCollector(),
        battery: BatteryMetricSource = BatteryCollector(),
        sensors: SensorMetricSource = DetailedSensorCollector(),
        dateProvider: @escaping () -> Date = Date.init,
        sampleIntervals: MetricSampleIntervals = .defaultValue
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.sensors = sensors
        self.dateProvider = dateProvider
        self.sampleIntervals = sampleIntervals
    }

    func sample(request: MetricSampleRequest = .all) -> Snapshot {
        let now = dateProvider()
        let needsSensors = request.containsAny([.temperatures, .fans, .batteryTemperature])
        let sensorSample = refreshedSensorSample(for: request, now: now)

        if let sensorSample {
            lastTemperatures = sensorSample.temperatures
            if request.contains(.fans) {
                lastFans = sensorSample.fans
            }
        }

        var cpuSample = request.contains(.cpu) ? cpu.sample() : lastCpu
        if needsSensors {
            cpuSample.temperatureC = sensorSample?.cpuTemperatureC ?? lastCpu.temperatureC
        }
        if request.containsAny([.cpu, .temperatures]) {
            lastCpu = cpuSample
        }

        if request.contains(.memory) {
            lastMemory = memory.sample()
        }
        if request.contains(.disk),
           shouldRefresh(lastSampleDate: lastDiskSampleDate, interval: sampleIntervals.disk, now: now) {
            lastDisks = disk.sample()
            lastDiskSampleDate = now
        }
        if request.contains(.network) {
            lastNetwork = network.sample()
        }

        var batterySample = lastBattery
        if request.contains(.battery),
           shouldRefresh(lastSampleDate: lastBatterySampleDate, interval: sampleIntervals.battery, now: now) {
            batterySample = battery.sample()
            lastBatterySampleDate = now
        }
        if request.contains(.batteryTemperature), var sample = batterySample {
            sample.temperatureC = sensorSample?.batteryTemperatureC ?? lastBattery?.temperatureC
            batterySample = sample
        }
        if request.containsAny([.battery, .batteryTemperature]) {
            lastBattery = batterySample
        }

        return Snapshot(
            cpu: cpuSample,
            memory: lastMemory,
            disks: lastDisks,
            network: lastNetwork,
            battery: batterySample,
            temperatures: lastTemperatures,
            fans: lastFans
        )
    }

    private func refreshedSensorSample(for request: MetricSampleRequest, now: Date) -> SensorSample? {
        guard request.containsAny([.temperatures, .fans, .batteryTemperature]) else {
            return nil
        }

        let includeFans = request.contains(.fans)
        let includeBatteryTemperature = request.contains(.batteryTemperature)
        let cacheLacksFans = includeFans && !lastSensorSampleIncludedFans
        let cacheLacksBatteryTemperature = includeBatteryTemperature
            && !lastSensorSampleIncludedBatteryTemperature

        guard cacheLacksFans
            || cacheLacksBatteryTemperature
            || shouldRefresh(
                lastSampleDate: lastSensorSampleDate,
                interval: sampleIntervals.sensors,
                now: now
            )
        else {
            return nil
        }

        let sample = sensors.sample(
            includeFans: includeFans,
            includeBatteryTemperature: includeBatteryTemperature
        )
        lastSensorSampleDate = now
        lastSensorSampleIncludedFans = includeFans
        lastSensorSampleIncludedBatteryTemperature = includeBatteryTemperature
        return sample
    }

    private func shouldRefresh(
        lastSampleDate: Date?,
        interval: TimeInterval,
        now: Date
    ) -> Bool {
        guard interval > 0, let lastSampleDate else {
            return true
        }
        return now.timeIntervalSince(lastSampleDate) >= interval
    }
}

private extension MetricSampleRequest {
    func containsAny(_ members: MetricSampleRequest) -> Bool {
        !intersection(members).isEmpty
    }
}

struct MetricSampleIntervals: Equatable, Sendable {
    var disk: TimeInterval
    var battery: TimeInterval
    var sensors: TimeInterval

    static let defaultValue = MetricSampleIntervals(
        disk: 10,
        battery: 10,
        sensors: 5
    )
}
