import CoreGraphics
import Foundation

/// Everything the pill view needs to draw one frame.
public struct PillFrameState: Equatable, Sendable {
    /// 0 = hidden above the window (behind the notch), 1 = resting spot.
    /// Briefly above 1 during the overshoot, never beyond `PillAnimation.maxProgress`.
    public let drop: Double
    /// 0 = circle, 1 = full pill. Never changes while `drop` is moving (pill styles).
    public let expansion: Double
    public let contentOpacity: Double
    /// 0 = eyelid open, 1 = shut. For the shutter style this is the aperture closing.
    public let lidClosure: Double
    /// Second eye's lid (two-eyes style); lags `lidClosure`.
    public let secondLidClosure: Double
    /// Look direction, each component in -1...1.
    public let pupil: CGVector
    /// Squash and stretch around (1, 1).
    public let avatarScale: CGSize
    /// Style-specific. Sleepy: how far the Zs have floated (0...1). Countdown: coral flash.
    /// Buffering: spinner visibility. Wiper: wiper angle in -1...1.
    public let aux: Double
    /// Wiper: how clean the eye is (0 smudged, 1 clean).
    public let aux2: Double
    /// Countdown digit 3, 2 or 1; 0 means "now" (or not a countdown).
    public let counter: Int
    /// Which scripted headline to show (countdown and buffering switch to 1).
    public let headlinePhase: Int
    /// Bouncing eyeball: rotation in degrees.
    public let ballRotation: Double
    public let isFinished: Bool
}

/// The whole reminder as a pure function of time, so it is deterministic and testable.
/// Timings come from the approved mockups; tune by eye.
public enum PillAnimation {
    public static let duration: TimeInterval = 6.6
    public static let maxProgress = PillGeometry.maxProgress

    public static func state(at time: TimeInterval, style: BlinkStyle = .classic) -> PillFrameState {
        let t = time.isNaN ? 0 : min(max(time, 0), duration)
        let s = scripts[style]!
        return PillFrameState(
            drop: s.drop.value(at: t),
            expansion: s.expansion.value(at: t),
            contentOpacity: s.content.value(at: t),
            lidClosure: s.lid.value(at: t),
            secondLidClosure: style == .twoEyes ? s.lid.value(at: max(0, t - 0.3)) : 0,
            pupil: CGVector(dx: s.pupilX.value(at: t), dy: s.pupilY.value(at: t)),
            avatarScale: CGSize(width: s.squashX.value(at: t), height: s.squashY.value(at: t)),
            aux: s.aux.value(at: t),
            aux2: s.aux2.value(at: t),
            counter: style == .countdown ? (t < 1.9 ? 3 : t < 2.6 ? 2 : t < 3.3 ? 1 : 0) : 0,
            headlinePhase: s.headlineSwitch.map { t >= $0 ? 1 : 0 } ?? 0,
            ballRotation: s.rotation.value(at: t),
            isFinished: t >= duration)
    }

    // MARK: Scripts

    private struct Script {
        var drop: Track, expansion: Track, content: Track, lid: Track
        var pupilX: Track, pupilY: Track, squashX: Track, squashY: Track
        var aux: Track = .constant(0), aux2: Track = .constant(0), rotation: Track = .constant(0)
        var headlineSwitch: Double?
    }

    private static let scripts: [BlinkStyle: Script] = Dictionary(
        uniqueKeysWithValues: BlinkStyle.allCases.map { ($0, makeScript($0)) })

