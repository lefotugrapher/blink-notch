import AppKit
import BlinkNotchCore
import SwiftUI

/// Debug/tooling: renders the animation to transparent PNG frames, with no screen
/// capture involved, so README media never contains anything from the desktop.
@MainActor
enum FrameRenderer {
    static func render(into directory: String, style: BlinkStyle, message: Message, fps: Double, scale: CGFloat) {
        let displays = SystemScreens().displays
        guard let display = displays.first(where: { $0.notch != nil }) ?? displays.first else { return }
        let geometry = PillGeometry(display: display)
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let count = Int(PillAnimation.duration * fps) + 1
        for i in 0..<count {
            let t = Double(i) / fps
            let view = PillView(geometry: geometry, message: message, style: style, startDate: Date(), freezeAt: t)
                .frame(width: geometry.windowSize.width, height: geometry.windowSize.height, alignment: .topLeading)
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            guard let cgImage = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(String(format: "frame-%04d.png", i)))
        }
        let notch = geometry.notchSize
        print("window \(geometry.windowSize.width) \(geometry.windowSize.height) notch \(notch.width) \(notch.height) frames \(count)")
    }
}
