import AppKit

final class MenuBarStatusView: NSView {
    private var lines: [String] = ["CPU --  NET --"]
    private let horizontalPadding: CGFloat = 7
    private let minimumWidth: CGFloat = 48

    override var isFlipped: Bool {
        true
    }

    var preferredWidth: CGFloat {
        let font = drawingFont
        let width = lines
            .map { ceil(attributedLine($0, font: font).size().width) }
            .max() ?? 0
        return max(minimumWidth, width + horizontalPadding * 2)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: NSStatusBar.system.thickness)
    }

    func update(lines: [String]) {
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
        let attributedLines = lines.map { attributedLine($0, font: font) }
        let sizes = attributedLines.map { $0.size() }
        let gap: CGFloat = lines.count > 1 ? -1 : 0
        let totalHeight = sizes.reduce(0) { $0 + $1.height }
            + gap * CGFloat(max(0, lines.count - 1))
        var y = floor((bounds.height - totalHeight) / 2)

        for (index, line) in attributedLines.enumerated() {
            line.draw(at: NSPoint(x: horizontalPadding, y: y))
            y += sizes[index].height + gap
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
}
