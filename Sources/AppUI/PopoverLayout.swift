import CoreGraphics

public enum PopoverLayout {
    public static let width: CGFloat = 450
    public static let contentPadding: CGFloat = 12
    public static let titleHeight: CGFloat = 18
    public static let titleSpacing: CGFloat = 12
    public static let metricCardHeight: CGFloat = 126
    public static let rowSpacing: CGFloat = 8
    public static let maximumHeight: CGFloat = 582

    public static var contentSize: CGSize {
        CGSize(width: width, height: maximumHeight)
    }
}
