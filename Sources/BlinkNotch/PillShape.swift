import BlinkNotchCore
import SwiftUI

extension PillGeometry {
    /// Top edge of the body for the floating style: hidden above the window at
    /// progress 0, resting `topInset` below the window top at progress 1.
    func floatingTop(progress: Double) -> CGFloat {
        -(bodySize.height + topInset) * (1 - CGFloat(progress)) + topInset
    }
}

/// The black silhouette for one frame. Notch style: a notch-wide neck flush with
/// the screen top (so it never covers menu bar items) and a wider body hanging
/// below it, joined by small concave fillets. Floating style: a rounded body.
struct PillShape: Shape {
    let geometry: PillGeometry
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let p = CGFloat(progress)
        let body = geometry.bodySize
        let cx = rect.midX

        if geometry.style == .floating {
            let top = geometry.floatingTop(progress: progress)
            let frame = CGRect(x: cx - body.width / 2, y: top, width: body.width, height: body.height)
            return Path(roundedRect: frame, cornerRadius: min(26, body.height / 2), style: .continuous)
        }

        let neckW = geometry.neckSize.width, yN = geometry.neckSize.height
        let bodyW = neckW + (body.width - neckW) * p
        let bodyH = body.height * p
        let yB = yN + bodyH
        let nL = cx - neckW / 2, nR = cx + neckW / 2
        let bL = cx - bodyW / 2, bR = cx + bodyW / 2

        // Radii shrink with the body so the first frames are a clean notch.
        let gap = (bodyW - neckW) / 2
        let f = max(0, min(10, gap / 2))
        let rt = max(0, min(14, gap - f, bodyH / 2))
        let r = max(0, min(26, bodyH / 2, bodyW / 2))

        var path = Path()
        path.move(to: CGPoint(x: nL, y: 0))
        path.addLine(to: CGPoint(x: nR, y: 0))
        path.addLine(to: CGPoint(x: nR, y: yN - f))
        path.addQuadCurve(to: CGPoint(x: nR + f, y: yN), control: CGPoint(x: nR, y: yN))
        path.addLine(to: CGPoint(x: bR - rt, y: yN))
        path.addQuadCurve(to: CGPoint(x: bR, y: yN + rt), control: CGPoint(x: bR, y: yN))
        path.addLine(to: CGPoint(x: bR, y: yB - r))
        path.addQuadCurve(to: CGPoint(x: bR - r, y: yB), control: CGPoint(x: bR, y: yB))
        path.addLine(to: CGPoint(x: bL + r, y: yB))
        path.addQuadCurve(to: CGPoint(x: bL, y: yB - r), control: CGPoint(x: bL, y: yB))
        path.addLine(to: CGPoint(x: bL, y: yN + rt))
        path.addQuadCurve(to: CGPoint(x: bL + rt, y: yN), control: CGPoint(x: bL, y: yN))
        path.addLine(to: CGPoint(x: nL - f, y: yN))
        path.addQuadCurve(to: CGPoint(x: nL, y: yN - f), control: CGPoint(x: nL, y: yN))
        path.closeSubpath()
        return path
    }
}
