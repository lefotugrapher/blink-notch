import CoreGraphics
import Foundation

/// Everything the pill view needs to draw one frame.
public struct PillFrameState: Equatable, Sendable {
    /// 0 = collapsed into the notch (or hidden above the screen), 1 = settled.
    /// Briefly above 1 during the overshoot, never beyond `PillAnimation.maxProgress`.
    public let progress: Double
    public let contentOpacity: Double
    /// 0 = eyelid open, 1 = shut.
    public let lidClosure: Double
    /// Look direction, each component in -1...1.
    public let pupil: CGVector
    /// Squash and stretch around (1, 1).
    public let avatarScale: CGSize
    public let isFinished: Bool
}

/// The whole reminder as a pure function of time, so it is deterministic and testable.
/// Timings come from the approved mockup, shifted to start at t = 0; tune by eye.
public enum PillAnimation {
    public static let duration: TimeInterval = 6.0
    public static let maxProgress = PillGeometry.maxProgress

    public static func state(at time: TimeInterval) -> PillFrameState {
        let t = time.isNaN ? 0 : min(max(time, 0), duration)
        return PillFrameState(
            progress: progress.value(at: t),
            contentOpacity: content.value(at: t),
            lidClosure: lid.value(at: t),
            pupil: CGVector(dx: pupilX.value(at: t), dy: pupilY.value(at: t)),
            avatarScale: CGSize(width: squashX.value(at: t), height: squashY.value(at: t)),
            isFinished: t >= duration)
    }

    // MARK: Tracks

    private static let progress = Track([
        (0, 0), (0.55, 1.12), (0.8, 0.96), (1.0, 1.0), (5.0, 1.0), (5.9, 0), (6.0, 0),
    ])

    private static let content = Track([
        (0, 0), (0.6, 0), (1.05, 1), (4.9, 1), (5.25, 0), (6.0, 0),
    ])

    /// Three slams: the first two are quick, the third is held shut a beat longer.
    private static let lid = Track([
        (0, 0),
        (1.25, 0), (1.33, 1), (1.45, 1), (1.60, 0),
        (2.25, 0), (2.33, 1), (2.45, 1), (2.60, 0),
        (3.25, 0), (3.33, 1), (3.85, 1), (4.05, 0),
        (6.0, 0),
    ], easing: .linear)

    private static let pupilX = Track([
        (0, 0), (0.9, 0), (1.3, -1), (2.2, 1), (3.0, -0.4), (4.0, 0), (6.0, 0),
    ])
    private static let pupilY = Track([
        (0, 0), (0.9, 0), (1.3, 0.3), (2.2, -0.3), (3.0, 0.8), (4.0, 0), (6.0, 0),
    ])

    /// Squash (wide and short) as the lid lands, stretch (narrow and tall) as it recovers.
    private static let squashX = Track(slamKeys(close: 1.08, recover: 0.97))
    private static let squashY = Track(slamKeys(close: 0.88, recover: 1.04))

    private static func slamKeys(close: Double, recover: Double) -> [(Double, Double)] {
        var keys: [(Double, Double)] = [(0, 1)]
        for start in [1.25, 2.25, 3.25] {
            keys += [(start, 1), (start + 0.08, close), (start + 0.20, recover), (start + 0.35, 1)]
        }
        keys.append((6.0, 1))
        return keys
    }
}

/// Piecewise keyframe track; values hold before the first and after the last key.
private struct Track {
    enum Easing { case smooth, linear }

    private let keys: [(time: Double, value: Double)]
    private let easing: Easing

    init(_ keys: [(Double, Double)], easing: Easing = .smooth) {
        self.keys = keys.map { (time: $0.0, value: $0.1) }
        self.easing = easing
    }

    func value(at t: Double) -> Double {
        guard let first = keys.first, let last = keys.last else { return 0 }
        if t <= first.time { return first.value }
        if t >= last.time { return last.value }
        let i = keys.lastIndex { $0.time <= t }!
        let a = keys[i], b = keys[i + 1]
        let u = (t - a.time) / (b.time - a.time)
        let eased = easing == .smooth ? u * u * (3 - 2 * u) : u
        return a.value + (b.value - a.value) * eased
    }
}
