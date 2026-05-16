import Foundation

public struct InstalledApp: Identifiable, Equatable, Sendable {
    public var id: String { "\(bundleIdentifier)|\(bundleURL.path)" }
    public var bundleIdentifier: String
    public var name: String
    public var version: String?
    public var iconURL: URL?
    public var bundleURL: URL
    public var bundleSize: UInt64
    public var sourceLocation: String
    public var executableName: String?
    public var isSystem: Bool
    public var appGroupIdentifiers: [String]

    public init(
        bundleIdentifier: String,
        name: String,
        version: String? = nil,
        iconURL: URL? = nil,
        bundleURL: URL,
        bundleSize: UInt64 = 0,
        sourceLocation: String,
        executableName: String? = nil,
        isSystem: Bool,
        appGroupIdentifiers: [String] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.iconURL = iconURL
        self.bundleURL = bundleURL
        self.bundleSize = bundleSize
        self.sourceLocation = sourceLocation
        self.executableName = executableName
        self.isSystem = isSystem
        self.appGroupIdentifiers = appGroupIdentifiers
    }
}
