import AppKit
import BlinkNotchCore

/// Reads the real displays, including the notch size, from `NSScreen` at run time.
@MainActor
struct SystemScreens: ScreenProviding {
    var displays: [DisplayInfo] { NSScreen.screens.map(Self.info(for:)) }
    var cursor: CGPoint { NSEvent.mouseLocation }

    static func info(for screen: NSScreen) -> DisplayInfo {
        let frame = screen.frame
        var notch: NotchSize?
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = NotchSize(width: frame.width - left.width - right.width,
                              height: screen.safeAreaInsets.top)
        }
        // Debug: pretend there is no notch, to exercise the floating style on the laptop screen.
        if ProcessInfo.processInfo.environment["BLINKNOTCH_DEBUG_NO_NOTCH"] != nil { notch = nil }
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return DisplayInfo(id: number?.uint32Value ?? 0,
                           frame: frame,
                           menuBarHeight: frame.maxY - screen.visibleFrame.maxY,
                           notch: notch)
    }
}
