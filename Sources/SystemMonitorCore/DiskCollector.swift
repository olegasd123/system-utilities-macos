import Foundation

struct DiskCollector: DiskMetricSource {
    func sample() -> [DiskSample] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys) else {
                return nil
            }

            let total = UInt64(values.volumeTotalCapacity ?? 0)
            guard total > 0 else {
                return nil
            }

            let available = UInt64(
                values.volumeAvailableCapacityForImportantUsage
                    ?? Int64(values.volumeAvailableCapacity ?? 0)
            )
            let used = total >= available ? total - available : 0
            let mountPoint = url.path

            return DiskSample(
                name: values.volumeName ?? url.lastPathComponent,
                mountPoint: mountPoint.isEmpty ? "/" : mountPoint,
                totalBytes: total,
                availableBytes: available,
                usedBytes: used,
                usedPercent: Double(used) / Double(total) * 100,
                isRemovable: values.volumeIsRemovable ?? false
            )
        }
    }
}
