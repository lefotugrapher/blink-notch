import CoreGraphics
import Testing
@testable import BlinkNotchCore

@MainActor final class FakePresenter: PillPresenting {
    nonisolated init() {}
    var isPresenting = false
    var presented: [(message: Message, display: DisplayInfo)] = []
    func present(message: Message, on display: DisplayInfo) {
        presented.append((message, display))
        isPresenting = true
    }
}

struct FakeScreens: ScreenProviding {
    var displays: [DisplayInfo] = [testLaptop, testExternal]
    var cursor = CGPoint(x: 500, y: 700)
}

@MainActor final class TestClock {
    nonisolated init() {}
    var now = date(1_000)
}

@MainActor @Suite struct ReminderCoordinatorTests {
    let clock = TestClock()
    let presenter = FakePresenter()
    let settings = Settings(defaults: freshDefaults())

    func make(screens: FakeScreens? = nil, override: Double? = nil) -> ReminderCoordinator {
        let clock = self.clock
        return ReminderCoordinator(presenter: presenter, screens: screens ?? FakeScreens(), settings: settings,
                                   intervalOverride: override, now: { clock.now })
    }

    @Test func showNowPresentsOnCursorDisplay() {
        let c = make(screens: FakeScreens(cursor: CGPoint(x: 3000, y: 700)))
        #expect(c.showNow())
        #expect(presenter.presented.count == 1)
        #expect(presenter.presented[0].display == testExternal)
        #expect(MessagePool.all.contains(presenter.presented[0].message))
    }

    // Review Focus 3: never stack two pills.
    @Test func secondTriggerWhilePresentingIsIgnored() {
        let c = make()
        #expect(c.showNow())
        #expect(!c.showNow())
        clock.now = clock.now + 1200
        c.timerFired()
        #expect(presenter.presented.count == 1)
    }

    @Test func noDisplaysDoesNothing() {
        let c = make(screens: FakeScreens(displays: []))
        #expect(!c.showNow())
        #expect(presenter.presented.isEmpty)
    }

    @Test func showNowWorksWhilePaused() {
        let c = make()
        c.setPaused(true)
        #expect(c.isPaused)
        #expect(c.showNow())
    }

    @Test func timerFiredWhenPausedDoesNotPresent() {
        let c = make()
        c.setPaused(true)
        clock.now = clock.now + 1200
        c.timerFired()
        #expect(presenter.presented.isEmpty)
    }

    @Test func resumeRestartsCountdown() {
        let c = make()
        c.setPaused(true)
        clock.now = clock.now + 300
        c.setPaused(false)
        #expect(c.schedule.nextFire == clock.now + 1200)
    }

    @Test func timerFiredWhenDuePresentsAndRearms() {
        let c = make()
        let start = clock.now
        clock.now = start + 1200
        c.timerFired()
        #expect(presenter.presented.count == 1)
        #expect(c.schedule.nextFire == start + 2400)
    }

    @Test func setIntervalPersistsAndRestarts() {
        let c = make()
        var changes = 0
        c.onScheduleChange = { changes += 1 }
        c.setInterval(.thirty)
        #expect(settings.interval == .thirty)
        #expect(c.interval == .thirty)
        #expect(c.schedule.nextFire == clock.now + 1800)
        #expect(changes == 1)
    }

    @Test func unsuspendRestartsCountdown() {
        let c = make()
        c.suspend(.locked)
        #expect(c.schedule.nextFire == nil)
        clock.now = clock.now + 4000
        c.unsuspend(.locked)
        #expect(c.schedule.nextFire == clock.now + 1200)
    }

    @Test func intervalOverrideReplacesSeconds() {
        let c = make(override: 15)
        #expect(c.schedule.nextFire == clock.now + 15)
        c.setInterval(.sixty)
        #expect(c.schedule.nextFire == clock.now + 15)
    }
}
