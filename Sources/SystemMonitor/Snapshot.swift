import Foundation

struct CpuSample: Equatable {
    var usagePercent: Double
    var coreCount: Int
    var temperatureC: Double?
}

struct MemorySample: Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64
    var usedPercent: Double
}

struct DiskSample: Identifiable, Equatable {
    var id: String { mountPoint }
    var name: String
    var mountPoint: String
    var totalBytes: UInt64
    var availableBytes: UInt64
    var usedBytes: UInt64
    var usedPercent: Double
    var isRemovable: Bool
}

struct NetworkSample: Equatable {
    var rxBytesPerSec: UInt64
    var txBytesPerSec: UInt64
    var totalRxBytes: UInt64
    var totalTxBytes: UInt64
    var primaryInterface: String?
    var connectionType: String?
}

enum BatteryState: String, Equatable {
    case charging
    case discharging
    case empty
    case full
    case unknown
}

struct BatterySample: Equatable {
    var chargePercent: Double
    var state: BatteryState
    var timeToFullSecs: UInt64?
    var timeToEmptySecs: UInt64?
    var cycleCount: UInt32?
}

struct TemperatureSample: Identifiable, Equatable {
    var id: String { label }
    var label: String
    var temperatureC: Double
    var criticalC: Double?
}

struct FanSample: Identifiable, Equatable {
    var id: String { label }
    var label: String
    var rpm: UInt32
}

struct Snapshot: Equatable {
    var cpu: CpuSample
    var memory: MemorySample
    var disks: [DiskSample]
    var network: NetworkSample
    var battery: BatterySample?
    var temperatures: [TemperatureSample]
    var fans: [FanSample]
}
