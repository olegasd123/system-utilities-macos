import Foundation

public struct MenuBarStatusLine: Equatable, Sendable {
    public var segments: [MenuBarStatusSegment]

    public init(segments: [MenuBarStatusSegment]) {
        self.segments = segments
    }

    public init(text: String) {
        segments = [MenuBarStatusSegment(text: text, reservedText: text)]
    }

    public var text: String {
        segments.map(\.text).joined(separator: "  ")
    }
}

public struct MenuBarStatusSegment: Equatable, Sendable {
    public var text: String
    public var reservedText: String
    public var symbolName: String?
    public var fallbackPrefix: String?

    public init(
        text: String,
        reservedText: String,
        symbolName: String? = nil,
        fallbackPrefix: String? = nil
    ) {
        self.text = text
        self.reservedText = reservedText
        self.symbolName = symbolName
        self.fallbackPrefix = fallbackPrefix
    }
}
