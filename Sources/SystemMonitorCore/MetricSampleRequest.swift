import Foundation

public struct MetricSampleRequest: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let cpu = MetricSampleRequest(rawValue: 1 << 0)
    public static let memory = MetricSampleRequest(rawValue: 1 << 1)
    public static let disk = MetricSampleRequest(rawValue: 1 << 2)
    public static let network = MetricSampleRequest(rawValue: 1 << 3)
    public static let battery = MetricSampleRequest(rawValue: 1 << 4)
    public static let temperatures = MetricSampleRequest(rawValue: 1 << 5)
    public static let fans = MetricSampleRequest(rawValue: 1 << 6)
    public static let batteryTemperature = MetricSampleRequest(rawValue: 1 << 7)

    public static let all: MetricSampleRequest = [
        .cpu,
        .memory,
        .disk,
        .network,
        .battery,
        .temperatures,
        .fans,
        .batteryTemperature
    ]
}
