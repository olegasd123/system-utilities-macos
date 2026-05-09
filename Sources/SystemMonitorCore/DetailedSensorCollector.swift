import Foundation
import MacSensorBridge

final class DetailedSensorCollector: SensorMetricSource {
    private let context: OpaquePointer?

    init() {
        context = MacSensorContextCreate()
    }

    deinit {
        if let context {
            MacSensorContextDestroy(context)
        }
    }

    func temperatures() -> [TemperatureSample] {
        let hid = readTemperatures(copyFunction: MacSensorCopyHidTemperatures)
        if !hid.isEmpty {
            return group(hid).map {
                TemperatureSample(label: $0.label, temperatureC: $0.temperatureC)
            }
        }

        return readTemperatures(copyFunction: MacSensorCopySmcTemperatures).map {
            TemperatureSample(label: $0.label, temperatureC: $0.temperatureC)
        }
    }

    func fans() -> [FanSample] {
        var readingsPointer: UnsafeMutablePointer<MacSensorReading>?
        let count = MacSensorCopyFans(context, &readingsPointer)
        guard let readingsPointer, count > 0 else {
            return []
        }
        defer {
            MacSensorReadingsFree(readingsPointer, count)
        }

        return (0..<Int(count)).compactMap { index in
            let reading = readingsPointer[index]
            guard let label = reading.label else {
                return nil
            }
            return FanSample(
                label: String(cString: label),
                rpm: UInt32(max(0, reading.value).rounded())
            )
        }
    }

    func cpuTemperature(from temperatures: [TemperatureSample]) -> Double? {
        let cluster = temperatures
            .filter {
                $0.label == SensorLabels.performanceCores
                    || $0.label == SensorLabels.efficiencyCores
            }
            .map(\.temperatureC)
        if !cluster.isEmpty {
            return cluster.reduce(0, +) / Double(cluster.count)
        }

        if let mainChip = temperatures.first(where: { $0.label == SensorLabels.mainChip }) {
            return mainChip.temperatureC
        }

        if let cpuDie = temperatures.first(where: { $0.label == "CPU Die" }) {
            return cpuDie.temperatureC
        }

        if let cpuProximity = temperatures.first(where: { $0.label == "CPU Proximity" }) {
            return cpuProximity.temperatureC
        }

        return temperatures.map(\.temperatureC).max()
    }

    func batteryTemperatureC() -> Double? {
        let values = readTemperatures(copyFunction: MacSensorCopyHidTemperatures)
            .filter { isBatteryTemperatureLabel($0.label) }
            .map(\.temperatureC)
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private func readTemperatures(
        copyFunction: (
            OpaquePointer?,
            UnsafeMutablePointer<UnsafeMutablePointer<MacSensorReading>?>
        ) -> Int
    ) -> [RawTemperature] {
        var readingsPointer: UnsafeMutablePointer<MacSensorReading>?
        let count = copyFunction(context, &readingsPointer)
        guard let readingsPointer, count > 0 else {
            return []
        }
        defer {
            MacSensorReadingsFree(readingsPointer, count)
        }

        return (0..<count).compactMap { index in
            let reading = readingsPointer[index]
            guard let label = reading.label, reading.value.isFinite else {
                return nil
            }
            return RawTemperature(
                label: String(cString: label),
                temperatureC: reading.value
            )
        }
    }

    private func group(_ samples: [RawTemperature]) -> [RawTemperature] {
        var grouped: [String: [Double]] = [:]
        var passthrough: [RawTemperature] = []

        for sample in samples {
            switch classify(sample.label) {
            case .group(let label):
                grouped[label, default: []].append(sample.temperatureC)
            case .skip:
                continue
            case .passthrough:
                passthrough.append(sample)
            }
        }

        let collapsed = grouped.map { label, values in
            RawTemperature(
                label: label,
                temperatureC: values.reduce(0, +) / Double(values.count)
            )
        }
        .sorted { lhs, rhs in
            sortPriority(lhs.label) < sortPriority(rhs.label)
        }

        return collapsed + passthrough
    }

    private func classify(_ label: String) -> SensorClassification {
        let lower = label.lowercased()

        if lower.hasPrefix("pacc")
            || lower.hasPrefix("p-acc")
            || lower.contains("performance cluster") {
            return .group(SensorLabels.performanceCores)
        }
        if lower.hasPrefix("eacc")
            || lower.hasPrefix("ecpu")
            || lower.contains("efficiency cluster") {
            return .group(SensorLabels.efficiencyCores)
        }
        if lower.hasPrefix("gpu")
            || lower.hasPrefix("gacc")
            || lower.hasPrefix("g-acc") {
            return .group(SensorLabels.graphics)
        }
        if isBatteryTemperatureLabel(lower) {
            return .skip
        }
        if lower.contains("tdie") {
            return .group(SensorLabels.mainChip)
        }
        if lower.contains("tdev") || lower.contains("tcal") {
            return .group(SensorLabels.powerSystem)
        }
        if lower.hasPrefix("nand") {
            return .group(SensorLabels.storage)
        }

        return .passthrough
    }

    private func isBatteryTemperatureLabel(_ label: String) -> Bool {
        label.lowercased().contains("gas gauge battery")
    }

    private func sortPriority(_ label: String) -> Int {
        switch label {
        case SensorLabels.performanceCores:
            return 0
        case SensorLabels.efficiencyCores:
            return 1
        case SensorLabels.graphics:
            return 2
        case SensorLabels.mainChip:
            return 3
        case SensorLabels.powerSystem:
            return 4
        case SensorLabels.storage:
            return 5
        default:
            return 99
        }
    }
}

private struct RawTemperature {
    var label: String
    var temperatureC: Double
}

private enum SensorClassification {
    case group(String)
    case skip
    case passthrough
}

private enum SensorLabels {
    static let performanceCores = "Performance Cores"
    static let efficiencyCores = "Efficiency Cores"
    static let graphics = "Graphics"
    static let mainChip = "Main Chip"
    static let powerSystem = "Power System"
    static let storage = "Storage"
}
