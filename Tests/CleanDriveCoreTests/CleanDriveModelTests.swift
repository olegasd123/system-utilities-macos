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
}

private actor CountingCategory: ReclaimableCategory {
    nonisolated let id = CleanDriveCategoryID(rawValue: "counting-category")
    nonisolated let displayName = "Counting category"
    nonisolated let symbolName = "folder"
    nonisolated let requiresFullDiskAccess = false
    nonisolated let defaultEnabled = true

    private(set) var scanCount = 0

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
        ReclaimReport()
    }
}
