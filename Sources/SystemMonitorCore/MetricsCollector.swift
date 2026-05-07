import Foundation

final class MetricsCollector {
    private let cpu: CpuMetricSource
    private let memory: MemoryMetricSource
    private let disk: DiskMetricSource
    private let network: NetworkMetricSource
    private let battery: BatteryMetricSource
    private let sensors: SensorMetricSource

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

    func sample() -> Snapshot {
        let temperatures = sensors.temperatures()
        let fans = sensors.fans()
        var cpuSample = cpu.sample()
        cpuSample.temperatureC = sensors.cpuTemperature(from: temperatures)
        var batterySample = battery.sample()
        batterySample?.temperatureC = sensors.batteryTemperatureC()

        return Snapshot(
            cpu: cpuSample,
            memory: memory.sample(),
            disks: disk.sample(),
            network: network.sample(),
            battery: batterySample,
            temperatures: temperatures,
            fans: fans
        )
    }
}
