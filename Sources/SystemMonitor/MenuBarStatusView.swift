import AppKit

final class MenuBarStatusView: NSView {
    private var lines: [MenuBarStatusLine] = [MenuBarStatusLine(text: "CPU --  NET --")]
    private let horizontalPadding: CGFloat = 7
    private let segmentSeparator = "  "
    private let compactSegmentSpacing: CGFloat = 6
    private let iconTextSpacing: CGFloat = 3
    private let minimumWidth: CGFloat = 48

    override var isFlipped: Bool {
        true
    }

    var preferredWidth: CGFloat {
        let font = drawingFont
        let width = lines
            .map { ceil(lineWidth($0, font: font)) }
            .max() ?? 0
        return max(minimumWidth, width + horizontalPadding * 2)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: NSStatusBar.system.thickness)
    }

    func update(lines: [MenuBarStatusLine]) {
        self.lines = Array(lines.prefix(2))
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !lines.isEmpty else {
            return
        }

        let font = drawingFont
        let lineHeights = lines.map { height(of: $0, font: font) }
        let gap: CGFloat = lines.count > 1 ? -1 : 0
        let totalHeight = lineHeights.reduce(0, +)
            + gap * CGFloat(max(0, lines.count - 1))
        var y = floor((bounds.height - totalHeight) / 2)

        for (index, line) in lines.enumerated() {
            draw(line, font: font, y: y)
            y += lineHeights[index] + gap
        }
    }

    private var drawingFont: NSFont {
        lines.count > 1
            ? .monospacedSystemFont(ofSize: 8.5, weight: .medium)
            : .monospacedSystemFont(ofSize: 11, weight: .medium)
    }

    private func attributedLine(_ line: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(
            string: line,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func lineWidth(_ line: MenuBarStatusLine, font: NSFont) -> CGFloat {
        guard !line.segments.isEmpty else {
            return 0
        }

        let segmentsWidth = line.segments.reduce(CGFloat.zero) { total, segment in
            total + segmentWidth(segment, font: font)
        }
        return segmentsWidth + segmentSpacing(for: line, font: font) * CGFloat(line.segments.count - 1)
    }

    private func height(of line: MenuBarStatusLine, font: NSFont) -> CGFloat {
        line.segments.map { segment in
            max(
                attributedLine(segment.text, font: font).size().height,
                symbolImage(for: segment, font: font)?.size.height ?? 0
            )
        }
            .max() ?? attributedLine("", font: font).size().height
    }

    private func draw(_ line: MenuBarStatusLine, font: NSFont, y: CGFloat) {
        var x = horizontalPadding
        let lineHeight = height(of: line, font: font)

        for segment in line.segments {
            draw(segment, font: font, x: x, y: y, lineHeight: lineHeight)
            x += segmentWidth(segment, font: font) + segmentSpacing(for: line, font: font)
        }
    }

    private func segmentWidth(_ segment: MenuBarStatusSegment, font: NSFont) -> CGFloat {
        if let image = symbolImage(for: segment, font: font) {
            return image.size.width + iconTextSpacing + reservedTextWidth(for: segment, font: font)
        }

        return reservedFallbackWidth(for: segment, font: font)
    }

    private func segmentSpacing(for line: MenuBarStatusLine, font: NSFont) -> CGFloat {
        if line.segments.contains(where: { $0.symbolName != nil }) {
            return compactSegmentSpacing
        }

        return attributedLine(segmentSeparator, font: font).size().width
    }

    private func draw(
        _ segment: MenuBarStatusSegment,
        font: NSFont,
        x: CGFloat,
        y: CGFloat,
        lineHeight: CGFloat
    ) {
        if let image = symbolImage(for: segment, font: font) {
            let iconY = y + floor((lineHeight - image.size.height) / 2)
            image.draw(
                at: NSPoint(x: x, y: iconY),
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1
            )

            let textY = y + floor((lineHeight - attributedLine(segment.text, font: font).size().height) / 2)
            attributedLine(segment.text, font: font).draw(
                at: NSPoint(x: x + image.size.width + iconTextSpacing, y: textY)
            )
            return
        }

        let text = displayTextWithFallback(for: segment)
        let textY = y + floor((lineHeight - attributedLine(text, font: font).size().height) / 2)
        attributedLine(text, font: font).draw(at: NSPoint(x: x, y: textY))
    }

    private func reservedTextWidth(for segment: MenuBarStatusSegment, font: NSFont) -> CGFloat {
        max(
            attributedLine(segment.text, font: font).size().width,
            attributedLine(segment.reservedText, font: font).size().width
        )
    }

    private func reservedFallbackWidth(for segment: MenuBarStatusSegment, font: NSFont) -> CGFloat {
        max(
            attributedLine(displayTextWithFallback(for: segment), font: font).size().width,
            attributedLine(reservedTextWithFallback(for: segment), font: font).size().width
        )
    }

    private func displayTextWithFallback(for segment: MenuBarStatusSegment) -> String {
        guard let fallbackPrefix = segment.fallbackPrefix else {
            return segment.text
        }

        return "\(fallbackPrefix) \(segment.text)"
    }

    private func reservedTextWithFallback(for segment: MenuBarStatusSegment) -> String {
        guard let fallbackPrefix = segment.fallbackPrefix else {
            return segment.reservedText
        }

        return "\(fallbackPrefix) \(segment.reservedText)"
    }

    private func symbolImage(for segment: MenuBarStatusSegment, font: NSFont) -> NSImage? {
        guard
            let symbolName = segment.symbolName,
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: segment.fallbackPrefix)
        else {
            return nil
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .medium)
        let configuredImage = image.withSymbolConfiguration(configuration) ?? image
        guard let tintedImage = configuredImage.copy() as? NSImage else {
            return configuredImage
        }

        tintedImage.lockFocus()
        NSColor.labelColor.set()
        NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
        tintedImage.unlockFocus()
        return tintedImage
    }
}
