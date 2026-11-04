import CoreGraphics
import Testing
@testable import BlinkNotchCore

@Suite struct PillGeometryTests {
    private let samples = stride(from: 0.0, through: PillAnimation.duration, by: 0.01).map { $0 }

    @Test func notchDisplayMeasuresFromNotch() {
        let g = PillGeometry(display: testLaptop)
        #expect(g.style == .notch)
        #expect(g.notchSize == CGSize(width: 220, height: 38))
        #expect(g.pillSize == CGSize(width: 270, height: 70))
        #expect(g.restTop == 48)
    }

    @Test func spaceBetweenNotchAndRestingShape() {
        let g = PillGeometry(display: testLaptop)
        #expect(g.restTop - g.notchSize.height >= 8)
    }

    @Test func narrowNotchStillGetsMinimumPill() {
        let narrow = DisplayInfo(id: 3, frame: testLaptop.frame, menuBarHeight: 38,
                                 notch: NotchSize(width: 100, height: 38))
        #expect(PillGeometry(display: narrow).pillSize.width == 260)
    }

    @Test func noNotchIsFloating() {
        let g = PillGeometry(display: testExternal)
        #expect(g.style == .floating)
        #expect(g.notchSize == .zero)
        #expect(g.pillSize == CGSize(width: 270, height: 70))
        #expect(g.restTop == 8)
    }

    @Test func hiddenCircleIsFullyAboveTheWindow() {
        for display in [testLaptop, testExternal] {
            let g = PillGeometry(display: display)
            let f = g.shapeFrame(drop: 0, expansion: 0)
            #expect(f.width == PillGeometry.circleDiameter && f.height == PillGeometry.circleDiameter)
            #expect(f.maxY <= 0)
            #expect(f.midX == g.windowSize.width / 2)
        }
    }

    @Test func restingPillIsCentredAtRestTop() {
        for display in [testLaptop, testExternal] {
            let g = PillGeometry(display: display)
            let f = g.shapeFrame(drop: 1, expansion: 1)
            #expect(f.size == g.pillSize)
            #expect(f.minY == g.restTop)
            #expect(f.midX == g.windowSize.width / 2)
        }
    }

    @Test func expansionZeroIsACircle() {
        let f = PillGeometry(display: testLaptop).shapeFrame(drop: 1, expansion: 0)
        #expect(f.width == f.height)
    }

    // A clipped shape was the original complaint; the window must always contain it.
    @Test func shapeAlwaysFitsInsideTheWindowForTheWholeAnimation() {
        for display in [testLaptop, testExternal] {
            let g = PillGeometry(display: display)
            for t in samples {
                let s = PillAnimation.state(at: t)
                let f = g.shapeFrame(drop: s.drop, expansion: s.expansion)
                #expect(f.minX >= 0 && f.maxX <= g.windowSize.width)
                #expect(f.maxY <= g.windowSize.height)
            }
        }
    }

    @Test func windowFrameIsCentredAndTopAligned() {
        let notch = PillGeometry(display: testLaptop).windowFrame(on: testLaptop)
        #expect(notch.maxY == testLaptop.frame.maxY)
        #expect(notch.midX == testLaptop.frame.midX)

        let floating = PillGeometry(display: testExternal).windowFrame(on: testExternal)
        #expect(floating.maxY == testExternal.frame.maxY - 24)
        #expect(floating.midX == testExternal.frame.midX)
    }
}
