import SwiftUI

struct AppUninstallerLoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(8)
    }
}

struct AppUninstallerEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
