import CleanDriveCore
import XCTest

final class UserCachesCategoryTests: XCTestCase {
    private var rootURL: URL!
    private var cacheURL: URL!
    private var trashURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        cacheURL = rootURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
        trashURL = rootURL.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(
            at: cacheURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        cacheURL = nil
        trashURL = nil
    }

    func testScanReturnsCacheItemsAndSizes() async throws {
        let appCache = cacheURL.appendingPathComponent("com.example.App", isDirectory: true)
        try FileManager.default.createDirectory(at: appCache, withIntermediateDirectories: true)
        try writeFile(
            appCache.appendingPathComponent("cache.bin"),
            byteCount: 4_096
        )
        try writeFile(
            cacheURL.appendingPathComponent("loose-cache.tmp"),
            byteCount: 1_024
        )

        let category = UserCachesCategory(blockedBundleIDs: [])
        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        XCTAssertEqual(Set(result.items.map(\.url.lastPathComponent)), [
            "com.example.App",
            "loose-cache.tmp"
        ])
        XCTAssertGreaterThan(result.totalBytes, 0)
        XCTAssertEqual(result.totalBytes, result.items.reduce(0) { $0 + $1.size })
        XCTAssertTrue(result.notes.isEmpty)
    }

    func testScanSkipsBlockedBundleIDs() async throws {
        try makeCacheDirectory(named: "com.apple.Safari")
        try makeCacheDirectory(named: "com.example.Keep")

        let category = UserCachesCategory(blockedBundleIDs: ["com.apple.Safari"])
        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        XCTAssertEqual(result.items.map(\.url.lastPathComponent), ["com.example.Keep"])
    }

    func testDefaultBlockedBundleIDsIncludeInitialDangerousCaches() {
        let blocked = UserCachesCategory.defaultBlockedBundleIDs

        XCTAssertTrue(blocked.contains("com.apple.AddressBook"))
        XCTAssertTrue(blocked.contains("com.apple.Photos"))
        XCTAssertTrue(blocked.contains("com.apple.Safari"))
    }

    func testReclaimMovesItemsToTrash() async throws {
        try writeFile(
            cacheURL.appendingPathComponent("loose-cache.tmp"),
            byteCount: 1_024
        )
        let category = UserCachesCategory(
            blockedBundleIDs: [],
            trasher: DirectoryTrash(trashDirectory: trashURL)
        )
        let result = try await category.scan(CleanDriveScanContext(homeDirectory: rootURL))

        let report = try await category.reclaim(result.items, mode: .moveToTrash)

        XCTAssertEqual(report.bytesReclaimed, result.totalBytes)
        XCTAssertEqual(report.reclaimedItemCount, 1)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: cacheURL.appendingPathComponent("loose-cache.tmp").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: trashURL.appendingPathComponent("loose-cache.tmp").path
            )
        )
    }

    private func makeCacheDirectory(named name: String) throws {
        let directory = cacheURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeFile(directory.appendingPathComponent("cache.bin"), byteCount: 1_024)
    }

    private func writeFile(_ url: URL, byteCount: Int) throws {
        try Data(repeating: 1, count: byteCount).write(to: url)
    }
}
