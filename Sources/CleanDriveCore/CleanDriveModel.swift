import AppCore
import Combine
import Foundation

public struct CleanDriveCategorySnapshot: Identifiable, Equatable, Sendable {
    public let id: CleanDriveCategoryID
    public var displayName: String
    public var symbolName: String
    public var requiresFullDiskAccess: Bool
    public var isIncluded: Bool
    public var isScanning: Bool
    public var isReclaiming: Bool
    public var permissionDenied: Bool
    public var items: [CleanDriveItem]
    public var notes: [String]
    public var errorMessage: String?

    public init(
        id: CleanDriveCategoryID,
        displayName: String,
        symbolName: String,
        requiresFullDiskAccess: Bool,
        isIncluded: Bool,
        isScanning: Bool = false,
        isReclaiming: Bool = false,
        permissionDenied: Bool = false,
        items: [CleanDriveItem] = [],
        notes: [String] = [],
        errorMessage: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.requiresFullDiskAccess = requiresFullDiskAccess
        self.isIncluded = isIncluded
        self.isScanning = isScanning
        self.isReclaiming = isReclaiming
        self.permissionDenied = permissionDenied
        self.items = items
        self.notes = notes
        self.errorMessage = errorMessage
    }

    public var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.size }
    }
}

@MainActor
public final class CleanDriveModel: ObservableObject {
    @Published public private(set) var categories: [CleanDriveCategorySnapshot]
    @Published public private(set) var lastReclaimReport: ReclaimReport?

