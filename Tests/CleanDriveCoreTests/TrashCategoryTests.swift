import CleanDriveCore
import XCTest

final class TrashCategoryTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
    }

    func testTrashCategoryRequiresFullDiskAccess() {
        XCTAssertTrue(TrashCategory().requiresFullDiskAccess)
    }

    func testScanReturnsItemsFromUserTrash() async throws {
        let trashURL = rootURL.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
        let fileURL = trashURL.appendingPathComponent("deleted.pdf")
        try Data(repeating: 1, count: 1_024).write(to: fileURL)

        let result = try await TrashCategory().scan(CleanDriveScanContext(homeDirectory: rootURL))

        XCTAssertEqual(result.items.map(\.url.lastPathComponent), ["deleted.pdf"])
        XCTAssertGreaterThan(result.totalBytes, 0)
    }

    func testScanSkipsFinderMetadataInUserTrash() async throws {
        let trashURL = rootURL.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_024)
            .write(to: trashURL.appendingPathComponent(".DS_Store"))
        try Data(repeating: 1, count: 1_024)
            .write(to: trashURL.appendingPathComponent(".env"))

        let result = try await TrashCategory().scan(CleanDriveScanContext(homeDirectory: rootURL))

        XCTAssertEqual(result.items.map(\.url.lastPathComponent), [".env"])
    }

    func testMoveToTrashLeavesTrashItemsInPlace() async throws {
        let trashURL = rootURL.appendingPathComponent(".Trash", isDirectory: true)
        let destinationTrashURL = rootURL.appendingPathComponent("OtherTrash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
        let fileURL = trashURL.appendingPathComponent("deleted.pdf")
        try Data(repeating: 1, count: 1_024).write(to: fileURL)

        let category = TrashCategory(trasher: DirectoryTrash(trashDirectory: destinationTrashURL))
        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        let report = try await category.reclaim(result.items, mode: .moveToTrash)

        XCTAssertEqual(report.reclaimedItemCount, 0)
        XCTAssertEqual(report.bytesReclaimed, 0)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationTrashURL.appendingPathComponent("deleted.pdf").path
            )
        )
    }

    func testHardDeleteRemovesTrashItems() async throws {
        let trashURL = rootURL.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
        let fileURL = trashURL.appendingPathComponent("deleted.pdf")
        try Data(repeating: 1, count: 1_024).write(to: fileURL)

        let category = TrashCategory()
        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        let report = try await category.reclaim(result.items, mode: .hardDelete)

        XCTAssertEqual(report.reclaimedItemCount, 1)
        XCTAssertEqual(report.bytesReclaimed, result.totalBytes)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
