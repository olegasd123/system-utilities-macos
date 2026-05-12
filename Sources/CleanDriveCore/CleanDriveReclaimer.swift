import Foundation

enum CleanDriveReclaimer {
    static func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode,
        trasher: any CleanDriveTrashing
    ) async throws -> ReclaimReport {
        var report = ReclaimReport()
        for item in items {
            try Task.checkCancellation()
            do {
                switch mode {
                case .moveToTrash:
                    try trasher.trashItem(at: item.url)
                case .hardDelete:
                    try FileManager.default.removeItem(at: item.url)
                }
                report.bytesReclaimed += item.size
                report.reclaimedItemCount += 1
            } catch {
                report.failures.append(
                    ReclaimFailure(
                        path: item.url.path,
                        reason: error.localizedDescription
                    )
                )
            }
        }
        return report
    }
}
