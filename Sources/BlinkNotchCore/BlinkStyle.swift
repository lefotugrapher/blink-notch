import Foundation

/// The look of one blink reminder. Each reminder uses a different style from the last.
public enum BlinkStyle: String, CaseIterable, Sendable {
    case classic          // the original: eye avatar with a coral lid that slams
    case pillEye          // the whole pill is a white eye
    case lashes           // eye with fluttering lashes
    case slowCat          // green slit-pupil eye, two slow blinks
    case twoEyes          // two small eyes with eyebrows, blinking in turn
    case countdown        // 3, 2, 1, then a flash
    case wiper            // a windshield wiper cleans the eye
    case shutter          // a camera shutter closes over the eye
    case sleepy           // a drooping eye with Zs that snaps awake
    case buffering        // the pupil is a loading spinner
    case bouncingEyeball  // no pill: a big eyeball bounces out of the notch

    /// Headlines that replace the random message for styles whose joke needs fixed text.
    /// Styles with two entries switch to the second at `PillFrameState.headlinePhase == 1`.
    public var scriptedHeadlines: [String]? {
        switch self {
        case .slowCat: return ["Slow-blink at me."]
        case .countdown: return ["Ready to blink?", "BLINK NOW!"]
        case .wiper: return ["Wipers on."]
        case .shutter: return ["Click. Blink captured."]
        case .sleepy: return ["Wake up. Blink."]
        case .buffering: return ["Buffering…", "Reloaded."]
        default: return nil
        }
    }

    public var scriptedFrom: String? {
        switch self {
        case .slowCat: return "your cat (and your eyes)"
        case .countdown, .buffering: return "your eyeballs"
        case .wiper: return "your windshield (eyes)"
        case .shutter: return "your eyes' camera roll"
        case .sleepy: return "your eyelids (asleep)"
        default: return nil
        }
    }
}

/// Picks the next style at random, never the same as the one before.
public struct BlinkStylePicker {
    private let styles: [BlinkStyle]
    private var last: BlinkStyle?

    public init(styles: [BlinkStyle] = BlinkStyle.allCases) {
        precondition(!styles.isEmpty, "BlinkStylePicker needs at least one style")
        self.styles = styles
    }

    public mutating func next() -> BlinkStyle {
        var generator = SystemRandomNumberGenerator()
        return next(using: &generator)
    }

    public mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> BlinkStyle {
        let candidates = styles.filter { $0 != last }
        let pick = (candidates.isEmpty ? styles : candidates).randomElement(using: &generator)!
        last = pick
        return pick
    }
}
