import SwiftUI

struct DashboardView: View {
    let settings: Settings
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("System Monitor")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 8) {
                MetricCardView(
                    symbol: "cpu",
                    label: "CPU LOAD",
                    value: "--%",
                    subtitle: "Waiting for samples",
                    accent: .blue,
                    progress: 0
                )

                MetricCardView(
                    symbol: "memorychip",
                    label: "MEMORY",
                    value: "--%",
                    subtitle: "Waiting for samples",
                    accent: .green,
                    progress: 0
                )

                MetricCardView(
                    symbol: "internaldrive",
                    label: "DISK",
                    value: "--% free",
                    subtitle: "Waiting for samples",
                    accent: .cyan,
                    progress: 0
                )

                MetricCardView(
                    symbol: "network",
                    label: "NETWORK",
                    value: "↓ -- B/s",
                    subtitle: "↑ -- B/s",
                    accent: .orange
                )

                MetricCardView(
                    symbol: "thermometer",
                    label: "SENSORS",
                    value: "-- active",
                    subtitle: "Waiting for samples",
                    accent: .yellow
                )

                MetricCardView(
                    symbol: "fan",
                    label: "FANS",
                    value: "No fan data",
                    subtitle: "Unavailable",
                    accent: .yellow
                )

                MetricCardView(
                    symbol: "battery.100",
                    label: "BATTERY",
                    value: "--%",
                    subtitle: "Waiting for samples",
                    accent: .green,
                    progress: 0
                )
                .gridCellColumns(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }
}
