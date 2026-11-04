import AppKit
import BlinkNotchCore

/// One single-shot timer aimed at the schedule's next fire date. No polling, so
/// the app is idle between reminders.
@MainActor
final class ReminderTimer {
    private let coordinator: ReminderCoordinator
    private var timer: Timer?

    init(coordinator: ReminderCoordinator) {
        self.coordinator = coordinator
        coordinator.onScheduleChange = { [weak self] in self?.rearm() }
        rearm()
    }

    func rearm() {
        timer?.invalidate()
        timer = nil
        guard let fireDate = coordinator.schedule.nextFire else { return }
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.timerFired() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
