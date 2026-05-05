import Foundation

enum MenuBarFormatter {
    static func title(snapshot: Snapshot?, settings: Settings) -> String {
        guard let snapshot else {
            return "CPU --  NET --"
        }

        var parts: [String] = []
        let menuBar = settings.menuBar

        if menuBar.showCpuLoad {
            parts.append("CPU \(Int(snapshot.cpu.usagePercent.rounded()))%")
        }

        if menuBar.showTemperature, let temperature = snapshot.cpu.temperatureC {
            parts.append("TEMP \(SystemFormatters.temperature(temperature, unit: settings.temperatureUnit))")
        }

        if menuBar.showMemoryUsage {
            parts.append("RAM \(Int(snapshot.memory.usedPercent.rounded()))%")
        }

        if menuBar.showDiskFree, let disk = primaryDisk(from: snapshot.disks) {
            parts.append("DISK \(SystemFormatters.compactBytes(disk.availableBytes))")
        }

        if menuBar.showBattery, let battery = snapshot.battery {
            let prefix = isOnPower(battery.state) ? "*" : ""
            parts.append("BAT \(prefix)\(Int(battery.chargePercent.rounded()))%")
        }

        if menuBar.showNetworkSpeed {
            let down = SystemFormatters.compactRate(
                snapshot.network.rxBytesPerSec,
                units: settings.networkUnits
            )
            let up = SystemFormatters.compactRate(
                snapshot.network.txBytesPerSec,
                units: settings.networkUnits
            )
            switch settings.networkDisplay {
            case .uploadAndDownload:
                parts.append("↓ \(down) ↑ \(up)")
            case .uploadOnly:
                parts.append("UP \(up)")
            case .downloadOnly:
                parts.append("DOWN \(down)")
            case .combined:
                parts.append("NET \(down)")
            }
        }

        return parts.isEmpty ? "System Monitor" : parts.joined(separator: "  ")
    }

    private static func primaryDisk(from disks: [DiskSample]) -> DiskSample? {
        disks.first { $0.mountPoint == "/System/Volumes/Data" }
            ?? disks.first { $0.mountPoint == "/" }
            ?? disks.first { !$0.isRemovable }
            ?? disks.first
    }

    private static func isOnPower(_ state: BatteryState) -> Bool {
        state == .charging || state == .full
    }
}
