import AppCore
import AppKit
import SwiftUI

struct FinderItemLinkLabel: View {
    @Environment(\.appLocalization) private var localization
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
        .help(localization("Show in Finder"))
        .accessibilityLabel(localization("Show %@ in Finder", url.lastPathComponent))
        .onHover { isHovering = $0 }
    }
}
