import Foundation
import Darwin

public struct CleanDrivePermissionDeniedError: LocalizedError, Equatable, Sendable {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    public var errorDescription: String? {
        "Full Disk Access is needed for \(path)."
    }
}

enum CleanDriveErrorClassifier {
    static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == Int(EPERM) || nsError.code == Int(EACCES)
        }
        if nsError.domain == NSCocoaErrorDomain {
            return nsError.code == NSFileReadNoPermissionError
                || nsError.code == NSFileWriteNoPermissionError
        }
        return false
    }
}
