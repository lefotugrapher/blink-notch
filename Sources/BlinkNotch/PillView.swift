import BlinkNotchCore
import SwiftUI

/// One reminder, drawn from the pure timeline in `PillAnimation`.
struct PillView: View {
    let geometry: PillGeometry
    let message: Message
    let style: BlinkStyle
    let startDate: Date
    /// Debug: render this one moment and hold it, for screenshots.
    var freezeAt: TimeInterval?

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: freezeAt != nil)) { context in
            let t = freezeAt ?? context.date.timeIntervalSince(startDate)
            let state = PillAnimation.state(at: t, style: style)
            Group {
                if style == .bouncingEyeball {
                    bouncingEyeball(state)
                } else {
                    pill(state, time: t)
                }
            }
            .frame(width: geometry.windowSize.width, height: geometry.windowSize.height, alignment: .topLeading)
        }
    }

    // MARK: Text

    private func headline(_ state: PillFrameState) -> String {
        guard let scripted = style.scriptedHeadlines else { return message.headline }
        return scripted[min(state.headlinePhase, scripted.count - 1)]
    }

    private var fromLine: String { "from: \(style.scriptedFrom ?? message.from)" }

    // MARK: Pill styles

    private func pill(_ state: PillFrameState, time: TimeInterval) -> some View {
        let rect = geometry.shapeFrame(drop: state.drop, expansion: state.expansion)
        let pillSize = geometry.pillSize
        let fill: Color = style == .pillEye ? .white : .black
        return ZStack(alignment: .topLeading) {
            Capsule().fill(fill)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
            if style == .countdown {
                Capsule().fill(Color.lid.opacity(state.aux))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
            pillContent(state, time: time)
                .frame(width: pillSize.width, height: pillSize.height, alignment: .leading)
                .opacity(state.contentOpacity)
                .offset(x: (geometry.windowSize.width - pillSize.width) / 2, y: rect.minY)
                .mask(alignment: .topLeading) {
                    Capsule()
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
        }
    }

    @ViewBuilder private func pillContent(_ state: PillFrameState, time: TimeInterval) -> some View {
        let pillSize = geometry.pillSize
        if style == .pillEye {
            ZStack(alignment: .leading) {
                texts(state, dark: true).frame(width: pillSize.width - 100, alignment: .leading).offset(x: 22)
                ZStack {
                    Circle().fill(Color(hex: 0x3B82F6))
                    Circle().fill(Color.ink).frame(width: 30, height: 30)
                    Circle().fill(.white).frame(width: 9, height: 9).offset(x: -7, y: -7)
                }
                .frame(width: 52, height: 52)
                .offset(x: pillSize.width - 14 - 52 + state.pupil.dx * 14)
                LidSlab(closure: state.lidClosure, size: pillSize, rimHeight: 5)
            }
        } else {
            ZStack(alignment: .leading) {
                EyeAvatarView(style: style, state: state, time: time).offset(x: 16)
                texts(state, dark: false).frame(width: pillSize.width - 70 - 14, alignment: .leading).offset(x: 70)
            }
        }
    }

    private func texts(_ state: PillFrameState, dark: Bool) -> some View {
        // Secondary text turns white while the countdown flashes the pill coral.
        let secondary: Color = dark ? Color(hex: 0x7A7A80) : Color(white: 0.56 + 0.44 * state.aux * (style == .countdown ? 1 : 0))
        return VStack(alignment: .leading, spacing: 2) {
            Text(MessagePool.kicker)
                .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                .foregroundStyle(secondary)
            Text(headline(state))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(dark ? Color.ink : .white)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(fromLine)
                .font(.system(size: 11))
                .foregroundStyle(secondary)
                .lineLimit(1)
        }
    }

    // MARK: Bouncing eyeball (no pill)

    private func bouncingEyeball(_ state: PillFrameState) -> some View {
        let ball = geometry.ballFrame(drop: state.drop)
        let d = PillGeometry.ballDiameter
        let cap = PillGeometry.captionSize
        return ZStack(alignment: .topLeading) {
            ZStack {
                Circle().fill(.white)
                Circle().fill(Color.ink).frame(width: 32, height: 32)
                    .overlay(Circle().fill(.white).frame(width: 9, height: 9).offset(x: -6, y: -6))
                    .offset(x: state.pupil.dx * 24, y: state.pupil.dy * 20)
                LidSlab(closure: state.lidClosure, size: CGSize(width: d, height: d), rimHeight: 5)
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.4), radius: 9, y: 6)
            .scaleEffect(x: state.avatarScale.width, y: state.avatarScale.height, anchor: .bottom)
            .rotationEffect(.degrees(state.ballRotation))
            .offset(x: ball.minX, y: ball.minY)

            ZStack {
                Capsule().fill(Color.black)
                texts(state, dark: false).multilineTextAlignment(.center)
            }
            .frame(width: cap.width, height: cap.height)
            .opacity(state.contentOpacity)
            .offset(x: (geometry.windowSize.width - cap.width) / 2,
                    y: geometry.captionTop + 10 * (1 - state.contentOpacity))
        }
    }
}
