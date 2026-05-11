import CleanDriveCore
import Foundation
import XCTest

@MainActor
final class CleanDriveModelTests: XCTestCase {
    func testScanIfNeededOnlyScansOnceAfterDataWasCollected() async {
        let category = CountingCategory()
        let model = CleanDriveModel(categories: [category])

        await model.scanIfNeeded()
        await model.scanIfNeeded()

        let scanCount = await category.scanCount
        XCTAssertEqual(scanCount, 1)
        XCTAssertEqual(model.totalBytes, 1_024)
    }

    func testManualScanStillRefreshesCollectedData() async {
        let category = CountingCategory()
        let model = CleanDriveModel(categories: [category])

        await model.scanIfNeeded()
        await model.scan()

        let scanCount = await category.scanCount
        XCTAssertEqual(scanCount, 2)
    }

    func testMoveToTrashCleanupSkipsTrashAndDoesNotRescanIt() async {
        let trash = CountingCategory(id: .trash)
        let logs = CountingCategory(id: .userLogs)
        let model = CleanDriveModel(categories: [trash, logs])
        model.setIncluded(true, for: .trash)

        await model.scan()
        await model.reclaimSelectedItems(mode: .moveToTrash)

        let trashScanCount = await trash.scanCount
        let trashReclaimCount = await trash.reclaimCount
        let logsScanCount = await logs.scanCount
        let logsReclaimCount = await logs.reclaimCount
        XCTAssertEqual(trashScanCount, 1)
        XCTAssertEqual(trashReclaimCount, 0)
        XCTAssertEqual(logsScanCount, 2)
        XCTAssertEqual(logsReclaimCount, 1)
    }

    func testHardDeleteCleanupReclaimsAndRescansTrash() async {
        let trash = CountingCategory(id: .trash)
        let model = CleanDriveModel(categories: [trash])
        model.setIncluded(true, for: .trash)

        await model.scan()
        await model.reclaimSelectedItems(mode: .hardDelete)

        let scanCount = await trash.scanCount
        let reclaimCount = await trash.reclaimCount
        XCTAssertEqual(scanCount, 2)
        XCTAssertEqual(reclaimCount, 1)
    }
}

private actor CountingCategory: ReclaimableCategory {
    nonisolated let id: CleanDriveCategoryID
    nonisolated let displayName: String
    nonisolated let symbolName = "folder"
    nonisolated let requiresFullDiskAccess = false
    nonisolated let defaultEnabled = true

    private(set) var scanCount = 0
    private(set) var reclaimCount = 0

    init(
        id: CleanDriveCategoryID = CleanDriveCategoryID(rawValue: "counting-category"),
        displayName: String = "Counting category"
    ) {
        self.id = id
        self.displayName = displayName
    }

    func scan(_ context: CleanDriveScanContext) async throws -> CleanDriveScanResult {
        scanCount += 1
        return CleanDriveScanResult(
            items: [
                CleanDriveItem(
                    url: context.homeDirectory.appendingPathComponent("item.bin"),
                    size: 1_024,
                    kind: .file
                )
            ]
        )
    }

    func reclaim(
        _ items: [CleanDriveItem],
        mode: ReclaimMode
    ) async throws -> ReclaimReport {
        reclaimCount += 1
        return ReclaimReport()
    }
}
