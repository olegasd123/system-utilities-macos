import AppCore
import AppKit
import AppUI
import CleanDriveCore
import Foundation
import SwiftUI

@MainActor
public final class CleanDriveFeature: ObservableObject, PopoverFeature {
    public let id = CleanDriveSettings.featureId
    public let displayName = "Clean Drive"
    public let symbolName = "internaldrive"

    public let model: CleanDriveModel

    private let settings: SettingsModel<CleanDriveSettings>

    public init(
        settings: SettingsModel<CleanDriveSettings>,
        model: CleanDriveModel
    ) {
        self.settings = settings
        self.model = model
    }

    public func makeRootView() -> AnyView {
        AnyView(CleanDriveView(model: model, settingsModel: settings))
    }

    public func makeSettingsSection() -> AnyView? {
        AnyView(CleanDriveSettingsView(settings: settings, model: model))
    }
}

private struct CleanDriveView: View {
    @ObservedObject var model: CleanDriveModel
    @ObservedObject var settingsModel: SettingsModel<CleanDriveSettings>
    @State private var previewCategoryID: CleanDriveCategoryID?
    @State private var showsHardDeleteConfirmation = false

    var body: some View {
        Group {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await model.scan()
        }
        .confirmationDialog(
            "Permanently delete selected items?",
            isPresented: $showsHardDeleteConfirmation
        ) {
            Button("Delete Permanently", role: .destructive) {
                Task {
                    await model.reclaimSelectedItems(mode: .hardDelete)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. \(selectedCategoryText)")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(CleanDriveFormatter.bytes(model.totalBytes))
                .font(.system(size: 34, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Ready for cleanup")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(category.displayName)
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
                Button("Show files...") {
                    previewCategoryID = category.id
                }
                .controlSize(.small)

                ProgressView()
                    .controlSize(.small)
            }
        } else if category.isReclaiming {
            ProgressView()
                .controlSize(.small)
        } else if category.permissionDenied {
            Button("Grant Access") {
                openFullDiskAccess()
            }
            .controlSize(.small)
        } else {
            HStack(spacing: 8) {
                if category.totalBytes > 0 {
                    Button("Show files...") {
                        previewCategoryID = category.id
                    }
                    .controlSize(.small)
                }

                Text(CleanDriveFormatter.bytes(category.totalBytes))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(category.totalBytes == 0 ? .secondary : .primary)
                    .frame(minWidth: 66, alignment: .trailing)
            }
        }
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
            Text("Nothing to clean.")
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
            .help("Scan again")
            .disabled(model.isScanning || model.isReclaiming)

            Picker("", selection: $settingsModel.settings.reclaim.permanentlyDelete) {
                Text("Move to Trash").tag(false)
                Text("Delete").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
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
                    Text(settingsModel.settings.reclaim.permanentlyDelete ? "Delete" : "Clean Up")
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
        return "Selected categories: \(names.joined(separator: ", "))."
    }

    private var firstErrorMessage: String? {
        model.categories.first { $0.errorMessage != nil }?.errorMessage
    }

    private func rowSubtitle(for category: CleanDriveCategorySnapshot) -> String {
        if category.permissionDenied {
            return "Full Disk Access needed"
        }
        if category.isScanning {
            return "Scanning"
        }
        if category.isReclaiming {
            return "Cleaning"
        }
        if category.items.isEmpty {
            return "No items found"
        }
        let count = category.items.count
        return "\(count) \(count == 1 ? "item" : "items") found"
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
            return "Reclaimed \(CleanDriveFormatter.bytes(report.bytesReclaimed))."
        }
        return "Reclaimed \(CleanDriveFormatter.bytes(report.bytesReclaimed)). \(report.failures.count) failed."
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

private struct CleanDriveSettingsView: View {
    @ObservedObject var settingsModel: SettingsModel<CleanDriveSettings>
    @ObservedObject var model: CleanDriveModel

    init(
        settings: SettingsModel<CleanDriveSettings>,
        model: CleanDriveModel
    ) {
        self.settingsModel = settings
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            categoriesSection
            remindersSection
            reclaimSafetySection
            advancedSection
        }
    }

    private var categoriesSection: some View {
        SettingsSection("Clean Drive categories") {
            ForEach(model.categories) { category in
                Toggle(isOn: categoryEnabledBinding(for: category)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                        if category.requiresFullDiskAccess {
                            Text("Full Disk Access may be needed")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var remindersSection: some View {
        SettingsSection("Clean Drive reminders") {
            Toggle(
                "Tell me when cleanup is ready",
                isOn: $settingsModel.settings.reminders.enabled
            )
            .onChange(of: settingsModel.settings.reminders.enabled) { _, enabled in
                if enabled {
                    NotificationPermissionService.requestPermission()
                }
            }

            if settingsModel.settings.reminders.enabled {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Threshold")
                        Slider(value: thresholdGBBinding, in: 1...20, step: 1)
                        Text("\(Int(thresholdGBBinding.wrappedValue)) GB")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }

                    Stepper(
                        "Minimum gap: \(settingsModel.settings.reminders.minHoursBetweenReminders) h",
                        value: $settingsModel.settings.reminders.minHoursBetweenReminders,
                        in: 1...168
                    )
                }
                .padding(.leading, 16)
            }
        }
    }

    private var reclaimSafetySection: some View {
        SettingsSection("Reclaim safety") {
            Picker(
                "Clean up mode",
                selection: $settingsModel.settings.reclaim.permanentlyDelete
            ) {
                Text("Move to Trash").tag(false)
                Text("Permanently delete").tag(true)
            }
            .pickerStyle(.radioGroup)

            if settingsModel.settings.reclaim.permanentlyDelete {
                Text("Files are removed right away. This cannot be undone.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            } else {
                Text("Files go to Trash. You can restore them later.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var advancedSection: some View {
        SettingsSection("Advanced") {
            Stepper(
                "Downloads older than \(settingsModel.settings.reclaim.downloadsOlderThanDays) days",
                value: $settingsModel.settings.reclaim.downloadsOlderThanDays,
                in: 1...365
            )

            Stepper(
                "Xcode archives older than \(settingsModel.settings.reclaim.xcodeArchivesOlderThanDays) days",
                value: $settingsModel.settings.reclaim.xcodeArchivesOlderThanDays,
                in: 1...365
            )
        }
    }

    private func categoryEnabledBinding(
        for category: CleanDriveCategorySnapshot
    ) -> Binding<Bool> {
        Binding(
            get: { category.isIncluded },
            set: { model.setIncluded($0, for: category.id) }
        )
    }

    private var thresholdGBBinding: Binding<Double> {
        Binding(
            get: {
                Double(settingsModel.settings.reminders.thresholdBytes) / Self.bytesPerGB
            },
            set: { value in
                settingsModel.settings.reminders.thresholdBytes = UInt64(value * Self.bytesPerGB)
            }
        )
    }

    private static let bytesPerGB = Double(1_024 * 1_024 * 1_024)
}

private struct CleanDrivePreviewView: View {
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
                Text(item.url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

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

private enum CleanDriveFormatter {
    static func bytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }

        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1024
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%.1f %@", value, units[index])
    }
}
