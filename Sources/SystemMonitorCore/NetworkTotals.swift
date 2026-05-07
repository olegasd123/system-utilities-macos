import Foundation

public struct NetworkDailyBaseline: Codable, Equatable {
    public var date: String
    public var rxBytes: UInt64
    public var txBytes: UInt64

    public init(date: String, rxBytes: UInt64, txBytes: UInt64) {
        self.date = date
        self.rxBytes = rxBytes
        self.txBytes = txBytes
    }

    public enum CodingKeys: String, CodingKey {
        case date
        case rxBytes = "rx_bytes"
        case txBytes = "tx_bytes"
    }
}

public struct NetworkTotals: Equatable {
    public var rxBytes: UInt64
    public var txBytes: UInt64

    public init(rxBytes: UInt64, txBytes: UInt64) {
        self.rxBytes = rxBytes
        self.txBytes = txBytes
    }
}
