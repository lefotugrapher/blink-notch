import CoreGraphics
import Testing
@testable import BlinkNotchCore

@Suite struct PillAnimationTests {
    private let samples = stride(from: 0.0, through: 6.0, by: 0.01).map { $0 }

    @Test func startsCollapsedAndInvisible() {
        let s = PillAnimation.state(at: 0)
        #expect(s.progress == 0)
        #expect(s.contentOpacity == 0)
        #expect(s.lidClosure == 0)
        #expect(!s.isFinished)
    }

    @Test func overshootsThenSettles() {
        let peak = PillAnimation.state(at: 0.55).progress
        #expect(peak > 1.0 && peak <= PillAnimation.maxProgress)
        #expect(abs(PillAnimation.state(at: 1.0).progress - 1) < 0.001)
    }

    @Test func lidShutAtEachSlam() {
        for t in [1.39, 2.39, 3.6] { #expect(PillAnimation.state(at: t).lidClosure == 1) }
        for t in [1.0, 2.9] { #expect(PillAnimation.state(at: t).lidClosure == 0) }
    }

    @Test func avatarSquashesOnSlamAndRestsOtherwise() {
        #expect(PillAnimation.state(at: 1.33).avatarScale.height < 0.95)
        #expect(PillAnimation.state(at: 2.0).avatarScale == CGSize(width: 1, height: 1))
    }

    @Test func contentIsFullyVisibleWhileSettled() {
        #expect(PillAnimation.state(at: 3.0).contentOpacity == 1)
    }

    @Test func finishesAtDuration() {
        let s = PillAnimation.state(at: 6.0)
        #expect(s.isFinished)
        #expect(s.progress == 0)
        #expect(s.contentOpacity == 0)
    }

    @Test func clampsOutOfRangeAndNaN() {
        #expect(PillAnimation.state(at: -3) == PillAnimation.state(at: 0))
        #expect(PillAnimation.state(at: 600) == PillAnimation.state(at: 6.0))
        #expect(PillAnimation.state(at: .nan) == PillAnimation.state(at: 0))
    }

    @Test func neverExceedsMaxProgressOrGoesNegative() {
        for t in samples {
            let p = PillAnimation.state(at: t).progress
            #expect(p >= 0 && p <= PillAnimation.maxProgress)
        }
    }

    @Test func pupilStaysWithinUnitRange() {
        for t in samples {
            let p = PillAnimation.state(at: t).pupil
            #expect(abs(p.dx) <= 1 && abs(p.dy) <= 1)
        }
    }

    @Test func lidOnlyMovesWhileContentIsVisible() {
        for t in samples {
            let s = PillAnimation.state(at: t)
            if s.lidClosure > 0 { #expect(s.contentOpacity > 0.9) }
        }
    }

    @Test func noPopping() {
        var previous = PillAnimation.state(at: 0)
        for t in samples.dropFirst() {
            let s = PillAnimation.state(at: t)
            #expect(abs(s.progress - previous.progress) < 0.2)
            #expect(abs(s.lidClosure - previous.lidClosure) < 0.6)
            previous = s
        }
    }
}
