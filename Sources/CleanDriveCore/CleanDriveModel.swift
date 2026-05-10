import Foundation

public struct CleanDriveCategorySnapshot: Identifiable, Equatable, Sendable {
    public let id: CleanDriveCategoryID
    public var displayName: String
    public var symbolName: String
    public var isIncluded: Bool
    public var isScanning: Bool
    public var isReclaiming: Bool
    public var items: [CleanDriveItem]
    public var notes: [String]
    public var errorMessage: String?
    public var lastReclaimReport: ReclaimReport?

    public init(
        id: CleanDriveCategoryID,
        displayName: String,
        symbolName: String,
        isIncluded: Bool,
        isScanning: Bool = false,
        isReclaiming: Bool = false,
        items: [CleanDriveItem] = [],
        notes: [String] = [],
        errorMessage: String? = nil,
        lastReclaimReport: ReclaimReport? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.isIncluded = isIncluded
        self.isScanning = isScanning
        self.isReclaiming = isReclaiming
        self.items = items
        self.notes = notes
        self.errorMessage = errorMessage
        self.lastReclaimReport = lastReclaimReport
    }

    public var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.size }
    }
}

@MainActor
public final class CleanDriveModel: ObservableObject {
    @Published public private(set) var userCaches: CleanDriveCategorySnapshot

    private let userCachesCategory: any ReclaimableCategory
    private let scanContext: CleanDriveScanContext

    public init(
        userCachesCategory: any ReclaimableCategory = UserCachesCategory(),
        scanContext: CleanDriveScanContext = CleanDriveScanContext()
    ) {
        self.userCachesCategory = userCachesCategory
        self.scanContext = scanContext
        self.userCaches = CleanDriveCategorySnapshot(
            id: userCachesCategory.id,
            displayName: userCachesCategory.displayName,
            symbolName: userCachesCategory.symbolName,
            isIncluded: userCachesCategory.defaultEnabled
        )
    }

    public var selectedBytes: UInt64 {
        userCaches.isIncluded ? userCaches.totalBytes : 0
    }

    public var canReclaimSelectedItems: Bool {
        selectedBytes > 0 && !userCaches.isScanning && !userCaches.isReclaiming
    }

    public func setUserCachesIncluded(_ isIncluded: Bool) {
        userCaches.isIncluded = isIncluded
    }

    public func scan() async {
        guard !userCaches.isScanning else {
            return
        }

        userCaches.isScanning = true
        userCaches.errorMessage = nil
        userCaches.lastReclaimReport = nil

        let category = userCachesCategory
        let context = scanContext
        do {
            let result = try await Task.detached(priority: .utility) {
                try await category.scan(context)
            }.value
            userCaches.items = result.items
            userCaches.notes = result.notes
        } catch is CancellationError {
            userCaches.errorMessage = "Scan canceled."
        } catch {
            userCaches.errorMessage = error.localizedDescription
        }
        userCaches.isScanning = false
    }

    @discardableResult
    public func reclaimSelectedItems() async -> ReclaimReport? {
        guard canReclaimSelectedItems else {
            return nil
        }

        let items = userCaches.items
        userCaches.isReclaiming = true
        userCaches.errorMessage = nil
        userCaches.lastReclaimReport = nil

        let category = userCachesCategory
        do {
            let report = try await Task.detached(priority: .utility) {
                try await category.reclaim(items, mode: .moveToTrash)
            }.value
            userCaches.isReclaiming = false
            await scan()
            userCaches.lastReclaimReport = report
            return report
        } catch is CancellationError {
            userCaches.errorMessage = "Clean up canceled."
        } catch {
            userCaches.errorMessage = error.localizedDescription
        }

        userCaches.isReclaiming = false
        return nil
    }
}
