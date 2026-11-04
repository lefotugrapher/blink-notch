import CoreGraphics
import Testing
@testable import BlinkNotchCore

@Suite struct BlinkStylePickerTests {
    @Test func hasElevenStyles() {
        #expect(BlinkStyle.allCases.count == 11)
    }

    @Test func neverRepeatsConsecutively() {
        var picker = BlinkStylePicker()
        var previous = picker.next()
        for _ in 0..<5_000 {
            let current = picker.next()
            #expect(current != previous)
            previous = current
        }
    }

    @Test func everyStyleEventuallyAppears() {
        var picker = BlinkStylePicker()
        var seen = Set<BlinkStyle>()
        for _ in 0..<2_000 { seen.insert(picker.next()) }
        #expect(seen == Set(BlinkStyle.allCases))
    }

    @Test func singleStylePoolDoesNotHang() {
        var picker = BlinkStylePicker(styles: [.wiper])
        #expect(picker.next() == .wiper)
        #expect(picker.next() == .wiper)
    }

    @Test func scriptedTextOnlyWhereTheMockupHadIt() {
        #expect(BlinkStyle.classic.scriptedHeadlines == nil)
        #expect(BlinkStyle.countdown.scriptedHeadlines == ["Ready to blink?", "BLINK NOW!"])
        #expect(BlinkStyle.buffering.scriptedHeadlines == ["Buffering…", "Reloaded."])
        #expect(BlinkStyle.shutter.scriptedHeadlines == ["Click. Blink captured."])
        #expect(BlinkStyle.wiper.scriptedFrom == "your windshield (eyes)")
    }

    @Test func rawValuesAreStableForTheDebugFlag() {
        #expect(BlinkStyle(rawValue: "bouncingEyeball") == .bouncingEyeball)
        #expect(BlinkStyle(rawValue: "slowCat") == .slowCat)
    }
}

@Suite struct BlinkStyleTimelineTests {
    private let samples = stride(from: 0.0, through: PillAnimation.duration, by: 0.01).map { $0 }

    @Test func everyStyleStartsHiddenAndEndsHidden() {
        for style in BlinkStyle.allCases {
            let start = PillAnimation.state(at: 0, style: style)
            #expect(start.drop == 0 && start.contentOpacity == 0 && start.lidClosure == 0)
            let end = PillAnimation.state(at: PillAnimation.duration, style: style)
            #expect(end.isFinished && end.drop == 0 && end.contentOpacity == 0)
        }
    }

    @Test func everyStyleStaysInRange() {
        for style in BlinkStyle.allCases {
            for t in samples {
                let s = PillAnimation.state(at: t, style: style)
                #expect(s.drop >= 0 && s.drop <= PillAnimation.maxProgress)
                #expect(s.expansion >= 0 && s.expansion <= PillAnimation.maxProgress)
                #expect(s.lidClosure >= 0 && s.lidClosure <= 1)
                #expect(s.secondLidClosure >= 0 && s.secondLidClosure <= 1)
                #expect(abs(s.pupil.dx) <= 1 && abs(s.pupil.dy) <= 1)
                #expect((0...3).contains(s.counter))
            }
        }
    }

