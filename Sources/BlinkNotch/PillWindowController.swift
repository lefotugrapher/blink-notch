import AppKit
import BlinkNotchCore
import SwiftUI

/// Borderless, click-through, never-key panel that can sit over the menu bar.
private final class PillPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Without this AppKit pushes the window below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
}

@MainActor
final class PillWindowController: PillPresenting {
    private(set) var isPresenting = false
    /// Debug (`--freeze-at`): hold this moment of the animation instead of playing it.
    var debugFreezeAt: TimeInterval?
    private var panel: PillPanel?
    private var dismissTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init() {
        // A display was plugged, unplugged or rearranged: never leave a stuck pill.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    func present(message: Message, style: BlinkStyle, on display: DisplayInfo) {
        guard !isPresenting else { return }
        let geometry = PillGeometry(display: display)
        let frame = geometry.windowFrame(on: display)
        let panel = PillPanel(frame: frame)
        panel.contentView = NSHostingView(rootView: PillView(geometry: geometry, message: message, style: style, startDate: Date(), freezeAt: debugFreezeAt))
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        self.panel = panel
        isPresenting = true
        guard debugFreezeAt == nil else { return }
        dismissTimer = Timer.scheduledTimer(withTimeInterval: PillAnimation.duration + 0.1, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
        isPresenting = false
    }
}
