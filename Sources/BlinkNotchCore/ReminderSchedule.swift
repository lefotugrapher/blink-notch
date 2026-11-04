import Foundation

public struct SuspendReason: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let screenAsleep = SuspendReason(rawValue: 1 << 0)
    public static let locked = SuspendReason(rawValue: 1 << 1)
}

/// Pure countdown state machine. It never reads the clock; callers pass `now`.
public struct ReminderSchedule: Sendable {
    /// A fire this far past its due time means the Mac was asleep; skip it.
    private static let staleAfter: TimeInterval = 60
    /// Timers may fire marginally early; accept up to this much.
    private static let earlyTolerance: TimeInterval = 1

    private var interval: TimeInterval
    private var suspendedFor: SuspendReason = []

    public private(set) var isPaused = false
    public private(set) var nextFire: Date?

    public var isSuspended: Bool { !suspendedFor.isEmpty }
    private var isRunning: Bool { !isPaused && !isSuspended }

    public init(interval: TimeInterval, now: Date) {
        self.interval = interval
        self.nextFire = now + interval
    }

    public mutating func pause() {
        isPaused = true
        nextFire = nil
    }

    public mutating func resume(now: Date) {
        isPaused = false
        restart(now: now)
    }

    public mutating func setInterval(_ newInterval: TimeInterval, now: Date) {
        interval = newInterval
        restart(now: now)
    }

    public mutating func suspend(_ reason: SuspendReason) {
        suspendedFor.insert(reason)
        nextFire = nil
    }

    public mutating func unsuspend(_ reason: SuspendReason, now: Date) {
        suspendedFor.remove(reason)
        restart(now: now)
    }

    /// Returns true when a reminder should be shown now. Reschedules when due or stale.
    public mutating func timerDidFire(now: Date) -> Bool {
        guard isRunning, let due = nextFire else { return false }
        guard now >= due - Self.earlyTolerance else { return false }
        let isStale = now > due + Self.staleAfter
        nextFire = now + interval
        return !isStale
    }

    /// Restarts the full countdown, or clears it while paused or suspended.
    private mutating func restart(now: Date) {
        nextFire = isRunning ? now + interval : nil
    }
}
