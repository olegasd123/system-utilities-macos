import SwiftUI

public struct MetricCardView: View {
    public let symbol: String
    public let label: String
    public let value: String
    public let subtitle: String
    public let accent: Color
    public var subtitleLineLimit: Int
    public var progress: Double?
    public var warning: Bool
    public var footer: AnyView?

    public init(
        symbol: String,
        label: String,
        value: String,
        subtitle: String,
        accent: Color,
        subtitleLineLimit: Int = 2,
        progress: Double? = nil,
        warning: Bool = false,
        footer: AnyView? = nil
    ) {
        self.symbol = symbol
        self.label = label
        self.value = value
        self.subtitle = subtitle
        self.accent = accent
        self.subtitleLineLimit = subtitleLineLimit
        self.progress = progress
        self.warning = warning
        self.footer = footer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
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
                .lineLimit(subtitleLineLimit)
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
