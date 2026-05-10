import Foundation

enum CleanDriveSizeReader {
    static func allocatedSize(of url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ])
        let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
        return UInt64(max(size, 0))
    }

    static func itemKind(at url: URL) throws -> CleanDriveItem.Kind? {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ])
        if values.isSymbolicLink == true {
            return nil
        }
        if values.isDirectory == true {
            return .directory
        }
        if values.isRegularFile == true {
            return .file
        }
        return nil
    }

    static func recursiveAllocatedSize(of directory: URL) throws -> UInt64 {
        try allocatedSize(of: directory) + recursiveChildrenSize(of: directory)
    }

    private static func recursiveChildrenSize(of directory: URL) throws -> UInt64 {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .fileAllocatedSizeKey,
                .isDirectoryKey,
                .isPackageKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .totalFileAllocatedSizeKey
            ],
            options: []
        )

        var total: UInt64 = 0
        for child in children {
            try Task.checkCancellation()
            guard let kind = try itemKind(at: child) else {
                continue
            }

            switch kind {
            case .file:
                total += try allocatedSize(of: child)
            case .directory:
                let values = try child.resourceValues(forKeys: [.isPackageKey])
                if values.isPackage == true {
                    total += try allocatedSize(of: child)
                } else {
                    total += try recursiveAllocatedSize(of: child)
                }
            }
        }
        return total
    }
}
