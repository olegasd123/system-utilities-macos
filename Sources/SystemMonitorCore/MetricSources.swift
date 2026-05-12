import Foundation

protocol CpuMetricSource {
    func sample() -> CpuSample
}

protocol MemoryMetricSource {
    func sample() -> MemorySample
}

protocol DiskMetricSource {
    func sample() -> [DiskSample]
}

protocol NetworkMetricSource {
    func sample() -> NetworkSample
}

protocol BatteryMetricSource {
    func sample() -> BatterySample?
}

protocol SensorMetricSource {
    func sample(includeFans: Bool, includeBatteryTemperature: Bool) -> SensorSample
}

struct SensorSample: Equatable, Sendable {
    var temperatures: [TemperatureSample]
    var fans: [FanSample]
    var cpuTemperatureC: Double?
    var batteryTemperatureC: Double?
}
