import AppCore
import AppUninstallerCore
import SwiftUI

struct AppUninstallerLeftoverPane: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject var model: AppUninstallerModel
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header(model.scanResult)

            if isExpanded {
                content
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func header(_ result: LeftoverScanResult?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14, height: 14)

                Text(localization("Leftovers"))
                    .font(.system(size: 12, weight: .semibold))

                if showsScanProgress {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                }

                Text(headerSubtitle(result))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let result {
                    Text(AppUninstallerFormatter.bytes(leftoverBytes(result)))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(localization(isExpanded ? "Hide leftovers" : "Show leftovers"))
    }

    @ViewBuilder
    private var content: some View {
        if let result = model.scanResult {
            if result.leftovers.isEmpty {
                AppUninstallerEmptyRow(text: localization("No leftovers found."))
            } else {
                leftoverList(result)
            }
        } else {
            AppUninstallerLoadingRow(text: localization("Scanning leftovers..."))
        }
    }

    private var showsScanProgress: Bool {
        model.isScanningLeftovers || (model.selectedApp != nil && model.scanResult == nil)
    }

    private func headerSubtitle(_ result: LeftoverScanResult?) -> String {
        if showsScanProgress {
            return localization("Scanning")
        }
        guard let result else {
            return localization("Not scanned")
        }
        return localization("%d found", result.leftovers.count)
    }

    private func leftoverList(_ result: LeftoverScanResult) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 7) {
                candidateGroup(localization("Exact match"), candidates: group(.exactBundleID, in: result))
                candidateGroup(localization("Related"), candidates: group(.bundleIDPrefix, in: result))
                candidateGroup(localization("Possible"), candidates: group(.nameHeuristic, in: result))
                candidateGroup(localization("User folder"), candidates: group(.userHome, in: result))

                ForEach(result.notes, id: \.self) { note in
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
    }

    private func leftoverBytes(_ result: LeftoverScanResult) -> UInt64 {
        result.leftovers.reduce(0) { $0 + $1.size }
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
}
