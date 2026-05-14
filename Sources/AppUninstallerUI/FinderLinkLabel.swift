import AppKit
import SwiftUI

struct FinderLinkLabel: View {
    let url: URL
    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } label: {
            Text(url.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .underline(isHovering)
                .foregroundStyle(isHovering ? .blue : .primary)
        }
        .buttonStyle(.plain)
        .help("Show in Finder")
        .accessibilityLabel("Show \(url.lastPathComponent) in Finder")
        .onHover { isHovering = $0 }
    }
}
