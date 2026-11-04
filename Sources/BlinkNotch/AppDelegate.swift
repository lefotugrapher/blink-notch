import AppKit
import BlinkNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let pillController = PillWindowController()
    private var coordinator: ReminderCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: AppInfo.name)
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item

        // Debug switches: --preview, --freeze-at <seconds>, --message <index>.
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

        let coordinator = ReminderCoordinator(presenter: pillController, screens: SystemScreens(),
                                              settings: Settings(), pool: pool)
        self.coordinator = coordinator

        if args.contains("--preview") || freezeAt != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { coordinator.showNow() }
        }
    }
}
