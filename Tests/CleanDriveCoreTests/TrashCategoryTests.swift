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
}
