import AppKit

final class MenuBarStatusView: NSView {
    private var lines: [MenuBarStatusLine] = [MenuBarStatusLine(text: "CPU --  NET --")]
    private let horizontalPadding: CGFloat = 7
    private let segmentSeparator = "  "
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
        return segmentsWidth + segmentSpacing(font: font) * CGFloat(line.segments.count - 1)
    }

    private func height(of line: MenuBarStatusLine, font: NSFont) -> CGFloat {
        line.segments
            .map { attributedLine($0.text, font: font).size().height }
            .max() ?? attributedLine("", font: font).size().height
    }

    private func draw(_ line: MenuBarStatusLine, font: NSFont, y: CGFloat) {
        var x = horizontalPadding

        for segment in line.segments {
            attributedLine(segment.text, font: font).draw(at: NSPoint(x: x, y: y))
            x += segmentWidth(segment, font: font) + segmentSpacing(font: font)
        }
    }

    private func segmentWidth(_ segment: MenuBarStatusSegment, font: NSFont) -> CGFloat {
        max(
            attributedLine(segment.text, font: font).size().width,
            attributedLine(segment.reservedText, font: font).size().width
        )
    }

    private func segmentSpacing(font: NSFont) -> CGFloat {
        attributedLine(segmentSeparator, font: font).size().width
    }
}
