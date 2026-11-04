import CoreGraphics

/// Sizes and placement of the pill for one display.
///
/// The reminder is one rounded shape. It starts as a circle hidden behind the
/// notch (or under the menu bar), drops to a resting spot with a gap below it,
/// grows into a pill, shrinks back to a circle, and rises away.
public struct PillGeometry: Equatable, Sendable {
    public enum Style: Sendable { case notch, floating }

    /// Largest `drop` or `expansion` value; the window must fit the shape at this size.
    public static let maxProgress: Double = 1.12
    public static let circleDiameter: CGFloat = 44

    private static let pillHeight: CGFloat = 70
    private static let minimumPillWidth: CGFloat = 260
    private static let notchExtraWidth: CGFloat = 50
    private static let floatingPillWidth: CGFloat = 270
    private static let gapBelowNotch: CGFloat = 10
    private static let gapBelowMenuBar: CGFloat = 8

    public let style: Style
    /// The physical notch (zero when the display has none).
    public let notchSize: CGSize
    public let pillSize: CGSize
    /// Distance from the window top to the top of the resting shape.
    public let restTop: CGFloat
    public let windowSize: CGSize

    public init(display: DisplayInfo) {
        if let notch = display.notch {
            style = .notch
            notchSize = CGSize(width: notch.width, height: notch.height)
            pillSize = CGSize(width: max(Self.minimumPillWidth, notch.width + Self.notchExtraWidth),
                              height: Self.pillHeight)
            restTop = notch.height + Self.gapBelowNotch
        } else {
            style = .floating
            notchSize = .zero
            pillSize = CGSize(width: Self.floatingPillWidth, height: Self.pillHeight)
            restTop = Self.gapBelowMenuBar
        }
        let d = Self.circleDiameter
        let m = CGFloat(Self.maxProgress)
        // Widest and tallest the shape gets: the pill at maximum expansion, or the
        // circle at maximum drop overshoot.
        let circleBottom = restTop + m * (restTop + d)
        let pillBottom = restTop + d + (pillSize.height - d) * m
        windowSize = CGSize(width: (d + (pillSize.width - d) * m).rounded(.up),
                            height: max(circleBottom, pillBottom).rounded(.up))
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

    /// The shape's rectangle in window coordinates (origin top-left, y down).
    /// `drop` 0 is fully above the window (hidden), 1 is the resting spot.
    /// `expansion` 0 is the circle, 1 is the full pill; it grows from the top centre.
    public func shapeFrame(drop: Double, expansion: Double) -> CGRect {
        let d = Self.circleDiameter
        let e = CGFloat(expansion), p = CGFloat(drop)
        let width = d + (pillSize.width - d) * e
        let height = d + (pillSize.height - d) * e
        let hiddenTop = -d
        let top = hiddenTop + (restTop - hiddenTop) * p
        return CGRect(x: windowSize.width / 2 - width / 2, y: top, width: width, height: height)
    }
}
