import Foundation

public struct UnavailableSimulatorsCategory: ReclaimableCategory {
    public let id: CleanDriveCategoryID = .xcodeSimulators
    public let displayName = "Unavailable simulators"
    public let symbolName = "iphone.slash"
    public let requiresFullDiskAccess = false
    public let defaultEnabled = false

    private let trasher: any CleanDriveTrashing
    private let commandRunner = CleanDriveCommandRunner()

    public init(trasher: any CleanDriveTrashing = SystemTrash()) {
        self.trasher = trasher
    }

    public func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        var items: [CleanDriveItem] = []
        var notes: [String] = []

        for deviceID in unavailableDeviceIDs() {
            try Task.checkCancellation()
            let url = context.homeDirectory
                .appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
                .appendingPathComponent(deviceID, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }
            do {
                if let kind = try CleanDriveSizeReader.itemKind(at: url), kind == .directory {
                    items.append(
                        CleanDriveItem(
                            url: url,
                            size: try CleanDriveSizeReader.recursiveAllocatedSize(of: url),
                            kind: .directory
                        )
                    )
                }
            } catch {
                notes.append("Skipped simulator \(deviceID): \(error.localizedDescription)")
            }
        }

        let cacheCategory = PathCleanDriveCategory(
            id: id,
            displayName: displayName,
            symbolName: symbolName,
            requiresFullDiskAccess: false,
            defaultEnabled: defaultEnabled,
            roots: [
                .home(["Library", "Developer", "CoreSimulator", "Caches"])
            ],
            scanMode: .children,
            trasher: trasher
        )
        let cacheResult = try await cacheCategory.scan(context)
        items += cacheResult.items
        notes += cacheResult.notes

        return CleanDriveScanResult(
            items: items.sorted { $0.size > $1.size },
            notes: notes
        )
    }

    public func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        let report = try await CleanDriveReclaimer.reclaim(items, mode: mode, trasher: trasher)
        _ = try? commandRunner.output(
            executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "delete", "unavailable"]
        )
        return report
    }

    private func unavailableDeviceIDs() -> [String] {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/xcrun") else {
            return []
        }
        let output = (try? commandRunner.output(
            executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "list", "devices", "--json"]
        )) ?? ""
        guard let data = output.data(using: .utf8) else {
            return []
        }

        struct Device: Decodable {
            let udid: String
            let isAvailable: Bool?
            let availabilityError: String?
        }
        struct Response: Decodable {
            let devices: [String: [Device]]
        }

        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            return []
        }

        return response.devices.values.flatMap { devices in
            devices.compactMap { device in
                if device.isAvailable == false || device.availabilityError != nil {
                    return device.udid
                }
                return nil
            }
        }
    }
}
