import AppCore
import AppKit
import AppUninstallerCore
import SwiftUI

struct AppUninstallerView: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject var model: AppUninstallerModel
    @ObservedObject var settingsModel: SettingsModel<AppUninstallerSettings>
    @State private var showsConfirmation = false
    @State private var isLeftoverListExpanded = false
    private let appListHeight: CGFloat = 220

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                searchField
                appList
                if showsLeftoverPane {
                    AppUninstallerLeftoverPane(
                        model: model,
                        isExpanded: $isLeftoverListExpanded
                    )
                }
                statusMessage
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showsConfirmation {
                AppUninstallerConfirmationOverlay(
                    model: model,
                    settingsModel: settingsModel,
                    isPresented: $showsConfirmation
                )
                .zIndex(1)
            }
        }
        .task {
            await model.loadAppsIfNeeded()
        }
        .onChange(of: model.selectedApp?.id) {
            isLeftoverListExpanded = false
        }
    }

    private var searchField: some View {
        TextField(localization("Search apps"), text: $model.query)
            .textFieldStyle(.roundedBorder)
    }

    private var showsLeftoverPane: Bool {
        model.selectedApp != nil || model.scanResult != nil || model.isScanningLeftovers
    }

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if model.isLoadingApps {
                    AppUninstallerLoadingRow(text: localization("Scanning installed apps..."))
                } else if model.filteredApps.isEmpty {
                    AppUninstallerEmptyRow(text: localization("No apps found."))
                } else {
                    ForEach(model.filteredApps) { app in
                        appRow(app)
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .frame(height: usesCompactAppList ? appListHeight : nil)
        .frame(maxHeight: usesCompactAppList ? nil : .infinity)
    }

    private var usesCompactAppList: Bool {
        showsLeftoverPane && isLeftoverListExpanded
    }

    private func appRow(_ app: InstalledApp) -> some View {
        Button {
            model.selectApp(app)
        } label: {
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable()
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(appSubtitle(app))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Text(AppUninstallerFormatter.bytes(app.bundleSize, localization: localization))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 62, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground(app), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func appSubtitle(_ app: InstalledApp) -> String {
        let version = app.version.map { " v\($0)" } ?? ""
        return "\(app.bundleIdentifier)\(version)"
    }

    private func rowBackground(_ app: InstalledApp) -> some ShapeStyle {
        model.selectedApp?.id == app.id
            ? AnyShapeStyle(Color.accentColor.opacity(0.18))
            : AnyShapeStyle(Color.secondary.opacity(0.08))
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let message = model.errorMessage {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .lineLimit(2)
        } else if let report = model.lastReclaimReport {
            Text(reportSummary(report))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await model.loadApps()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(localization("Scan again"))
            .disabled(model.isLoadingApps || model.isScanningLeftovers || model.isUninstalling)

            Picker("", selection: $settingsModel.settings.defaultReclaimMode) {
                Text(localization("Move to Trash")).tag(ReclaimMode.moveToTrash)
                Text(localization("Delete")).tag(ReclaimMode.hardDelete)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
            .disabled(model.isUninstalling)

            Spacer()

            Text(AppUninstallerFormatter.bytes(model.selectedBytes, localization: localization))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                showsConfirmation = true
            } label: {
                if model.isUninstalling {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Text(localization(settingsModel.settings.defaultReclaimMode == .hardDelete ? "Delete" : "Uninstall"))
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canUninstall)
        }
    }

    private func reportSummary(_ report: ReclaimReport) -> String {
        if report.failures.isEmpty {
            return localization(
                "Reclaimed %@.",
                AppUninstallerFormatter.bytes(report.bytesReclaimed, localization: localization)
            )
        }
        return localization(
            "Reclaimed %@. %d failed.",
            AppUninstallerFormatter.bytes(report.bytesReclaimed, localization: localization),
            report.failures.count
        )
    }
}
