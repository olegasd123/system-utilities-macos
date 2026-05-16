import AppCore

enum CleanDriveReclaimer {
    static func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode,
        trasher: any CleanDriveTrashing
    ) async throws -> ReclaimReport {
        try await FileReclaimer.reclaim(items, mode: mode, trasher: trasher)
    }
}
