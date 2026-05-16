import AppCore
import AppKit
import AppUI
import CleanDriveCore
import SwiftUI

struct CleanDriveSettingsView: View {
    @Environment(\.appLocalization) private var localization
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
            customFoldersSection
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
                        Text(localizedCategoryName(category.displayName))
                        if category.requiresFullDiskAccess {
                            Text(localization("Full Disk Access may be needed"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var customFoldersSection: some View {
        SettingsSection("Custom folders") {
            Text(localization("Clean folder contents. The folders stay."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if settingsModel.settings.customFolders.isEmpty {
                Text(localization("No custom folders."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(settingsModel.settings.customFolders) { folder in
                        customFolderRow(folder)
                    }
                }
            }

            Button {
                addCustomFolder()
            } label: {
                Label(localization("Add Folder..."), systemImage: "plus")
            }
            .controlSize(.small)
        }
    }

    private func customFolderRow(_ folder: CleanDriveCustomFolder) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(folder.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button {
                removeCustomFolder(folder)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help(localization("Remove folder"))
            .accessibilityLabel(localization("Remove folder"))
        }
    }

    private var remindersSection: some View {
        SettingsSection("Clean Drive reminders") {
            Toggle(
                localization("Tell me when cleanup is ready"),
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
                        Text(localization("Threshold"))
                        Slider(value: thresholdGBBinding, in: 1...20, step: 1)
                        Text(
                            AppFormatters.compactBytes(
                                settingsModel.settings.reminders.thresholdBytes,
                                localization: localization
                            )
                        )
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }

                    Stepper(
                        localization(
                            "Minimum gap: %@",
                            AppFormatters.duration(
                                UInt64(settingsModel.settings.reminders.minHoursBetweenReminders * 60 * 60),
                                localization: localization
                            )
                        ),
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
                localization("Clean up mode"),
                selection: $settingsModel.settings.reclaim.permanentlyDelete
            ) {
                Text(localization("Move to Trash")).tag(false)
                Text(localization("Permanently delete")).tag(true)
            }
            .pickerStyle(.radioGroup)

            if settingsModel.settings.reclaim.permanentlyDelete {
                Text(localization("Files are removed right away. This cannot be undone."))
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            } else {
                Text(localization("Files go to Trash. You can restore them later."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var advancedSection: some View {
        SettingsSection("Advanced") {
            Stepper(
                localization(
                    "Downloads older than %d days",
                    settingsModel.settings.reclaim.downloadsOlderThanDays
                ),
                value: $settingsModel.settings.reclaim.downloadsOlderThanDays,
                in: 1...365
            )

            Stepper(
                localization(
                    "Xcode archives older than %d days",
                    settingsModel.settings.reclaim.xcodeArchivesOlderThanDays
                ),
                value: $settingsModel.settings.reclaim.xcodeArchivesOlderThanDays,
                in: 1...365
            )
        }
    }

    private func addCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = localization("Add")
        panel.message = localization("Choose folders to clean.")

        guard panel.runModal() == .OK else {
            return
        }

        var settings = settingsModel.settings
        var knownPaths = Set(settings.customFolders.map(\.path))
        for url in panel.urls.map(\.standardizedFileURL) {
            guard CleanDriveCustomFolder.canUse(url) else {
                continue
            }
            let folder = CleanDriveCustomFolder(path: url.path)
            guard !knownPaths.contains(folder.path) else {
                continue
            }
            settings.customFolders.append(folder)
            knownPaths.insert(folder.path)
        }

        guard settings != settingsModel.settings else {
            return
        }

        settings.setCategoryEnabled(true, id: .customFolders)
        settingsModel.settings = settings
        Task {
            await model.scanCategory(id: .customFolders)
        }
    }

    private func removeCustomFolder(_ folder: CleanDriveCustomFolder) {
        var settings = settingsModel.settings
        settings.customFolders.removeAll { $0.path == folder.path }
        if settings.customFolders.isEmpty {
            settings.setCategoryEnabled(false, id: .customFolders)
        }
        settingsModel.settings = settings
        Task {
            await model.scanCategory(id: .customFolders)
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
}
