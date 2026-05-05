import SwiftUI

struct MetricCardView: View {
    let symbol: String
    let label: String
    let value: String
    let subtitle: String
    let accent: Color
    var progress: Double?
    var warning = false
    var footer: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
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
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 0)

            if let progress {
                ProgressView(value: max(0, min(progress, 100)), total: 100)
                    .tint(accent)
                    .controlSize(.small)
            }

            footer
        }
        .padding(13)
        .frame(
            maxWidth: .infinity,
            minHeight: PopoverLayout.metricCardHeight,
            maxHeight: PopoverLayout.metricCardHeight,
            alignment: .topLeading
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(warning ? .orange : .secondary.opacity(0.22), lineWidth: 1)
        }
    }
}
