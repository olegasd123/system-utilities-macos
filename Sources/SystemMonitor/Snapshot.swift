import Foundation

public struct CpuSample: Equatable {
    public var usagePercent: Double
    public var coreCount: Int
    public var temperatureC: Double?

    public init(usagePercent: Double, coreCount: Int, temperatureC: Double?) {
        self.usagePercent = usagePercent
        self.coreCount = coreCount
        self.temperatureC = temperatureC
    }
}

public struct MemorySample: Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
    public var usedPercent: Double

    public init(usedBytes: UInt64, totalBytes: UInt64, usedPercent: Double) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.usedPercent = usedPercent
    }
}

public struct DiskSample: Identifiable, Equatable {
    public var id: String { mountPoint }
    public var name: String
    public var mountPoint: String
    public var totalBytes: UInt64
    public var availableBytes: UInt64
    public var usedBytes: UInt64
    public var usedPercent: Double
    public var isRemovable: Bool

    public init(
        name: String,
        mountPoint: String,
        totalBytes: UInt64,
        availableBytes: UInt64,
        usedBytes: UInt64,
        usedPercent: Double,
        isRemovable: Bool
    ) {
        self.name = name
        self.mountPoint = mountPoint
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.usedBytes = usedBytes
        self.usedPercent = usedPercent
        self.isRemovable = isRemovable
    }
}

public struct NetworkSample: Equatable {
    public var rxBytesPerSec: UInt64
    public var txBytesPerSec: UInt64
    public var totalRxBytes: UInt64
    public var totalTxBytes: UInt64
    public var primaryInterface: String?
    public var connectionType: String?

    public init(
        rxBytesPerSec: UInt64,
        txBytesPerSec: UInt64,
        totalRxBytes: UInt64,
        totalTxBytes: UInt64,
        primaryInterface: String?,
        connectionType: String?
    ) {
        self.rxBytesPerSec = rxBytesPerSec
        self.txBytesPerSec = txBytesPerSec
        self.totalRxBytes = totalRxBytes
        self.totalTxBytes = totalTxBytes
        self.primaryInterface = primaryInterface
        self.connectionType = connectionType
    }
}

public enum BatteryState: String, Equatable {
    case charging
    case discharging
    case empty
    case full
    case unknown
}

public struct BatterySample: Equatable {
    public var chargePercent: Double
    public var state: BatteryState
    public var timeToFullSecs: UInt64?
    public var timeToEmptySecs: UInt64?
    public var cycleCount: UInt32?

    public init(
        chargePercent: Double,
        state: BatteryState,
        timeToFullSecs: UInt64?,
        timeToEmptySecs: UInt64?,
        cycleCount: UInt32?
    ) {
        self.chargePercent = chargePercent
        self.state = state
        self.timeToFullSecs = timeToFullSecs
        self.timeToEmptySecs = timeToEmptySecs
        self.cycleCount = cycleCount
    }
}

public struct TemperatureSample: Identifiable, Equatable {
    public var id: String { label }
    public var label: String
    public var temperatureC: Double
    public var criticalC: Double?

    public init(label: String, temperatureC: Double, criticalC: Double?) {
        self.label = label
        self.temperatureC = temperatureC
        self.criticalC = criticalC
    }
}

public struct FanSample: Identifiable, Equatable {
    public var id: String { label }
    public var label: String
    public var rpm: UInt32

    public init(label: String, rpm: UInt32) {
        self.label = label
        self.rpm = rpm
    }
}

public struct Snapshot: Equatable {
    public var cpu: CpuSample
    public var memory: MemorySample
    public var disks: [DiskSample]
    public var network: NetworkSample
    public var battery: BatterySample?
    public var temperatures: [TemperatureSample]
    public var fans: [FanSample]

    public init(
        cpu: CpuSample,
        memory: MemorySample,
        disks: [DiskSample],
        network: NetworkSample,
        battery: BatterySample?,
        temperatures: [TemperatureSample],
        fans: [FanSample]
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disks = disks
        self.network = network
        self.battery = battery
        self.temperatures = temperatures
        self.fans = fans
    }
}
