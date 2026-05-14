import AppKit
import SwiftUI

struct FinderItemLinkLabel: View {
    let url: URL
    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } label: {
            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering ? .blue : .primary)
                .underline(isHovering)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .help("Show in Finder")
        .accessibilityLabel("Show \(url.lastPathComponent) in Finder")
        .onHover { isHovering = $0 }
    }
}
