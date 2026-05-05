import Foundation

final class MetricsCollector {
    private var cpuCollector = CpuCollector()
    private var networkCollector = NetworkCollector()

    func sample() -> Snapshot {
        let cpu = cpuCollector.sample()
        let memory = MemoryCollector.sample()
        let disks = DiskCollector.sample()
        let network = networkCollector.sample()

        return Snapshot(
            cpu: cpu,
            memory: memory,
            disks: disks,
            network: network,
            battery: nil,
            temperatures: [],
            fans: []
        )
    }
}
