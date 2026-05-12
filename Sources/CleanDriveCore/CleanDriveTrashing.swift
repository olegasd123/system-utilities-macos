import Foundation

public protocol CleanDriveTrashing: Sendable {
    func trashItem(at url: URL) throws
}

public struct SystemTrash: CleanDriveTrashing {
    public init() {}

    public func trashItem(at url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(
            at: url,
            resultingItemURL: &resultingURL
        )
    }
}

public struct DirectoryTrash: CleanDriveTrashing {
    private let trashDirectory: URL

    public init(trashDirectory: URL) {
        self.trashDirectory = trashDirectory
    }

    public func trashItem(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: trashDirectory,
            withIntermediateDirectories: true
        )
        let destination = uniqueDestination(for: url)
        try FileManager.default.moveItem(at: url, to: destination)
    }

    private func uniqueDestination(for url: URL) -> URL {
        let base = trashDirectory.appendingPathComponent(url.lastPathComponent)
        guard FileManager.default.fileExists(atPath: base.path) else {
            return base
        }

        let name = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        var index = 1
        while true {
            let fileName = pathExtension.isEmpty
                ? "\(name) \(index)"
                : "\(name) \(index).\(pathExtension)"
            let candidate = trashDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