    private var hasCollectedData = false
    private let reclaimableCategories: [any ReclaimableCategory]
    private let baseScanContext: CleanDriveScanContext
    private let settingsModel: SettingsModel<CleanDriveSettings>?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        categories: [any ReclaimableCategory] = CleanDriveCategoryCatalog.defaultCategories(),
        scanContext: CleanDriveScanContext = CleanDriveScanContext(),
        settings: SettingsModel<CleanDriveSettings>? = nil
    ) {
        self.reclaimableCategories = categories
        self.baseScanContext = scanContext
        self.settingsModel = settings
        let cleanDriveSettings = settings?.settings ?? .defaultValue
        self.categories = categories.map {
            CleanDriveCategorySnapshot(
                id: $0.id,
                displayName: Self.displayName(for: $0, settings: cleanDriveSettings),
                symbolName: $0.symbolName,
                requiresFullDiskAccess: $0.requiresFullDiskAccess,
                isIncluded: cleanDriveSettings.isCategoryEnabled(
                    $0.id,
                    defaultEnabled: $0.defaultEnabled
                )
            )
        }

        settings?.publisher
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.apply(settings)
            }
            .store(in: &cancellables)
    }

    public var totalBytes: UInt64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }

    public var selectedBytes: UInt64 {
        categories.reduce(0) { total, snapshot in
            snapshot.isIncluded ? total + snapshot.totalBytes : total
        }
    }

    public var isScanning: Bool {
        categories.contains { $0.isScanning }
    }

    public var isReclaiming: Bool {
        categories.contains { $0.isReclaiming }
    }

    public var canReclaimSelectedItems: Bool {
        selectedBytes > 0 && !isScanning && !isReclaiming
    }

    public var selectedCategoryNames: [String] {
        categories
            .filter { $0.isIncluded && !$0.items.isEmpty }
            .map(\.displayName)
    }

    public func setIncluded(_ isIncluded: Bool, for id: CleanDriveCategoryID) {
        guard let index = index(for: id) else {
            return
        }
        categories[index].isIncluded = isIncluded
        guard let settingsModel else {
            return
        }
        settingsModel.settings.setCategoryEnabled(isIncluded, id: id)
    }

    public func items(for id: CleanDriveCategoryID) -> [CleanDriveItem] {
        categories.first { $0.id == id }?.items ?? []
    }

    public func scanIfNeeded() async {
        guard !hasCollectedData else {
            return
        }
        await scan()
    }

    public func scan() async {
        guard !isScanning else {
            return
        }
        lastReclaimReport = nil

        for category in reclaimableCategories {
            await scan(category)
        }
        hasCollectedData = true
    }

    public func scanCategory(id: CleanDriveCategoryID) async {
        guard let category = reclaimableCategories.first(where: { $0.id == id }) else {
            return
        }
        await scan(category)
    }

    @discardableResult
    public func reclaimSelectedItems(mode: ReclaimMode = .moveToTrash) async -> ReclaimReport? {
        guard canReclaimSelectedItems else {
            return nil
        }

        lastReclaimReport = nil
        var aggregate = ReclaimReport()
        var refreshedCategoryIDs: Set<CleanDriveCategoryID> = []

        for category in reclaimableCategories {
            guard
                let index = index(for: category.id),
                categories[index].isIncluded,
                !categories[index].items.isEmpty
            else {
                continue
            }

            if mode == .moveToTrash, category.id == .trash {
                continue
            }

            categories[index].isReclaiming = true
            categories[index].errorMessage = nil
            let items = categories[index].items
            refreshedCategoryIDs.insert(category.id)

            do {
                let report = try await Task.detached(priority: .utility) {
                    try await category.reclaim(items, mode: mode)
                }.value
                aggregate.bytesReclaimed += report.bytesReclaimed
                aggregate.reclaimedItemCount += report.reclaimedItemCount
                aggregate.failures += report.failures
            } catch is CancellationError {
                categories[index].errorMessage = "Clean up canceled."
            } catch {
                categories[index].errorMessage = error.localizedDescription
            }

            categories[index].isReclaiming = false
        }

        lastReclaimReport = aggregate
        for category in reclaimableCategories where refreshedCategoryIDs.contains(category.id) {
            await scan(category)
        }
        lastReclaimReport = aggregate
        return aggregate
    }

    private func scan(_ category: any ReclaimableCategory) async {
        guard let startIndex = index(for: category.id), !categories[startIndex].isScanning else {
            return
        }

        categories[startIndex].isScanning = true
        categories[startIndex].permissionDenied = false
        categories[startIndex].errorMessage = nil

        let context = scanContext
        do {
            let result = try await Task.detached(priority: .utility) {
                try await category.scan(context)
            }.value
            if let currentIndex = self.index(for: category.id) {
                categories[currentIndex].items = result.items
                categories[currentIndex].notes = result.notes
            }
        } catch is CancellationError {
            categories[startIndex].errorMessage = "Scan canceled."
        } catch let error as CleanDrivePermissionDeniedError {
            categories[startIndex].items = []
            categories[startIndex].permissionDenied = true
            categories[startIndex].errorMessage = error.localizedDescription
        } catch {
            categories[startIndex].errorMessage = error.localizedDescription
        }

        if let currentIndex = index(for: category.id) {
            categories[currentIndex].isScanning = false
        }
    }

    private func index(for id: CleanDriveCategoryID) -> Int? {
        categories.firstIndex { $0.id == id }
    }

    private var settings: CleanDriveSettings {
        settingsModel?.settings ?? .defaultValue
    }

    private var scanContext: CleanDriveScanContext {
        CleanDriveScanContext(
            homeDirectory: baseScanContext.homeDirectory,
            userID: baseScanContext.userID,
            downloadsOlderThanDays: settings.reclaim.downloadsOlderThanDays,
            xcodeArchivesOlderThanDays: settings.reclaim.xcodeArchivesOlderThanDays,
            customFolderURLs: settings.customFolders.map(\.url)
        )
    }

    private func apply(_ settings: CleanDriveSettings) {
        for category in reclaimableCategories {
            guard let index = index(for: category.id) else {
                continue
            }
            categories[index].displayName = Self.displayName(for: category, settings: settings)
            categories[index].isIncluded = settings.isCategoryEnabled(
                category.id,
                defaultEnabled: category.defaultEnabled
            )
        }
    }

    private static func displayName(
        for category: any ReclaimableCategory,
        settings: CleanDriveSettings
    ) -> String {
        switch category.id {
        case .downloadsOld:
            return "Downloads (older than \(settings.reclaim.downloadsOlderThanDays) days)"
        case .xcodeArchives:
            return "Xcode archives (older than \(settings.reclaim.xcodeArchivesOlderThanDays) days)"
        default:
            return category.displayName
        }
    }
}
