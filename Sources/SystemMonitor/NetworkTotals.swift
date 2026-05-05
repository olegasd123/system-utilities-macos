import Foundation

struct NetworkDailyBaseline: Codable, Equatable {
    var date: String
    var rxBytes: UInt64
    var txBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case date
        case rxBytes = "rx_bytes"
        case txBytes = "tx_bytes"
    }
}

struct NetworkTotals: Equatable {
    var rxBytes: UInt64
    var txBytes: UInt64
}