    private static func makeScript(_ style: BlinkStyle) -> Script {
        let end = duration
        let pupilX = Track([(0, 0), (0.9, 0), (1.3, -1), (2.2, 1), (3.0, -0.4), (4.0, 0), (end, 0)])
        let pupilY = Track([(0, 0), (0.9, 0), (1.3, 0.3), (2.2, -0.3), (3.0, 0.8), (4.0, 0), (end, 0)])
        let slams = [1.25, 2.25, 3.25]
        let classicLid = Track(slamLid(slams, holdLast: 0.52), easing: .linear)

        // Circle drops out of the notch, rests, and rises back at the very end.
        var script = Script(
            drop: Track([(0, 0), (0.35, 1.12), (0.5, 1.0), (5.9, 1.0), (6.4, 0), (end, 0)]),
            // Grows into the pill once landed; a circle again, held 0.3 s, before rising.
            expansion: Track([(0, 0), (0.5, 0), (0.85, 1.08), (1.1, 1.0), (5.0, 1.0), (5.6, 0), (end, 0)]),
            content: Track([(0, 0), (0.85, 0), (1.15, 1), (4.9, 1), (5.2, 0), (end, 0)]),
            lid: classicLid, pupilX: pupilX, pupilY: pupilY,
            squashX: Track(slamSquash(slams, close: 1.08, recover: 0.97)),
            squashY: Track(slamSquash(slams, close: 0.88, recover: 1.04)))

        switch style {
        case .classic, .pillEye, .lashes, .twoEyes, .shutter:
            break
        case .slowCat:
            script.lid = Track([(0, 0), (1.25, 0), (1.75, 1), (2.3, 1), (2.8, 0), (3.4, 0), (3.9, 1), (4.3, 1), (4.8, 0), (end, 0)])
            script.squashX = .constant(1); script.squashY = .constant(1)
        case .sleepy:
            script.lid = Track([(0, 0), (1.2, 0), (1.7, 0.45), (2.1, 0.78), (2.45, 0.95), (2.5, 0),
                                (2.9, 0), (2.98, 1), (3.1, 1), (3.25, 0), (3.6, 0), (3.68, 1), (4.2, 1), (4.4, 0), (end, 0)])
            script.aux = Track([(0, 0), (1.2, 0), (2.45, 1), (2.5, 0), (end, 0)])
            script.squashX = Track(slamSquash([2.9, 3.6], close: 1.08, recover: 0.97))
            script.squashY = Track(slamSquash([2.9, 3.6], close: 0.88, recover: 1.04))
        case .countdown:
            script.lid = .constant(0)
            script.aux = Track([(0, 0), (3.3, 0), (3.34, 1), (3.8, 1), (4.4, 0), (end, 0)])
            script.squashX = .constant(1); script.squashY = .constant(1)
            script.headlineSwitch = 3.3
        case .wiper:
            script.lid = .constant(0)
            var angle: [(Double, Double)] = [(0, -1)]
            for start in slams { angle += [(start, -1), (start + 0.2, 1), (start + 0.4, -1)] }
            angle.append((end, -1))
            script.aux = Track(angle)
            script.aux2 = Track([(0, 0), (1.25, 0), (1.45, 0.3), (2.45, 0.65), (3.45, 1), (end, 1)])
            script.squashX = .constant(1); script.squashY = .constant(1)
        case .buffering:
            script.aux = Track([(0, 0), (1.0, 0), (1.15, 1), (3.4, 1), (3.55, 0), (end, 0)])
            script.headlineSwitch = 3.6
        case .bouncingEyeball:
            script.drop = Track([(0, 0), (0.45, 1.0), (0.75, 0.5), (1.05, 1.0), (1.25, 0.8), (1.45, 1.0),
                                 (5.7, 1.0), (6.3, 0), (end, 0)])
            script.expansion = .constant(0)
            script.content = Track([(0, 0), (1.3, 0), (1.7, 1), (5.0, 1), (5.4, 0), (end, 0)])
            script.lid = Track([(0, 0), (1.8, 0), (1.88, 1), (2.0, 1), (2.15, 0), (2.8, 0), (2.88, 1), (3.0, 1), (3.15, 0),
                                (3.8, 0), (3.88, 1), (4.35, 1), (4.55, 0), (end, 0)], easing: .linear)
            script.pupilX = Track([(0, 0), (1.5, 0), (1.9, -1), (2.7, 1), (3.5, -0.3), (4.4, 0), (end, 0)])
            script.pupilY = Track([(0, 0), (1.5, 0), (1.9, 0.3), (2.7, -0.3), (3.5, 0.6), (4.4, 0), (end, 0)])
            script.rotation = Track([(0, -200), (0.45, 0), (5.7, 0), (6.3, 240), (end, 240)])
            // Squash on each landing.
            script.squashX = Track([(0, 1), (0.4, 1), (0.45, 1.14), (0.55, 1), (1.0, 1), (1.05, 1.09), (1.15, 1),
                                    (1.4, 1), (1.45, 1.05), (1.55, 1), (end, 1)])
            script.squashY = Track([(0, 1), (0.4, 1), (0.45, 0.86), (0.55, 1), (1.0, 1), (1.05, 0.91), (1.15, 1),
                                    (1.4, 1), (1.45, 0.95), (1.55, 1), (end, 1)])
        }
        return script
    }

    /// Quick slams (close in 0.08 s, held 0.12 s, open by 0.35 s); the last is held longer.
    private static func slamLid(_ starts: [Double], holdLast: Double) -> [(Double, Double)] {
        var keys: [(Double, Double)] = [(0, 0)]
        for (i, start) in starts.enumerated() {
            let hold = i == starts.count - 1 ? holdLast : 0.12
            keys += [(start, 0), (start + 0.08, 1), (start + 0.08 + hold, 1), (start + 0.08 + hold + 0.15, 0)]
        }
        keys.append((duration, 0))
        return keys
    }

    /// Squash (wide and short) as the lid lands, stretch (narrow and tall) as it recovers.
    private static func slamSquash(_ starts: [Double], close: Double, recover: Double) -> [(Double, Double)] {
        var keys: [(Double, Double)] = [(0, 1)]
        for start in starts {
            keys += [(start, 1), (start + 0.08, close), (start + 0.20, recover), (start + 0.35, 1)]
        }
        keys.append((duration, 1))
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

    static func constant(_ value: Double) -> Track { Track([(0, value)]) }

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
