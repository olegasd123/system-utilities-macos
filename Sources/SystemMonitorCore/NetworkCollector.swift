import Darwin
import Foundation

final class NetworkCollector: NetworkMetricSource {
    private var previous: NetworkCounters?
    private var previousDate = Date()

    func sample() -> NetworkSample {
        let now = Date()
        let counters = readCounters()
        let elapsed = max(now.timeIntervalSince(previousDate), 0.001)
        defer {
            previous = counters
            previousDate = now
        }

        guard let previous else {
            return NetworkSample(
                rxBytesPerSec: 0,
                txBytesPerSec: 0,
                totalRxBytes: counters.totalRxBytes,
                totalTxBytes: counters.totalTxBytes,
                primaryInterface: counters.primaryInterface,
                connectionType: counters.primaryInterface.flatMap(connectionType)
            )
        }

        let rxDelta = counters.totalRxBytes.saturatingSubtract(previous.totalRxBytes)
        let txDelta = counters.totalTxBytes.saturatingSubtract(previous.totalTxBytes)

        return NetworkSample(
            rxBytesPerSec: UInt64(Double(rxDelta) / elapsed),
            txBytesPerSec: UInt64(Double(txDelta) / elapsed),
            totalRxBytes: counters.totalRxBytes,
            totalTxBytes: counters.totalTxBytes,
            primaryInterface: counters.primaryInterface,
            connectionType: counters.primaryInterface.flatMap(connectionType)
        )
    }

    private func readCounters() -> NetworkCounters {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else {
            return NetworkCounters(totalRxBytes: 0, totalTxBytes: 0, primaryInterface: nil)
        }
        defer {
            freeifaddrs(interfaces)
        }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var activityByInterface: [String: UInt64] = [:]

        var cursor: UnsafeMutablePointer<ifaddrs>? = interfaces
        while let current = cursor {
            defer {
                cursor = current.pointee.ifa_next
            }

            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0 else {
                continue
            }
            guard current.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else {
                continue
            }
            guard let dataPointer = current.pointee.ifa_data else {
                continue
            }

            let name = String(cString: current.pointee.ifa_name)
            guard !isLoopback(name) else {
                continue
            }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            let interfaceRx = UInt64(data.ifi_ibytes)
            let interfaceTx = UInt64(data.ifi_obytes)
            rx += interfaceRx
            tx += interfaceTx
            activityByInterface[name, default: 0] += interfaceRx + interfaceTx
        }

        let primary = activityByInterface.max { lhs, rhs in
            lhs.value < rhs.value
        }?.key

        return NetworkCounters(totalRxBytes: rx, totalTxBytes: tx, primaryInterface: primary)
    }

    private func isLoopback(_ name: String) -> Bool {
        name == "lo" || name == "lo0" || name.hasPrefix("Loopback")
    }

    private func connectionType(for interface: String) -> String? {
        let lower = interface.lowercased()
        if lower == "en0" {
            return "Wi-Fi"
        }
        if lower.hasPrefix("utun") || lower.hasPrefix("tun") || lower.hasPrefix("tap") || lower.hasPrefix("ppp") {
            return "VPN"
        }
        if lower.hasPrefix("bridge") {
            return "Bridge"
        }
        if lower.hasPrefix("en") || lower.hasPrefix("eth") {
            return "Ethernet"
        }
        return nil
    }
}

private struct NetworkCounters {
    var totalRxBytes: UInt64
    var totalTxBytes: UInt64
    var primaryInterface: String?
}

private extension UInt64 {
    func saturatingSubtract(_ value: UInt64) -> UInt64 {
        self >= value ? self - value : 0
    }
}
