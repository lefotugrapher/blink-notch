import CoreGraphics
import Testing
@testable import BlinkNotchCore

@Suite struct PillGeometryTests {
    @Test func notchDisplayMeasuresFromNotch() {
        let g = PillGeometry(display: testLaptop)
        #expect(g.style == .notch)
        #expect(g.neckSize == CGSize(width: 220, height: 38))
        #expect(g.bodySize == CGSize(width: 270, height: 70))
        #expect(g.topInset == 0)
        #expect(g.neckSize.height + g.bodySize.height == 108)
    }

    @Test func narrowNotchStillGetsMinimumBody() {
        let narrow = DisplayInfo(id: 3, frame: testLaptop.frame, menuBarHeight: 38,
                                 notch: NotchSize(width: 100, height: 38))
        #expect(PillGeometry(display: narrow).bodySize.width == 260)
    }

    @Test func noNotchIsFloating() {
        let g = PillGeometry(display: testExternal)
        #expect(g.style == .floating)
        #expect(g.neckSize == .zero)
        #expect(g.bodySize == CGSize(width: 270, height: 70))
        #expect(g.topInset == 8)
    }

    @Test func windowFitsOvershoot() {
        for display in [testLaptop, testExternal] {
            let g = PillGeometry(display: display)
            #expect(g.windowSize.width >= 1.12 * g.bodySize.width)
            #expect(g.windowSize.height >= 1.12 * (g.neckSize.height + g.bodySize.height + g.topInset))
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
