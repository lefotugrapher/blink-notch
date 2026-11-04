import CoreGraphics
import Testing
@testable import BlinkNotchCore

@Suite struct PillAnimationTests {
    private let samples = stride(from: 0.0, through: PillAnimation.duration, by: 0.01).map { $0 }

    @Test func startsHiddenAsACircle() {
        let s = PillAnimation.state(at: 0)
        #expect(s.drop == 0)
        #expect(s.expansion == 0)
        #expect(s.contentOpacity == 0)
        #expect(s.lidClosure == 0)
        #expect(!s.isFinished)
    }

    @Test func dropsOvershootsThenSettlesBeforeExpanding() {
        let peak = PillAnimation.state(at: 0.35).drop
        #expect(peak > 1.0 && peak <= PillAnimation.maxProgress)
        let arrived = PillAnimation.state(at: 0.5)
        #expect(abs(arrived.drop - 1) < 0.001)
        #expect(arrived.expansion == 0)
    }

    @Test func expandsToAPillWithASlightOvershoot() {
        let peak = PillAnimation.state(at: 0.85).expansion
        #expect(peak > 1.0 && peak <= PillAnimation.maxProgress)
        #expect(abs(PillAnimation.state(at: 1.1).expansion - 1) < 0.001)
    }

    // The user wants to see the final circle before it goes back up.
    @Test func becomesACircleAgainAndIsSeenBeforeRising() {
        let seen = PillAnimation.state(at: 5.75)
        #expect(seen.expansion == 0)
        #expect(seen.drop == 1)
        #expect(seen.contentOpacity == 0)
        // And it is up again by the end.
        #expect(PillAnimation.state(at: PillAnimation.duration).drop == 0)
    }

    @Test func neverMovesAndChangesShapeAtTheSameTime() {
        for t in samples {
            let s = PillAnimation.state(at: t)
            if s.expansion > 0.001 { #expect(s.drop >= 0.999) }
        }
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
        let s = PillAnimation.state(at: PillAnimation.duration)
        #expect(s.isFinished)
        #expect(s.drop == 0)
        #expect(s.expansion == 0)
        #expect(s.contentOpacity == 0)
    }

    @Test func clampsOutOfRangeAndNaN() {
        #expect(PillAnimation.state(at: -3) == PillAnimation.state(at: 0))
        #expect(PillAnimation.state(at: 600) == PillAnimation.state(at: PillAnimation.duration))
        #expect(PillAnimation.state(at: .nan) == PillAnimation.state(at: 0))
    }

    @Test func neverExceedsMaxOrGoesNegative() {
        for t in samples {
            let s = PillAnimation.state(at: t)
            for v in [s.drop, s.expansion] { #expect(v >= 0 && v <= PillAnimation.maxProgress) }
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

    @Test func contentIsGoneBeforeThePillShrinksSmall() {
        for t in samples {
            let s = PillAnimation.state(at: t)
            if s.expansion < 0.6 { #expect(s.contentOpacity == 0) }
        }
    }

    @Test func noPopping() {
        var previous = PillAnimation.state(at: 0)
        for t in samples.dropFirst() {
            let s = PillAnimation.state(at: t)
            #expect(abs(s.drop - previous.drop) < 0.2)
            #expect(abs(s.expansion - previous.expansion) < 0.2)
            #expect(abs(s.lidClosure - previous.lidClosure) < 0.6)
            previous = s
        }
    }
}
