import BlinkNotchCore
import SwiftUI

/// Placeholder for Task 8: a black shape sized by the animation, to check motion
/// and window behaviour. Replaced by the real visuals in Task 9.
struct PillContent: View {
    let geometry: PillGeometry
    let startDate: Date

    var body: some View {
        TimelineView(.animation) { context in
            let state = PillAnimation.state(at: context.date.timeIntervalSince(startDate))
            let p = CGFloat(state.progress)
            let neck = geometry.neckSize, body = geometry.bodySize
            let width = geometry.style == .notch ? neck.width + (body.width - neck.width) * p : body.width
            let height = geometry.style == .notch ? neck.height + body.height * p : body.height
            let offsetY = geometry.style == .notch ? 0 : -(body.height + geometry.topInset) * (1 - p) + geometry.topInset
            Rectangle().fill(.black)
                .frame(width: width, height: height)
                .offset(y: offsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
