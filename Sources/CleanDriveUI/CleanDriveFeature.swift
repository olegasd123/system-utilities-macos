import AppCore
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
        AnyView(CleanDriveView(model: model))
    }

    public func makeSettingsSection() -> AnyView? {
        nil
    }
}

private struct CleanDriveView: View {
    @ObservedObject var model: CleanDriveModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summary
            categoryRow
            statusMessage
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await model.scan()
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(CleanDriveFormatter.bytes(model.userCaches.totalBytes))
                .font(.system(size: 36, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Ready for cleanup")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryRow: some View {
        HStack(spacing: 10) {
            Toggle(
                "",
                isOn: Binding(
                    get: { model.userCaches.isIncluded },
                    set: { model.setUserCachesIncluded($0) }
                )
            )
            .labelsHidden()
            .disabled(model.userCaches.isReclaiming)

            Image(systemName: model.userCaches.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.userCaches.displayName)
                    .font(.system(size: 14, weight: .medium))

                Text(rowSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if model.userCaches.isScanning {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(CleanDriveFormatter.bytes(model.userCaches.totalBytes))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(model.userCaches.totalBytes == 0 ? .secondary : .primary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let message = model.userCaches.errorMessage {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        } else if let report = model.userCaches.lastReclaimReport {
            Text(cleanupSummary(report))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else if model.userCaches.totalBytes == 0, !model.userCaches.isScanning {
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
            .disabled(model.userCaches.isScanning || model.userCaches.isReclaiming)

            Spacer()

            Button {
                Task {
                    await model.reclaimSelectedItems()
                }
            } label: {
                if model.userCaches.isReclaiming {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Text("Clean Up")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canReclaimSelectedItems)
        }
    }

    private var rowSubtitle: String {
        if model.userCaches.isScanning {
            return "Scanning"
        }
        if model.userCaches.items.isEmpty {
            return "No cache items found"
        }
        let count = model.userCaches.items.count
        return "\(count) \(count == 1 ? "item" : "items") found"
    }

    private func cleanupSummary(_ report: ReclaimReport) -> String {
        if report.failures.isEmpty {
            return "Moved \(CleanDriveFormatter.bytes(report.bytesReclaimed)) to Trash."
        }
        return "Moved \(CleanDriveFormatter.bytes(report.bytesReclaimed)) to Trash. \(report.failures.count) failed."
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
