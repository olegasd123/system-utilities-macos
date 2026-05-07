import Foundation

final class MetricsCollector {
    private var cpuCollector = CpuCollector()
    private var networkCollector = NetworkCollector()
    private var sensorCollector = DetailedSensorCollector()

    func sample() -> Snapshot {
        let temperatures = sensorCollector.temperatures()
        let fans = sensorCollector.fans()
        var cpu = cpuCollector.sample()
        cpu.temperatureC = sensorCollector.cpuTemperature(from: temperatures)
        let memory = MemoryCollector.sample()
        let disks = DiskCollector.sample()
        let network = networkCollector.sample()
        let battery = BatteryCollector.sample()

        return Snapshot(
            cpu: cpu,
            memory: memory,
            disks: disks,
            network: network,
            battery: battery,
            temperatures: temperatures,
            fans: fans
        )
    }
}
