import AppCore
import SwiftUI

public struct MetricCardView: View {
    @Environment(\.appLocalization) private var localization
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

                Text(localization(label))
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
                MetricProgressBar(value: progress, accent: accent)
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

private struct MetricProgressBar: View {
    let value: Double
    let accent: Color

    private let height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let fraction = max(0, min(value, 100)) / 100
            let fillWidth = proxy.size.width * fraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.22))

                if fillWidth > 0 {
                    Capsule()
                        .fill(accent)
                        .frame(width: fillWidth)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
