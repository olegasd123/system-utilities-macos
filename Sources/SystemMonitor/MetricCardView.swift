import SwiftUI

struct MetricCardView: View {
    let symbol: String
    let label: String
    let value: String
    let subtitle: String
    let accent: Color
    var progress: Double?
    var warning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if warning {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .monospacedDigit()

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let progress {
                ProgressView(value: max(0, min(progress, 100)), total: 100)
                    .tint(accent)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(warning ? .orange : .secondary.opacity(0.22), lineWidth: 1)
        }
    }
}
