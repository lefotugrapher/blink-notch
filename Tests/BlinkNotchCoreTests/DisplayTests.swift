import CoreGraphics
import Testing
@testable import BlinkNotchCore

let testLaptop = DisplayInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 2056, height: 1329),
                             menuBarHeight: 38, notch: NotchSize(width: 220, height: 38))
let testExternal = DisplayInfo(id: 2, frame: CGRect(x: 2056, y: 0, width: 2560, height: 1440),
                               menuBarHeight: 24, notch: nil)

@Suite struct DisplayTests {
    @Test func containsPicksThatDisplay() {
        #expect(pickDisplay(cursor: CGPoint(x: 3000, y: 700), from: [testLaptop, testExternal]) == testExternal)
        #expect(pickDisplay(cursor: CGPoint(x: 500, y: 700), from: [testLaptop, testExternal]) == testLaptop)
    }

    // Review Focus 4: the cursor sits on the very top edge when reaching for the menu bar.
    @Test func cursorOnTopEdgePicksThatDisplay() {
        #expect(pickDisplay(cursor: CGPoint(x: 1000, y: 1329), from: [testLaptop, testExternal]) == testLaptop)
        #expect(pickDisplay(cursor: CGPoint(x: 3000, y: 1440), from: [testLaptop, testExternal]) == testExternal)
    }

    @Test func sharedEdgeFirstMatchWins() {
        #expect(pickDisplay(cursor: CGPoint(x: 2056, y: 700), from: [testLaptop, testExternal]) == testLaptop)
    }

    // Review Focus 4: outside every display (for example just after one is unplugged).
    @Test func cursorOutsideAllPicksNearest() {
        #expect(pickDisplay(cursor: CGPoint(x: -50, y: 600), from: [testLaptop, testExternal]) == testLaptop)
        #expect(pickDisplay(cursor: CGPoint(x: 5000, y: 700), from: [testLaptop, testExternal]) == testExternal)
    }

    @Test func emptyListIsNil() {
        #expect(pickDisplay(cursor: CGPoint(x: 0, y: 0), from: []) == nil)
    }
}
