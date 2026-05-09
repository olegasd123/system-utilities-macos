import Darwin
import Foundation
import SystemConfiguration

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
                connectionType: counters.connectionType
            )
        }

        let rxDelta = counters.totalRxBytes.saturatingSubtract(previous.totalRxBytes)
        let txDelta = counters.totalTxBytes.saturatingSubtract(previous.totalTxBytes)

        return NetworkSample(
            rxBytesPerSec: UInt64(Double(rxDelta) / elapsed),
            txBytesPerSec: UInt64(Double(txDelta) / elapsed),
            totalRxBytes: counters.totalRxBytes,
            totalTxBytes: counters.totalTxBytes,
            connectionType: counters.connectionType
        )
    }

    private func readCounters() -> NetworkCounters {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else {
            return NetworkCounters(totalRxBytes: 0, totalTxBytes: 0, connectionType: nil)
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

        let primary = primaryInterface(from: activityByInterface)
        let serviceTypes = serviceTypesByInterface()
        let type = primary.flatMap {
            Self.connectionType(for: $0, serviceType: serviceTypes[$0])
        }

        return NetworkCounters(
            totalRxBytes: rx,
            totalTxBytes: tx,
            connectionType: type
        )
    }

    private func isLoopback(_ name: String) -> Bool {
        name == "lo" || name == "lo0" || name.hasPrefix("Loopback")
    }

    private func primaryInterface(from activityByInterface: [String: UInt64]) -> String? {
        if let activeInterface = activePrimaryInterface(),
           activityByInterface[activeInterface] != nil {
            return activeInterface
        }

        return activityByInterface.max { lhs, rhs in
            lhs.value < rhs.value
        }?.key
    }

    private func activePrimaryInterface() -> String? {
        primaryInterface(for: "State:/Network/Global/IPv4")
            ?? primaryInterface(for: "State:/Network/Global/IPv6")
    }

    private func primaryInterface(for key: String) -> String? {
        guard let store = SCDynamicStoreCreate(nil, "SystemMonitor" as CFString, nil, nil),
              let state = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any] else {
            return nil
        }

        return state["PrimaryInterface"] as? String
    }

    private func serviceTypesByInterface() -> [String: String] {
        guard let preferences = SCPreferencesCreate(nil, "SystemMonitor" as CFString, nil),
              let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            return [:]
        }

        var types: [String: String] = [:]
        for service in services where SCNetworkServiceGetEnabled(service) {
            guard let interface = SCNetworkServiceGetInterface(service),
                  let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let type = SCNetworkInterfaceGetInterfaceType(interface) as String? else {
                continue
            }

            types[name] = type
        }

        return types
    }

    static func connectionType(for interface: String, serviceType: String?) -> String? {
        if let serviceType {
            switch serviceType {
            case "IEEE80211":
                return "Wi-Fi"
            case "Ethernet":
                return "Ethernet"
            case "Bluetooth":
                return "Bluetooth"
            case "WWAN":
                return "Cellular"
            case "FireWire":
                return "FireWire"
            case "IPSec", "L2TP", "PPP", "PPTP":
                return "VPN"
            case "Bond":
                return "Bond"
            case "VLAN":
                return "VLAN"
            default:
                break
            }
        }

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
    var connectionType: String?
}

private extension UInt64 {
    func saturatingSubtract(_ value: UInt64) -> UInt64 {
        self >= value ? self - value : 0
    }
}
