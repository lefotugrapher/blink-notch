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
            let shape = PillShape(geometry: geometry, progress: state.progress)
            ZStack(alignment: .topLeading) {
                shape.fill(Color.black)
                content(state)
                    .frame(width: geometry.bodySize.width, height: geometry.bodySize.height, alignment: .leading)
                    .opacity(state.contentOpacity)
                    .offset(x: (geometry.windowSize.width - geometry.bodySize.width) / 2,
                            y: bodyTop(state))
                    .clipShape(shape)
            }
            .frame(width: geometry.windowSize.width, height: geometry.windowSize.height, alignment: .topLeading)
        }
    }

    private func bodyTop(_ state: PillFrameState) -> CGFloat {
        geometry.style == .notch ? geometry.neckSize.height : geometry.floatingTop(progress: state.progress)
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
            .frame(width: geometry.bodySize.width - 70 - 14, alignment: .leading)
            .offset(x: 70)
        }
    }
}
