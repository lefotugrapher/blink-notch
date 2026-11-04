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
}

/// The cartoon eye: white ball, looking pupil, and a coral eyelid that slams down.
struct EyeAvatarView: View {
    let state: PillFrameState

    private let diameter: CGFloat = 40
    private let pupilDiameter: CGFloat = 16
    private let rimHeight: CGFloat = 3

    var body: some View {
        let travel = (diameter - pupilDiameter) / 2 - 3
        let lidHeight = diameter + rimHeight
        ZStack {
            Circle().fill(.white)
            Circle().fill(Color(hex: 0x1A1A1A))
                .frame(width: pupilDiameter, height: pupilDiameter)
                .offset(x: state.pupil.dx * travel, y: state.pupil.dy * travel)
            VStack(spacing: 0) {
                Color.lid
                Color.lidRim.frame(height: rimHeight)
            }
            .frame(width: diameter, height: lidHeight)
            .offset(y: -lidHeight * (1 - CGFloat(state.lidClosure)))
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .scaleEffect(x: state.avatarScale.width, y: state.avatarScale.height, anchor: .bottom)
    }
}
