import CleanDriveCore
import SwiftUI

struct CleanDrivePreviewView: View {
    @ObservedObject var model: CleanDriveModel
    let categoryID: CleanDriveCategoryID
    let onBack: () -> Void

    private var category: CleanDriveCategorySnapshot? {
        model.categories.first { $0.id == categoryID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            previewHeader

            if let category {
                previewSummary(for: category)
                previewContent(for: category)
            } else {
                emptyMessage("Category is not available.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var previewHeader: some View {
        HStack(spacing: 8) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back")
            .accessibilityLabel("Back")

            Text(category?.displayName ?? "Files")
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)

            Spacer()
        }
    }

    private func previewSummary(for category: CleanDriveCategorySnapshot) -> some View {
        HStack(spacing: 8) {
            Label(
                CleanDriveFormatter.bytes(category.totalBytes),
                systemImage: category.symbolName
            )

            Text("\(category.items.count) \(category.items.count == 1 ? "item" : "items")")
                .foregroundStyle(.secondary)

            if category.isScanning {
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
    }

    @ViewBuilder
    private func previewContent(for category: CleanDriveCategorySnapshot) -> some View {
        if category.permissionDenied {
            emptyMessage("Full Disk Access is needed.")
        } else if let errorMessage = category.errorMessage {
            emptyMessage(errorMessage)
        } else if category.isScanning && category.items.isEmpty {
            loadingMessage
        } else if category.items.isEmpty {
            emptyMessage("No files found.")
        } else {
            fileList(for: category)
        }
    }

    private var loadingMessage: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading files...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fileList(for category: CleanDriveCategorySnapshot) -> some View {
        let visibleItems = category.items
            .sorted { $0.size > $1.size }
            .prefix(80)

        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(visibleItems)) { item in
                    fileRow(item)
                }

                if category.items.count > visibleItems.count {
                    Text("Showing largest \(visibleItems.count) files.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxHeight: .infinity)
    }

    private func fileRow(_ item: CleanDriveItem) -> some View {
        HStack(spacing: 9) {
            Image(systemName: item.kind == .directory ? "folder" : "doc")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                FinderItemLinkLabel(url: item.url)

                Text(item.url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(CleanDriveFormatter.bytes(item.size))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .frame(minWidth: 58, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}
