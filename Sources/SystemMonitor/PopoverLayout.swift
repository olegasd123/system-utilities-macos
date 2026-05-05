import CoreGraphics

enum PopoverLayout {
    static let width: CGFloat = 450
    static let contentPadding: CGFloat = 12
    static let titleHeight: CGFloat = 18
    static let titleSpacing: CGFloat = 12
    static let metricCardHeight: CGFloat = 126
    static let rowSpacing: CGFloat = 8
    static let maximumHeight: CGFloat = 590

    static var contentSize: CGSize {
        CGSize(width: width, height: maximumHeight)
    }
}
