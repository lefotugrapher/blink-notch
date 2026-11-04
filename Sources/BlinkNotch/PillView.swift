import BlinkNotchCore
import SwiftUI

/// One reminder, drawn from the pure timeline in `PillAnimation`.
struct PillView: View {
    let geometry: PillGeometry
    let message: Message
    let startDate: Date
    /// Debug: render this one moment and hold it, for screenshots.
    var freezeAt: TimeInterval?

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: freezeAt != nil)) { context in
            let t = freezeAt ?? context.date.timeIntervalSince(startDate)
            let state = PillAnimation.state(at: t)
            let rect = geometry.shapeFrame(drop: state.drop, expansion: state.expansion)
            let pill = geometry.pillSize
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.black)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                content(state)
                    .frame(width: pill.width, height: pill.height, alignment: .leading)
                    .opacity(state.contentOpacity)
                    .offset(x: (geometry.windowSize.width - pill.width) / 2, y: rect.minY)
                    .mask(alignment: .topLeading) {
                        Capsule()
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    }
            }
            .frame(width: geometry.windowSize.width, height: geometry.windowSize.height, alignment: .topLeading)
        }
    }

    private func content(_ state: PillFrameState) -> some View {
        ZStack(alignment: .leading) {
            EyeAvatarView(state: state)
                .offset(x: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(MessagePool.kicker)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.secondaryText)
                Text(message.headline)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("from: \(message.from)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: geometry.pillSize.width - 70 - 14, alignment: .leading)
            .offset(x: 70)
        }
    }
}
