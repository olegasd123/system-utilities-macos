import AppCore
import Foundation

public protocol CleanDriveTrashing: FileTrashing {}

public struct SystemTrash: CleanDriveTrashing {
    private let base = AppCore.SystemTrash()

    public init() {}

    public func trashItem(at url: URL) throws {
        try base.trashItem(at: url)
    }
}

public struct DirectoryTrash: CleanDriveTrashing {
    private let base: AppCore.DirectoryTrash

    public init(trashDirectory: URL) {
        self.base = AppCore.DirectoryTrash(trashDirectory: trashDirectory)
    }

    public func trashItem(at url: URL) throws {
        try base.trashItem(at: url)
    }
}
