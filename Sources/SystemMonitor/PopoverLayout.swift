import CoreGraphics

enum PopoverLayout {
    static let width: CGFloat = 450
    static let contentPadding: CGFloat = 12
    static let titleHeight: CGFloat = 18
    static let titleSpacing: CGFloat = 12
    static let metricCardHeight: CGFloat = 126
    static let rowSpacing: CGFloat = 8
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
        let rowCount: CGFloat = hasBattery ? 4 : 3
        let totalRowSpacing = max(0, rowCount - 1) * rowSpacing

        return contentPadding * 2
            + titleHeight
            + titleSpacing
            + rowCount * metricCardHeight
            + totalRowSpacing
    }
}
