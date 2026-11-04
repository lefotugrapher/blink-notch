import AppKit
import BlinkNotchCore

/// Tells the coordinator when the screen sleeps, wakes, locks or unlocks, so no
/// reminder fires into an unwatched screen and the countdown restarts after.
@MainActor
final class SystemEvents {
    private var tokens: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    init(coordinator: ReminderCoordinator) {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        observe(workspace, NSWorkspace.willSleepNotification) { coordinator.suspend(.screenAsleep) }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { coordinator.suspend(.screenAsleep) }
        // Only the screens waking counts: a dark wake (system up, screens off) stays silent.
        observe(workspace, NSWorkspace.screensDidWakeNotification) { coordinator.unsuspend(.screenAsleep) }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { coordinator.suspend(.locked) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { coordinator.unsuspend(.locked) }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ action: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        }
        tokens.append((center, token))
    }
}
