import AppCore
import AppKit
import SwiftUI

struct FinderLinkLabel: View {
    @Environment(\.appLocalization) private var localization
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
        .help(localization("Show in Finder"))
        .accessibilityLabel(localization("Show %@ in Finder", url.lastPathComponent))
        .onHover { isHovering = $0 }
    }
}
