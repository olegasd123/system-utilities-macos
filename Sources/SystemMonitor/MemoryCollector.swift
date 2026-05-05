import Darwin
import Foundation

enum MemoryCollector {
    static func sample() -> MemorySample {
        let total = ProcessInfo.processInfo.physicalMemory
        let used = activityMonitorUsedMemory(total: total) ?? 0
        return MemorySample(
            usedBytes: used,
            totalBytes: total,
            usedPercent: total == 0 ? 0 : Double(used) / Double(total) * 100
        )
    }

    private static func activityMonitorUsedMemory(total: UInt64) -> UInt64? {
        guard let pageSize = pageSize(), let stat = vmStatistics() else {
            return nil
        }

        let appPages = UInt64(stat.internal_page_count).saturatingSubtract(UInt64(stat.purgeable_count))
        let usedPages = appPages
            .saturatingAdd(UInt64(stat.wire_count))
            .saturatingAdd(UInt64(stat.compressor_page_count))
        let used = usedPages.saturatingMultiply(by: pageSize)
        return total > 0 ? min(used, total) : used
    }

    private static func vmStatistics() -> vm_statistics64? {
        var stat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stat) { statPointer in
            statPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    reboundPointer,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? stat : nil
    }

    private static func pageSize() -> UInt64? {
        let value = sysconf(_SC_PAGESIZE)
        return value > 0 ? UInt64(value) : nil
    }
}

private extension UInt64 {
    func saturatingAdd(_ value: UInt64) -> UInt64 {
        let (result, overflow) = addingReportingOverflow(value)
        return overflow ? UInt64.max : result
    }

    func saturatingSubtract(_ value: UInt64) -> UInt64 {
        self >= value ? self - value : 0
    }

    func saturatingMultiply(by value: UInt64) -> UInt64 {
        let (result, overflow) = multipliedReportingOverflow(by: value)
        return overflow ? UInt64.max : result
    }
}