    @Test func lidsOnlyMoveWhileTheTextIsVisible() {
        for style in BlinkStyle.allCases {
            for t in samples {
                let s = PillAnimation.state(at: t, style: style)
                if s.lidClosure > 0 || s.secondLidClosure > 0 { #expect(s.contentOpacity > 0.9) }
            }
        }
    }

    @Test func noPoppingInAnyStyle() {
        for style in BlinkStyle.allCases {
            var previous = PillAnimation.state(at: 0, style: style)
            for t in samples.dropFirst() {
                let s = PillAnimation.state(at: t, style: style)
                #expect(abs(s.drop - previous.drop) < 0.2)
                #expect(abs(s.expansion - previous.expansion) < 0.2)
                #expect(abs(s.lidClosure - previous.lidClosure) < 0.6)
                previous = s
            }
        }
    }

    @Test func pillStylesKeepTheCircleRule() {
        for style in BlinkStyle.allCases where style != .bouncingEyeball {
            for t in samples {
                let s = PillAnimation.state(at: t, style: style)
                if s.expansion > 0.001 { #expect(s.drop >= 0.999) }
            }
            let seen = PillAnimation.state(at: 5.75, style: style)
            #expect(seen.expansion == 0 && seen.drop == 1 && seen.contentOpacity == 0)
        }
    }

    @Test func slowCatBlinksSlowly() {
        #expect(PillAnimation.state(at: 1.0, style: .slowCat).lidClosure == 0)
        #expect(PillAnimation.state(at: 2.0, style: .slowCat).lidClosure == 1)
        #expect(PillAnimation.state(at: 3.0, style: .slowCat).lidClosure == 0)
        let mid = PillAnimation.state(at: 1.5, style: .slowCat).lidClosure
        #expect(mid > 0.2 && mid < 0.8)
    }

    @Test func sleepyLidDroopsThenSnapsAwake() {
        let drooping = PillAnimation.state(at: 2.0, style: .sleepy).lidClosure
        #expect(drooping > 0.5 && drooping < 1)
        #expect(PillAnimation.state(at: 2.7, style: .sleepy).lidClosure == 0)
        #expect(PillAnimation.state(at: 3.0, style: .sleepy).lidClosure == 1)
    }

    @Test func twoEyesSecondEyeLagsTheFirst() {
        let a = PillAnimation.state(at: 1.39, style: .twoEyes)
        #expect(a.lidClosure == 1 && a.secondLidClosure < 1)
        let b = PillAnimation.state(at: 1.7, style: .twoEyes)
        #expect(b.secondLidClosure == 1 && b.lidClosure < 1)
    }

    @Test func countdownCountsThenBlinks() {
        #expect(PillAnimation.state(at: 1.5, style: .countdown).counter == 3)
        #expect(PillAnimation.state(at: 2.2, style: .countdown).counter == 2)
        #expect(PillAnimation.state(at: 2.9, style: .countdown).counter == 1)
        let now = PillAnimation.state(at: 3.5, style: .countdown)
        #expect(now.counter == 0 && now.headlinePhase == 1 && now.aux > 0.5)
        #expect(PillAnimation.state(at: 1.5, style: .countdown).headlinePhase == 0)
    }

    @Test func bufferingSpinsThenReloads() {
        #expect(PillAnimation.state(at: 2.0, style: .buffering).aux == 1)
        #expect(PillAnimation.state(at: 2.0, style: .buffering).headlinePhase == 0)
        #expect(PillAnimation.state(at: 4.0, style: .buffering).aux == 0)
        #expect(PillAnimation.state(at: 4.0, style: .buffering).headlinePhase == 1)
    }

    @Test func wiperSweepsAndCleansTheEye() {
        #expect(PillAnimation.state(at: 1.0, style: .wiper).aux == -1)
        #expect(PillAnimation.state(at: 1.45, style: .wiper).aux == 1)
        #expect(PillAnimation.state(at: 4.0, style: .wiper).aux2 == 1)
        #expect(PillAnimation.state(at: 1.0, style: .wiper).aux2 == 0)
    }

    @Test func bouncingEyeballBounces() {
        #expect(PillAnimation.state(at: 0.45, style: .bouncingEyeball).drop == 1)
        #expect(PillAnimation.state(at: 0.75, style: .bouncingEyeball).drop < 0.7)
        #expect(PillAnimation.state(at: 1.45, style: .bouncingEyeball).drop == 1)
        #expect(PillAnimation.state(at: 3.0, style: .bouncingEyeball).expansion == 0)
        #expect(PillAnimation.state(at: 3.0, style: .bouncingEyeball).contentOpacity == 1)
    }
}
