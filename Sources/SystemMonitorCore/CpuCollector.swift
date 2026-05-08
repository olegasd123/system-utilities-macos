import Darwin
import Foundation

final class CpuCollector: CpuMetricSource {
    private var previousLoads: [processor_cpu_load_info] = []

    func sample() -> CpuSample {
        guard let loads = readProcessorLoads(), !loads.isEmpty else {
            return CpuSample(usagePercent: 0, coreCount: ProcessInfo.processInfo.processorCount, temperatureC: nil)
        }

        defer {
            previousLoads = loads
        }

        guard previousLoads.count == loads.count else {
            return CpuSample(usagePercent: 0, coreCount: loads.count, temperatureC: nil)
        }

        var activeDelta: UInt64 = 0
        var totalDelta: UInt64 = 0

        for (current, previous) in zip(loads, previousLoads) {
            let user = delta(current.cpu_ticks.0, previous.cpu_ticks.0)
            let system = delta(current.cpu_ticks.1, previous.cpu_ticks.1)
            let idle = delta(current.cpu_ticks.2, previous.cpu_ticks.2)
            let nice = delta(current.cpu_ticks.3, previous.cpu_ticks.3)

            activeDelta += user + system + nice
            totalDelta += user + system + idle + nice
        }

        let usage = totalDelta == 0 ? 0 : Double(activeDelta) / Double(totalDelta) * 100
        return CpuSample(usagePercent: usage, coreCount: loads.count, temperatureC: nil)
    }

    private func readProcessorLoads() -> [processor_cpu_load_info]? {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let processorInfo else {
            return nil
        }

        defer {
            let byteCount = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), byteCount)
        }

        let capacity = Int(processorCount)
        return (0..<capacity).map { index in
            let offset = index * Int(CPU_STATE_MAX)
            return processor_cpu_load_info(
                cpu_ticks: (
                    UInt32(processorInfo[offset + Int(CPU_STATE_USER)]),
                    UInt32(processorInfo[offset + Int(CPU_STATE_SYSTEM)]),
                    UInt32(processorInfo[offset + Int(CPU_STATE_IDLE)]),
                    UInt32(processorInfo[offset + Int(CPU_STATE_NICE)])
                )
            )
        }
    }

    private func delta(_ current: UInt32, _ previous: UInt32) -> UInt64 {
        if current >= previous {
            return UInt64(current - previous)
        }
        return UInt64(current) + UInt64(UInt32.max - previous)
    }
}
