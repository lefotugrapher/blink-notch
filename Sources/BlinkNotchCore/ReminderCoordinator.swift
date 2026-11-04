import CoreGraphics
import Foundation

@MainActor
public protocol PillPresenting: AnyObject {
    var isPresenting: Bool { get }
    func present(message: Message, on display: DisplayInfo)
}

@MainActor
public protocol ScreenProviding {
    var displays: [DisplayInfo] { get }
    var cursor: CGPoint { get }
}

/// Ties the countdown, settings, message pool and display choice together.
@MainActor
public final class ReminderCoordinator {
    private let presenter: PillPresenting
    private let screens: ScreenProviding
    private let settings: Settings
    private let intervalOverride: TimeInterval?
    private let now: () -> Date
    private var pool: MessagePool

    public private(set) var schedule: ReminderSchedule
    /// Called after every change to `schedule`, so the timer can be re-armed.
    public var onScheduleChange: (() -> Void)?

    public init(presenter: PillPresenting, screens: ScreenProviding, settings: Settings,
                pool: MessagePool = MessagePool(), intervalOverride: TimeInterval? = nil,
                now: @escaping () -> Date = Date.init) {
        self.presenter = presenter
        self.screens = screens
        self.settings = settings
        self.pool = pool
        self.intervalOverride = intervalOverride
        self.now = now
        self.schedule = ReminderSchedule(interval: intervalOverride ?? settings.interval.seconds, now: now())
    }

    public var isPaused: Bool { schedule.isPaused }
    public var interval: ReminderInterval { settings.interval }

    /// Shows a reminder now. False when one is already playing or there is no display.
    @discardableResult
    public func showNow() -> Bool {
        guard !presenter.isPresenting,
              let display = pickDisplay(cursor: screens.cursor, from: screens.displays) else { return false }
        presenter.present(message: pool.next(), on: display)
        return true
    }

    public func timerFired() {
        if schedule.timerDidFire(now: now()) { showNow() }
        onScheduleChange?()
    }

    public func setPaused(_ paused: Bool) {
        if paused { schedule.pause() } else { schedule.resume(now: now()) }
        onScheduleChange?()
    }

    public func setInterval(_ newInterval: ReminderInterval) {
        settings.interval = newInterval
        schedule.setInterval(intervalOverride ?? newInterval.seconds, now: now())
        onScheduleChange?()
    }

    public func suspend(_ reason: SuspendReason) {
        schedule.suspend(reason)
        onScheduleChange?()
    }

    public func unsuspend(_ reason: SuspendReason) {
        schedule.unsuspend(reason, now: now())
        onScheduleChange?()
    }
}
