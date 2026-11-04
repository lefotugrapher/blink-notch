import AppKit
import BlinkNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pillController = PillWindowController()
    private var coordinator: ReminderCoordinator?
    private var menuBar: MenuBarController?
    private var timer: ReminderTimer?
    private var systemEvents: SystemEvents?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Debug switches: --preview, --freeze-at <seconds>, --message <index>, --dump-menu,
        // and env BLINKNOTCH_DEBUG_INTERVAL_SECONDS to replace the interval.
        let args = CommandLine.arguments
        func value(after flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }
        let freezeAt = value(after: "--freeze-at").flatMap(Double.init)
        pillController.debugFreezeAt = freezeAt
        var pool = MessagePool()
        if let index = value(after: "--message").flatMap(Int.init), MessagePool.all.indices.contains(index) {
            pool = MessagePool(messages: [MessagePool.all[index]])
        }
        let intervalOverride = ProcessInfo.processInfo.environment["BLINKNOTCH_DEBUG_INTERVAL_SECONDS"]
            .flatMap(Double.init)

        let coordinator = ReminderCoordinator(presenter: pillController, screens: SystemScreens(),
                                              settings: Settings(), pool: pool,
                                              intervalOverride: intervalOverride)
        self.coordinator = coordinator
        let menuBar = MenuBarController(coordinator: coordinator)
        self.menuBar = menuBar
        timer = ReminderTimer(coordinator: coordinator)
        systemEvents = SystemEvents(coordinator: coordinator)

        if args.contains("--dump-menu") {
            print(menuBar.dump())
            exit(0)
        }
        if args.contains("--preview") || freezeAt != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { coordinator.showNow() }
        }
    }
}
