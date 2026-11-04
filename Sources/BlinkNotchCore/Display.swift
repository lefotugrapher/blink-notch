import CoreGraphics
import Foundation

public struct NotchSize: Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

public struct DisplayInfo: Equatable, Sendable {
    public var id: UInt32
    /// AppKit global coordinates (origin bottom-left).
    public var frame: CGRect
    public var menuBarHeight: CGFloat
    public var notch: NotchSize?

    public init(id: UInt32, frame: CGRect, menuBarHeight: CGFloat, notch: NotchSize?) {
        self.id = id
        self.frame = frame
        self.menuBarHeight = menuBarHeight
        self.notch = notch
    }
}

/// The display holding `cursor`. Edges are inclusive, because the cursor rests
/// exactly on a screen's top edge when reaching for the menu bar. When no display
/// contains the point, the nearest one wins.
public func pickDisplay(cursor: CGPoint, from displays: [DisplayInfo]) -> DisplayInfo? {
    if let hit = displays.first(where: { contains($0.frame, cursor) }) { return hit }
    return displays.min { distance(from: cursor, to: $0.frame) < distance(from: cursor, to: $1.frame) }
}

private func contains(_ rect: CGRect, _ p: CGPoint) -> Bool {
    p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
}

private func distance(from p: CGPoint, to rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
    let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
    return hypot(dx, dy)
}
