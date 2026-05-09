import Foundation

final class MetricsCollector: @unchecked Sendable {
    private let cpu: CpuMetricSource
    private let memory: MemoryMetricSource
    private let disk: DiskMetricSource
    private let network: NetworkMetricSource
    private let battery: BatteryMetricSource
    private let sensors: SensorMetricSource
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

    init(
        cpu: CpuMetricSource = CpuCollector(),
        memory: MemoryMetricSource = MemoryCollector(),
        disk: DiskMetricSource = DiskCollector(),
        network: NetworkMetricSource = NetworkCollector(),
        battery: BatteryMetricSource = BatteryCollector(),
        sensors: SensorMetricSource = DetailedSensorCollector()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.sensors = sensors
    }

    func sample(request: MetricSampleRequest = .all) -> Snapshot {
        let needsSensors = request.containsAny([.temperatures, .fans, .batteryTemperature])
        let sensorSample = needsSensors
            ? sensors.sample(
                includeFans: request.contains(.fans),
                includeBatteryTemperature: request.contains(.batteryTemperature)
            )
            : nil

        if let sensorSample {
            lastTemperatures = sensorSample.temperatures
            if request.contains(.fans) {
                lastFans = sensorSample.fans
            }
        }

        var cpuSample = request.contains(.cpu) ? cpu.sample() : lastCpu
        if let sensorSample {
            cpuSample.temperatureC = sensorSample.cpuTemperatureC
        }
        if request.containsAny([.cpu, .temperatures]) {
            lastCpu = cpuSample
        }

        if request.contains(.memory) {
            lastMemory = memory.sample()
        }
        if request.contains(.disk) {
            lastDisks = disk.sample()
        }
        if request.contains(.network) {
            lastNetwork = network.sample()
        }

        var batterySample = request.contains(.battery) ? battery.sample() : lastBattery
        if request.contains(.batteryTemperature), var sample = batterySample {
            sample.temperatureC = sensorSample?.batteryTemperatureC
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
}

private extension MetricSampleRequest {
    func containsAny(_ members: MetricSampleRequest) -> Bool {
        !intersection(members).isEmpty
    }
}
