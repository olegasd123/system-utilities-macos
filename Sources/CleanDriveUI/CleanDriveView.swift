import AppCore
import AppKit
import AppUI
import CleanDriveCore
import SwiftUI

struct CleanDriveView: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject var model: CleanDriveModel
    @ObservedObject var settingsModel: SettingsModel<CleanDriveSettings>
    @State private var previewCategoryID: CleanDriveCategoryID?
    @State private var showsHardDeleteConfirmation = false

    var body: some View {
        ZStack {
            content

            if showsHardDeleteConfirmation {
                hardDeleteConfirmation
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await model.scanIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let previewCategoryID {
            CleanDrivePreviewView(
                model: model,
                categoryID: previewCategoryID
            ) {
                self.previewCategoryID = nil
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                summary
                categoryList
                statusMessage
                footer
            }
        }
    }

    private var hardDeleteConfirmation: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(localization("Permanently delete selected items?"))
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(localization("This cannot be undone. %@", selectedCategoryText))
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    Button(role: .destructive) {
                        confirmHardDelete()
                    } label: {
                        Text(localization("Delete Permanently"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .background(Color.red.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))

                    Button(role: .cancel) {
                        showsHardDeleteConfirmation = false
                    } label: {
                        Text(localization("Cancel"))
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(22)
            .frame(width: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.secondary.opacity(0.45), lineWidth: 1)
            }
            .shadow(radius: 18)
        }
        .transition(.opacity)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(CleanDriveFormatter.bytes(model.totalBytes, localization: localization))
                .font(.system(size: 34, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(summaryStatusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryStatusText: String {
        model.isScanning ? localization("Collecting cleanup data") : localization("Ready for cleanup")
    }

    private var categoryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.categories) { category in
                    categoryRow(category)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxHeight: .infinity)
    }

    private func categoryRow(_ category: CleanDriveCategorySnapshot) -> some View {
        HStack(spacing: 9) {
            Toggle(
                "",
                isOn: Binding(
                    get: { category.isIncluded },
                    set: { model.setIncluded($0, for: category.id) }
                )
            )
            .labelsHidden()
            .disabled(category.isReclaiming || category.permissionDenied)

            Image(systemName: category.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(rowAccent(for: category))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedCategoryName(category.displayName))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(rowSubtitle(for: category))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailingControls(for: category)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func trailingControls(for category: CleanDriveCategorySnapshot) -> some View {
        if category.isScanning {
            HStack(spacing: 8) {
                showFilesButton(for: category)

                ProgressView()
                    .controlSize(.small)
            }
        } else if category.isReclaiming {
            ProgressView()
                .controlSize(.small)
        } else if category.permissionDenied {
            Button(localization("Grant Access")) {
                openFullDiskAccess()
            }
            .controlSize(.small)
        } else {
            HStack(spacing: 8) {
                if category.totalBytes > 0 {
                    showFilesButton(for: category)
                }

                Text(CleanDriveFormatter.bytes(category.totalBytes, localization: localization))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(category.totalBytes == 0 ? .secondary : .primary)
                    .frame(minWidth: 66, alignment: .trailing)
            }
        }
    }

    private func showFilesButton(for category: CleanDriveCategorySnapshot) -> some View {
        Button {
            previewCategoryID = category.id
        } label: {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 20)
        }
        .controlSize(.small)
        .buttonStyle(.plain)
        .help(localization("Show files"))
        .accessibilityLabel(localization("Show files"))
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let message = firstErrorMessage {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .lineLimit(2)
        } else if let report = model.lastReclaimReport {
            Text(cleanupSummary(report))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else if model.totalBytes == 0, !model.isScanning {
            Text(localization("Nothing to clean."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await model.scan()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(localization("Scan again"))
            .disabled(model.isScanning || model.isReclaiming)

            Picker("", selection: $settingsModel.settings.reclaim.permanentlyDelete) {
                Text(localization("Move to Trash")).tag(false)
                Text(localization("Delete")).tag(true)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
            .disabled(model.isReclaiming)

            Spacer()

            Button {
                if settingsModel.settings.reclaim.permanentlyDelete {
                    showsHardDeleteConfirmation = true
                } else {
                    Task {
                        await model.reclaimSelectedItems(mode: .moveToTrash)
                    }
                }
            } label: {
                if model.isReclaiming {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Text(localization(settingsModel.settings.reclaim.permanentlyDelete ? "Delete" : "Clean Up"))
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canReclaimSelectedItems)
        }
    }

    private var selectedCategoryText: String {
        let names = model.selectedCategoryNames
        guard !names.isEmpty else {
            return ""
        }
        return localization("Selected categories: %@.", names.map(localizedCategoryName).joined(separator: ", "))
    }

    private func confirmHardDelete() {
        showsHardDeleteConfirmation = false
        Task {
            await model.reclaimSelectedItems(mode: .hardDelete)
        }
    }

    private var firstErrorMessage: String? {
        model.categories.first { $0.errorMessage != nil }?.errorMessage
    }

    private func rowSubtitle(for category: CleanDriveCategorySnapshot) -> String {
        if category.permissionDenied {
            return localization("Full Disk Access needed")
        }
        if category.isScanning {
            return localization("Scanning")
        }
        if category.isReclaiming {
            return localization("Cleaning")
        }
        if category.items.isEmpty {
            return localization("No items found")
        }
        let count = category.items.count
        return count == 1
            ? localization("%d item found", count)
            : localization("%d items found", count)
    }

    private func rowAccent(for category: CleanDriveCategorySnapshot) -> Color {
        if category.permissionDenied {
            return .orange
        }
        if category.totalBytes == 0 {
            return .secondary
        }
        return .cyan
    }

    private func cleanupSummary(_ report: ReclaimReport) -> String {
        if report.failures.isEmpty {
            return localization(
                "Reclaimed %@.",
                CleanDriveFormatter.bytes(report.bytesReclaimed, localization: localization)
            )
        }
        return localization(
            "Reclaimed %@. %d failed.",
            CleanDriveFormatter.bytes(report.bytesReclaimed, localization: localization),
            report.failures.count
        )
    }

    private func localizedCategoryName(_ name: String) -> String {
        if let days = olderThanDays(in: name, prefix: "Downloads (older than ") {
            return localization("Downloads (older than %d days)", days)
        }
        if let days = olderThanDays(in: name, prefix: "Xcode archives (older than ") {
            return localization("Xcode archives (older than %d days)", days)
        }
        return localization(name)
    }

    private func olderThanDays(in name: String, prefix: String) -> Int? {
        guard name.hasPrefix(prefix), name.hasSuffix(" days)") else {
            return nil
        }
        let value = name.dropFirst(prefix.count).dropLast(" days)".count)
        return Int(value)
    }

    private func openFullDiskAccess() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
