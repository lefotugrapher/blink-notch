import AppKit
import BlinkNotchCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let coordinator: ReminderCoordinator
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
    private let everyMenu = NSMenu()
    private let loginItem = NSMenuItem(title: "Launch at login", action: nil, keyEquivalent: "")

    init(coordinator: ReminderCoordinator) {
        self.coordinator = coordinator
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: AppInfo.name)
        menu.delegate = self

        menu.addItem(item("Show one now", #selector(showNow)))

        pauseItem.action = #selector(togglePause)
        pauseItem.target = self
        menu.addItem(pauseItem)

        let every = NSMenuItem(title: "Every", action: nil, keyEquivalent: "")
        for interval in ReminderInterval.allCases {
            let entry = item(interval.menuTitle, #selector(chooseInterval(_:)))
            entry.tag = interval.rawValue
            everyMenu.addItem(entry)
        }
        every.submenu = everyMenu
        menu.addItem(every)

        loginItem.action = #selector(toggleLaunchAtLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        refresh()
    }

    /// Titles and check marks as plain text, for the `--dump-menu` debug switch.
    func dump() -> String {
        refresh()
        return menu.items.map { top in
            guard let sub = top.submenu else {
                return top.isSeparatorItem ? "---" : (top.state == .on ? "[x] " : "") + top.title
            }
            return top.title + ": " + sub.items.map { ($0.state == .on ? "[x] " : "[ ] ") + $0.title }.joined(separator: ", ")
        }.joined(separator: "\n")
    }

    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    private func refresh() {
        pauseItem.title = coordinator.isPaused ? "Resume" : "Pause"
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        for entry in everyMenu.items {
            entry.state = entry.tag == coordinator.interval.rawValue ? .on : .off
        }
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    @objc private func showNow() { coordinator.showNow() }
    @objc private func togglePause() { coordinator.setPaused(!coordinator.isPaused) }
    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            // Leave the item as it is (unchecked); no modal, no crash.
            NSLog("Blink Notch: could not change launch at login: \(error)")
        }
        refresh()
    }
    @objc private func chooseInterval(_ sender: NSMenuItem) {
        if let interval = ReminderInterval(rawValue: sender.tag) { coordinator.setInterval(interval) }
    }
}
