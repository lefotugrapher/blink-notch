import BlinkNotchCore
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let lid = Color(hex: 0xFF5A5F)
    static let lidRim = Color(hex: 0xB3262B)
    static let secondaryText = Color(hex: 0x8E8E93)
    static let ink = Color(hex: 0x1A1A1A)
}

/// A slab that slides down over a rectangle: closure 0 is hidden above, 1 covers it.
struct LidSlab: View {
    let closure: Double
    let size: CGSize
    var color = Color.lid
    var rim = Color.lidRim
    var rimHeight: CGFloat = 3

    var body: some View {
        let height = size.height + rimHeight
        VStack(spacing: 0) {
            color
            rim.frame(height: rimHeight)
        }
        .frame(width: size.width, height: height)
        .offset(y: -height * (1 - CGFloat(closure)))
    }
}

/// The 40 pt avatar on the left of the pill, drawn per style.
struct EyeAvatarView: View {
    let style: BlinkStyle
    let state: PillFrameState
    /// Seconds since the animation started, for continuous motion (the spinner).
    let time: TimeInterval

    private let diameter: CGFloat = 40

    var body: some View {
        Group {
            switch style {
            case .twoEyes: twoEyes
            case .countdown: countdown
            default: singleEye
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(x: state.avatarScale.width, y: state.avatarScale.height, anchor: .bottom)
    }

    // MARK: Single eye (classic, lashes, slowCat, wiper, shutter, sleepy, buffering)

    private var singleEye: some View {
        let travel = (diameter - 16) / 2 - 3
        return ZStack {
            Circle().fill(style == .slowCat ? Color(hex: 0xD8EC6A) : .white)
            pupil(travel: travel)
            if style == .wiper {
                Color.gray.opacity(0.45 * (1 - state.aux2))
                Rectangle().fill(Color.black).frame(width: 3, height: 44)
                    .rotationEffect(.degrees(state.aux * 62), anchor: .bottom)
                    .offset(y: -2)
            }
            if style == .shutter {
                Circle()
                    .fill(AngularGradient(colors: [Color(hex: 0x202020), Color(hex: 0x363636), Color(hex: 0x202020),
                                                   Color(hex: 0x363636), Color(hex: 0x202020), Color(hex: 0x363636),
                                                   Color(hex: 0x202020)], center: .center))
                    .scaleEffect(state.lidClosure * 1.1)
                    .rotationEffect(.degrees(90 - 40 * state.lidClosure))
            }
            lid
        }
        .clipShape(Circle())
        .overlay(style == .shutter ? Circle().stroke(Color(hex: 0x555555), lineWidth: 3) : nil)
        .overlay(alignment: .center) { if style == .lashes { lashes } }
        .overlay(alignment: .center) { if style == .sleepy { zzz } }
    }

    @ViewBuilder private func pupil(travel: CGFloat) -> some View {
        switch style {
        case .slowCat:
            Capsule().fill(Color.black).frame(width: 6, height: 28)
                .offset(x: state.pupil.dx * 2)
        case .buffering:
            ZStack {
                Circle().fill(Color.ink).frame(width: 16, height: 16)
                    .opacity(1 - state.aux)
                    .offset(x: state.pupil.dx * travel, y: state.pupil.dy * travel)
                Circle().stroke(Color.black.opacity(0.15), lineWidth: 3).frame(width: 18, height: 18)
                    .opacity(state.aux)
                Circle().trim(from: 0, to: 0.28).stroke(Color.black, lineWidth: 3).frame(width: 18, height: 18)
                    .rotationEffect(.degrees(time * 450))
                    .opacity(state.aux)
            }
        default:
            Circle().fill(Color.ink).frame(width: 16, height: 16)
                .offset(x: state.pupil.dx * travel, y: state.pupil.dy * travel)
        }
    }

    @ViewBuilder private var lid: some View {
        let size = CGSize(width: diameter, height: diameter)
        switch style {
        case .slowCat:
            LidSlab(closure: state.lidClosure, size: size, color: Color(hex: 0x6B4F2A), rim: Color(hex: 0x3E2C14))
        case .sleepy:
            LidSlab(closure: state.lidClosure, size: size, color: Color(hex: 0x7D6BB8), rim: Color(hex: 0x4B3D85))
        case .wiper, .shutter:
            EmptyView()
        default:
            LidSlab(closure: state.lidClosure, size: size)
        }
    }

    private var lashes: some View {
        ZStack {
            ForEach([-50.0, -25.0, 0.0, 25.0, 50.0], id: \.self) { angle in
                ZStack {
                    Capsule().fill(Color.white)
                        .frame(width: 2, height: 9 * (1 + 0.7 * state.lidClosure))
                        .offset(y: -(diameter / 2 + 4))
                }
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
            }
        }
    }

    private var zzz: some View {
        let a = state.aux
        return ZStack {
            Text("z").font(.system(size: 11, weight: .heavy)).offset(x: 16 + a * 6, y: -14 - a * 6)
            Text("Z").font(.system(size: 13, weight: .heavy)).offset(x: 22 + a * 5, y: -20 - a * 7)
        }
        .foregroundStyle(Color(hex: 0xB9A8FF))
        .opacity(sin(.pi * a))
    }

    // MARK: Two little eyes

    private var twoEyes: some View {
        HStack(spacing: 4) {
            smallEye(closure: state.lidClosure)
            smallEye(closure: state.secondLidClosure)
        }
        .overlay(alignment: .top) {
            HStack(spacing: 6) {
                Capsule().frame(width: 14, height: 3).rotationEffect(.degrees(-8))
                Capsule().frame(width: 14, height: 3).rotationEffect(.degrees(8))
            }
            .foregroundStyle(.white)
            .offset(y: -9 - 3 * max(state.lidClosure, state.secondLidClosure))
        }
    }

    private func smallEye(closure: Double) -> some View {
        ZStack {
            Circle().fill(.white)
            Circle().fill(Color.ink).frame(width: 7, height: 7)
                .offset(x: state.pupil.dx * 3, y: state.pupil.dy * 3)
            LidSlab(closure: closure, size: CGSize(width: 17, height: 17), rimHeight: 2)
        }
        .frame(width: 17, height: 17)
        .clipShape(Circle())
    }

    // MARK: Countdown

    @ViewBuilder private var countdown: some View {
        if state.counter > 0 {
            ZStack {
                Circle().strokeBorder(Color.white, lineWidth: 3)
                Text("\(state.counter)").font(.system(size: 20, weight: .heavy)).foregroundStyle(.white)
            }
        } else {
            // A closed eye: one thick downward arc.
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 24, y: 0), control: CGPoint(x: 12, y: 16))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .frame(width: 24, height: 10)
        }
    }
}
