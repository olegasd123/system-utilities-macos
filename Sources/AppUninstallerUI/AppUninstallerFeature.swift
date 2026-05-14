import AppCore
import AppKit
import AppUI
import AppUninstallerCore
import Foundation
import SwiftUI

@MainActor
public final class AppUninstallerFeature: ObservableObject, PopoverFeature {
    public let id = AppUninstallerSettings.featureId
    public let displayName = "App Uninstaller"
    public let symbolName = "app.badge"

    public let model: AppUninstallerModel
    private let settings: SettingsModel<AppUninstallerSettings>

    public init(
        settings: SettingsModel<AppUninstallerSettings>,
        model: AppUninstallerModel
    ) {
        self.settings = settings
        self.model = model
    }

    public func makeRootView() -> AnyView {
        AnyView(AppUninstallerView(model: model, settingsModel: settings))
    }

    public func makeSettingsSection() -> AnyView? {
        AnyView(AppUninstallerSettingsView(settings: settings))
    }
}

private struct AppUninstallerView: View {
    @ObservedObject var model: AppUninstallerModel
    @ObservedObject var settingsModel: SettingsModel<AppUninstallerSettings>
    @State private var showsConfirmation = false
    private let appListHeight: CGFloat = 220

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                searchField
                appList
                if showsLeftoverPane {
                    detailPane
                }
                statusMessage
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showsConfirmation {
                confirmationOverlay
                    .zIndex(1)
            }
        }
        .task {
            await model.loadAppsIfNeeded()
        }
    }

    private var searchField: some View {
        TextField("Search apps", text: $model.query)
            .textFieldStyle(.roundedBorder)
    }

    private var showsLeftoverPane: Bool {
        model.isScanningLeftovers || model.scanResult?.leftovers.isEmpty == false
    }

    @ViewBuilder
    private var appList: some View {
        let list = ScrollView {
            LazyVStack(spacing: 6) {
                if model.isLoadingApps {
                    loadingRow("Scanning installed apps...")
                } else if model.filteredApps.isEmpty {
                    emptyRow("No apps found.")
                } else {
                    ForEach(model.filteredApps) { app in
                        appRow(app)
                    }
                }
            }
            .padding(.vertical, 1)
        }

        if showsLeftoverPane {
            list.frame(height: appListHeight)
        } else {
            list.frame(maxHeight: .infinity)
        }
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

                Text(AppUninstallerFormatter.bytes(app.bundleSize))
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
    private var detailPane: some View {
        if model.isScanningLeftovers {
            loadingRow("Scanning leftovers...")
                .frame(maxHeight: .infinity, alignment: .top)
        } else if let result = model.scanResult, !result.leftovers.isEmpty {
            leftoverList(result)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            Color.clear
                .frame(maxHeight: .infinity)
        }
    }

    private func leftoverList(_ result: LeftoverScanResult) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 7) {
                candidateGroup("Exact match", candidates: group(.exactBundleID, in: result))
                candidateGroup("Related", candidates: group(.bundleIDPrefix, in: result))
                candidateGroup("Possible", candidates: group(.nameHeuristic, in: result))

                ForEach(result.notes, id: \.self) { note in
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func group(
        _ confidence: LeftoverConfidence,
        in result: LeftoverScanResult
    ) -> [LeftoverCandidate] {
        result.leftovers.filter { $0.confidence == confidence }
    }

    @ViewBuilder
    private func candidateGroup(_ title: String, candidates: [LeftoverCandidate]) -> some View {
        if !candidates.isEmpty {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(candidates) { candidate in
                candidateRow(candidate)
            }
        }
    }

    private func candidateRow(_ candidate: LeftoverCandidate) -> some View {
        HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { model.selectedLeftoverIDs.contains(candidate.id) },
                    set: { model.setSelected(candidate, isSelected: $0) }
                )
            )
            .labelsHidden()
            .disabled(model.isUninstalling)

            Image(systemName: candidate.kind == .directory ? "folder" : "doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                FinderLinkLabel(url: candidate.url)

                Text(candidate.url.deletingLastPathComponent().path)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            Text(AppUninstallerFormatter.bytes(candidate.size))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
            .help("Scan again")
            .disabled(model.isLoadingApps || model.isScanningLeftovers || model.isUninstalling)

            Picker("", selection: $settingsModel.settings.defaultReclaimMode) {
                Text("Move to Trash").tag(ReclaimMode.moveToTrash)
                Text("Delete").tag(ReclaimMode.hardDelete)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
            .disabled(model.isUninstalling)

            Spacer()

            Text(AppUninstallerFormatter.bytes(model.selectedBytes))
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
                    Text(settingsModel.settings.defaultReclaimMode == .hardDelete ? "Delete" : "Uninstall")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canUninstall)
        }
    }

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(confirmationTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(confirmationMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    Button(role: settingsModel.settings.defaultReclaimMode == .hardDelete ? .destructive : nil) {
                        confirmUninstall()
                    } label: {
                        Text(confirmationButtonTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(confirmButtonBackground, in: RoundedRectangle(cornerRadius: 8))

                    Button("Cancel") {
                        showsConfirmation = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
            .frame(width: 286)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.45), lineWidth: 1)
            }
            .shadow(radius: 18)
        }
        .transition(.opacity)
    }

    private var confirmationTitle: String {
        settingsModel.settings.defaultReclaimMode == .hardDelete
            ? "Permanently delete app?"
            : "Uninstall app?"
    }

    private var confirmationMessage: String {
        let count = 1 + model.selectedLeftovers.count
        let mode = settingsModel.settings.defaultReclaimMode == .hardDelete
            ? "deleted right away"
            : "moved to Trash"
        return "\(count) items will be \(mode). Running app will be asked to quit."
    }

    private var confirmationButtonTitle: String {
        settingsModel.settings.defaultReclaimMode == .hardDelete
            ? "Delete Permanently"
            : "Move to Trash"
    }

    private var confirmButtonBackground: some ShapeStyle {
        settingsModel.settings.defaultReclaimMode == .hardDelete
            ? AnyShapeStyle(Color.red.opacity(0.22))
            : AnyShapeStyle(Color.accentColor.opacity(0.2))
    }

    private func confirmUninstall() {
        showsConfirmation = false
        Task {
            await model.uninstallSelected()
        }
    }

    private func reportSummary(_ report: ReclaimReport) -> String {
        if report.failures.isEmpty {
            return "Reclaimed \(AppUninstallerFormatter.bytes(report.bytesReclaimed))."
        }
        return "Reclaimed \(AppUninstallerFormatter.bytes(report.bytesReclaimed)). \(report.failures.count) failed."
    }

    private func loadingRow(_ text: String) -> some View {
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

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FinderLinkLabel: View {
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

private struct AppUninstallerSettingsView: View {
    @ObservedObject var settings: SettingsModel<AppUninstallerSettings>

    var body: some View {
        SettingsSection("App Uninstaller") {
            Toggle(
                "Show possible name matches",
                isOn: $settings.settings.includeNameHeuristicMatches
            )

            Toggle(
                "Scan /Library paths",
                isOn: $settings.settings.includeSystemLibraryPaths
            )

            Picker("Default uninstall mode", selection: $settings.settings.defaultReclaimMode) {
                Text("Move to Trash").tag(ReclaimMode.moveToTrash)
                Text("Permanently delete").tag(ReclaimMode.hardDelete)
            }
            .pickerStyle(.radioGroup)

            if settings.settings.defaultReclaimMode == .hardDelete {
                Text("Items are removed right away. This cannot be undone.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
    }
}

private enum AppUninstallerFormatter {
    static func bytes(_ bytes: UInt64) -> String {
        if bytes == 0 {
            return "0 KB"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
