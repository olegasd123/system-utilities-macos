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
    func temperatures() -> [TemperatureSample]
    func fans() -> [FanSample]
    func cpuTemperature(from temperatures: [TemperatureSample]) -> Double?
}
