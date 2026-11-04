import Testing
@testable import BlinkNotchCore

@Suite struct ReminderScheduleTests {
    let t0 = date(1_000)
    func make() -> ReminderSchedule { ReminderSchedule(interval: 1200, now: t0) }

    @Test func startsRunningWithFullInterval() {
        #expect(make().nextFire == t0 + 1200)
    }

    @Test func firesAtNextFireAndReschedules() {
        var s = make()
        let fired = s.timerDidFire(now: t0 + 1200)
        #expect(fired)
        #expect(s.nextFire == t0 + 2400)
    }

    @Test func timerSlopWithinOneSecondStillFires() {
        var s = make()
        let fired = s.timerDidFire(now: t0 + 1199.5)
        #expect(fired)
    }

    @Test func earlyFireIsIgnored() {
        var s = make()
        let fired = s.timerDidFire(now: t0 + 1190)
        #expect(!fired)
        #expect(s.nextFire == t0 + 1200)
    }

    @Test func fireSixtySecondsLateStillCounts() {
        var s = make()
        let fired = s.timerDidFire(now: t0 + 1260)
        #expect(fired)
    }

    // Review Focus 1: the Mac slept through the fire time; the timer fires late on wake.
    @Test func staleFireAfterSleepIsSkipped() {
        var s = make()
        let fired = s.timerDidFire(now: t0 + 5000)
        #expect(!fired)
        #expect(s.nextFire == t0 + 5000 + 1200)
    }

    @Test func pausedNeverFires() {
        var s = make()
        s.pause()
        #expect(s.isPaused)
        #expect(s.nextFire == nil)
        let fired = s.timerDidFire(now: t0 + 1200)
        #expect(!fired)
        #expect(s.nextFire == nil)
    }

    @Test func resumeRestartsCountdown() {
        var s = make()
        s.pause()
        s.resume(now: t0 + 500)
        #expect(!s.isPaused)
        #expect(s.nextFire == t0 + 1700)
    }

    @Test func setIntervalRestartsCountdown() {
        var s = make()
        s.setInterval(600, now: t0 + 100)
        #expect(s.nextFire == t0 + 700)
    }

    @Test func suspendedNeverFires() {
        var s = make()
        s.suspend(.locked)
        #expect(s.isSuspended)
        #expect(s.nextFire == nil)
        let fired = s.timerDidFire(now: t0 + 1200)
        #expect(!fired)
    }

    @Test func unsuspendRestartsFullCountdown() {
        var s = make()
        s.suspend(.screenAsleep)
        s.unsuspend(.screenAsleep, now: t0 + 4000)
        #expect(!s.isSuspended)
        #expect(s.nextFire == t0 + 5200)
    }

    // Review Focus 2: lock, then screen sleep, then the screen wakes while still locked.
    @Test func lockThenSleepThenWakeStillLockedStaysSilent() {
        var s = make()
        s.suspend(.locked)
        s.suspend(.screenAsleep)
        s.unsuspend(.screenAsleep, now: t0 + 3000)
        #expect(s.isSuspended)
        #expect(s.nextFire == nil)
        s.unsuspend(.locked, now: t0 + 4000)
        #expect(!s.isSuspended)
        #expect(s.nextFire == t0 + 4000 + 1200)
    }

    @Test func unsuspendWhilePausedStaysPaused() {
        var s = make()
        s.pause()
        s.suspend(.locked)
        s.unsuspend(.locked, now: t0 + 100)
        #expect(s.isPaused)
        #expect(s.nextFire == nil)
        s.resume(now: t0 + 200)
        #expect(s.nextFire == t0 + 1400)
    }

    @Test func resumeWhileSuspendedWaitsForUnsuspend() {
        var s = make()
        s.suspend(.screenAsleep)
        s.pause()
        s.resume(now: t0 + 50)
        #expect(s.nextFire == nil)
        s.unsuspend(.screenAsleep, now: t0 + 60)
        #expect(s.nextFire == t0 + 1260)
    }
}
