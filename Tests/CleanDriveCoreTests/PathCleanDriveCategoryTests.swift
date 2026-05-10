import CleanDriveCore
import XCTest

final class PathCleanDriveCategoryTests: XCTestCase {
    private var rootURL: URL!
    private var trashURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        trashURL = rootURL.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        trashURL = nil
    }

    func testChildrenOlderThanDaysFiltersByModificationDate() async throws {
        let downloadsURL = rootURL.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true)

        let oldFile = downloadsURL.appendingPathComponent("old.zip")
        let newFile = downloadsURL.appendingPathComponent("new.zip")
        try writeFile(oldFile)
        try writeFile(newFile)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-40 * 24 * 60 * 60)],
            ofItemAtPath: oldFile.path
        )

        let category = PathCleanDriveCategory(
            id: .downloadsOld,
            displayName: "Downloads",
            symbolName: "arrow.down.circle",
            requiresFullDiskAccess: false,
            defaultEnabled: false,
            roots: [.home(["Downloads"])],
            scanMode: .childrenOlderThanDays(30),
            trasher: DirectoryTrash(trashDirectory: trashURL)
        )

        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        XCTAssertEqual(result.items.map(\.url.lastPathComponent), ["old.zip"])
    }

    func testHardDeleteRemovesItems() async throws {
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        let fileURL = cacheURL.appendingPathComponent("item.bin")
        try writeFile(fileURL)

        let category = PathCleanDriveCategory(
            id: .userLogs,
            displayName: "Logs",
            symbolName: "doc.text",
            requiresFullDiskAccess: false,
            defaultEnabled: true,
            roots: [.absolute(cacheURL.path)],
            scanMode: .children,
            trasher: DirectoryTrash(trashDirectory: trashURL)
        )
        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        let report = try await category.reclaim(result.items, mode: .hardDelete)

        XCTAssertEqual(report.reclaimedItemCount, 1)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: trashURL.appendingPathComponent("item.bin").path
            )
        )
    }

    func testDefaultCatalogContainsMilestoneThreeCategories() {
        let ids = CleanDriveCategoryCatalog.defaultCategories(
            trasher: DirectoryTrash(trashDirectory: trashURL)
        ).map(\.id)

        XCTAssertEqual(ids, [
            .userCaches,
            .userLogs,
            .trash,
            .xcodeDerived,
            .xcodeArchives,
            .xcodeDeviceSupport,
            .xcodeSimulators,
            .homebrewCache,
            .browserCaches,
            .mailCache,
            .downloadsOld,
            .softwareUpdates
        ])
    }

    private func writeFile(_ url: URL) throws {
        try Data(repeating: 1, count: 1_024).write(to: url)
    }
}
