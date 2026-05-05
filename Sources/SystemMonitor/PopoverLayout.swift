import CoreGraphics

enum PopoverLayout {
    static let width: CGFloat = 450
    static let metricCardHeight: CGFloat = 126
    static let maximumHeight: CGFloat = 590

    static func contentSize(for route: PopoverRoute, hasBattery: Bool) -> CGSize {
        CGSize(width: width, height: height(for: route, hasBattery: hasBattery))
    }

    static func height(for route: PopoverRoute, hasBattery: Bool) -> CGFloat {
        switch route {
        case .dashboard:
            return dashboardHeight(hasBattery: hasBattery)
        case .settings:
            return maximumHeight
        }
    }

    private static func dashboardHeight(hasBattery: Bool) -> CGFloat {
        let padding: CGFloat = 24
        let titleHeight: CGFloat = 18
        let titleSpacing: CGFloat = 12
        let rowCount: CGFloat = hasBattery ? 4 : 3
        let rowSpacing = max(0, rowCount - 1) * 8

        return padding + titleHeight + titleSpacing + rowCount * metricCardHeight + rowSpacing
    }
}
