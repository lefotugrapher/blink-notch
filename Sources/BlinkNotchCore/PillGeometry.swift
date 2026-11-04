import CoreGraphics

/// Sizes and placement of the pill for one display.
public struct PillGeometry: Equatable, Sendable {
    public enum Style: Sendable { case notch, floating }

    /// Largest `PillFrameState.progress`; the window must fit the shape at this size.
    public static let maxProgress: Double = 1.12

    private static let bodyHeight: CGFloat = 70
    private static let minimumBodyWidth: CGFloat = 260
    private static let notchBodyExtraWidth: CGFloat = 50
    private static let floatingBodyWidth: CGFloat = 270
    private static let floatingTopInset: CGFloat = 8

    public let style: Style
    /// The notch-sized part that stays in the menu-bar band (zero when floating).
    public let neckSize: CGSize
    public let bodySize: CGSize
    /// Gap between the window top and the shape's resting top (floating only).
    public let topInset: CGFloat
    public let windowSize: CGSize

    public init(display: DisplayInfo) {
        if let notch = display.notch {
            style = .notch
            neckSize = CGSize(width: notch.width, height: notch.height)
            bodySize = CGSize(width: max(Self.minimumBodyWidth, notch.width + Self.notchBodyExtraWidth),
                              height: Self.bodyHeight)
            topInset = 0
        } else {
            style = .floating
            neckSize = .zero
            bodySize = CGSize(width: Self.floatingBodyWidth, height: Self.bodyHeight)
            topInset = Self.floatingTopInset
        }
        let factor = CGFloat(Self.maxProgress)
        windowSize = CGSize(width: (bodySize.width * factor).rounded(.up),
                            height: ((neckSize.height + bodySize.height + topInset) * factor).rounded(.up))
    }

    /// Window frame centred on the display. The top sits at the screen top for a
    /// notch display, and just below the menu bar for a floating one.
    public func windowFrame(on display: DisplayInfo) -> CGRect {
        let top = style == .notch ? display.frame.maxY : display.frame.maxY - display.menuBarHeight
        return CGRect(x: display.frame.midX - windowSize.width / 2,
                      y: top - windowSize.height,
                      width: windowSize.width,
                      height: windowSize.height)
    }
}
