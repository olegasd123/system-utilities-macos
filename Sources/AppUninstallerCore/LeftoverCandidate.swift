import AppCore
import Foundation

public enum LeftoverConfidence: String, Codable, Sendable {
    case appBundle
    case exactBundleID
    case bundleIDPrefix
    case nameHeuristic
    case userHome
}

public enum LeftoverKind: String, Codable, Sendable {
    case file
    case directory
    case symlink
}

public struct LeftoverCandidate: Identifiable, Equatable, Sendable, FileReclaimItem {
    public var id: String { url.path }
    public var url: URL
    public var size: UInt64
    public var kind: LeftoverKind
    public var confidence: LeftoverConfidence

    public init(
        url: URL,
        size: UInt64,
        kind: LeftoverKind,
        confidence: LeftoverConfidence
    ) {
        self.url = url
        self.size = size
        self.kind = kind
        self.confidence = confidence
    }

    public var isSelectedByDefault: Bool {
        switch confidence {
        case .appBundle, .exactBundleID, .bundleIDPrefix:
            true
        case .nameHeuristic, .userHome:
            false
        }
    }
}

public struct LeftoverScanNote: Hashable, Sendable {
    public var key: String
    public var arguments: [String]

    public init(_ key: String, _ arguments: String...) {
        self.key = key
        self.arguments = arguments
    }

    public init(key: String, arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }

    public func localized(using localization: AppLocalization) -> String {
        guard !arguments.isEmpty else {
            return localization(key)
        }
        return localization.format(
            key,
            arguments: arguments.map { $0 as CVarArg }
        )
    }
}

public struct LeftoverScanResult: Equatable, Sendable {
    public var app: InstalledApp
    public var bundle: LeftoverCandidate
    public var leftovers: [LeftoverCandidate]
    public var notes: [LeftoverScanNote]

    public init(
        app: InstalledApp,
        bundle: LeftoverCandidate,
        leftovers: [LeftoverCandidate],
        notes: [LeftoverScanNote] = []
    ) {
        self.app = app
        self.bundle = bundle
        self.leftovers = leftovers
        self.notes = notes
    }

    public var totalBytes: UInt64 {
        bundle.size + leftovers.reduce(0) { $0 + $1.size }
    }
}
