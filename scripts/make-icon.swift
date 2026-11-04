// Draws the Blink Notch app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift   (needs only the Command Line Tools)
import AppKit

let size: CGFloat = 1024

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// App-icon tile: 824 pt rounded square centred in the 1024 canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 28
shadow.set()
hex(0x27324D).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

tilePath.addClip()
NSGradient(colors: [hex(0x2B3A66), hex(0x5A3A66)])!.draw(in: tile, angle: -60)

// The notch, hanging from the top edge of the tile.
let notch = NSBezierPath()
let nx = tile.midX, nTop = tile.maxY, nW: CGFloat = 330, nH: CGFloat = 96, r: CGFloat = 44
notch.move(to: NSPoint(x: nx - nW / 2, y: nTop))
notch.line(to: NSPoint(x: nx + nW / 2, y: nTop))
notch.line(to: NSPoint(x: nx + nW / 2, y: nTop - nH + r))
notch.curve(to: NSPoint(x: nx + nW / 2 - r, y: nTop - nH),
            controlPoint1: NSPoint(x: nx + nW / 2, y: nTop - nH + 14),
            controlPoint2: NSPoint(x: nx + nW / 2 - 14, y: nTop - nH))
notch.line(to: NSPoint(x: nx - nW / 2 + r, y: nTop - nH))
notch.curve(to: NSPoint(x: nx - nW / 2, y: nTop - nH + r),
            controlPoint1: NSPoint(x: nx - nW / 2 + 14, y: nTop - nH),
            controlPoint2: NSPoint(x: nx - nW / 2, y: nTop - nH + 14))
notch.close()
NSColor.black.setFill()
notch.fill()

// The eyeball.
let eye = NSRect(x: tile.midX - 290, y: tile.midY - 215, width: 580, height: 430)
let eyePath = NSBezierPath(ovalIn: eye)
NSGraphicsContext.saveGraphicsState()
let eyeShadow = NSShadow()
eyeShadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
eyeShadow.shadowOffset = NSSize(width: 0, height: -12)
eyeShadow.shadowBlurRadius = 24
eyeShadow.set()
NSColor.white.setFill()
eyePath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
eyePath.addClip()
// Pupil, looking slightly down and to the left.
let pupil = NSRect(x: eye.midX - 150, y: eye.midY - 150, width: 210, height: 210)
hex(0x1A1A1A).setFill()
NSBezierPath(ovalIn: pupil).fill()
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: pupil.minX + 48, y: pupil.maxY - 82, width: 52, height: 52)).fill()
// Eyelid mid-slam: coral slab from the top with a darker rim.
let lidBottom = eye.maxY - 190
let lid = NSRect(x: eye.minX - 10, y: lidBottom, width: eye.width + 20, height: eye.maxY - lidBottom + 20)
hex(0xFF5A5F).setFill()
NSBezierPath(rect: lid).fill()
hex(0xB3262B).setFill()
NSBezierPath(rect: NSRect(x: lid.minX, y: lidBottom, width: lid.width, height: 22)).fill()
NSGraphicsContext.restoreGraphicsState()
NSColor(white: 0.1, alpha: 1).setStroke()
eyePath.lineWidth = 14
eyePath.stroke()

NSGraphicsContext.restoreGraphicsState()

// Write the iconset and build the .icns.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let work = root.appendingPathComponent(".build/icon", isDirectory: true)
let iconset = work.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: work)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = work.appendingPathComponent("master.png")
try rep.representation(using: .png, properties: [:])!.write(to: master)

func run(_ tool: String, _ args: [String]) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    try p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { fatalError("\(tool) failed") }
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try run("/usr/bin/sips", ["-z", "\(px)", "\(px)", master.path, "--out", iconset.appendingPathComponent(name).path])
    }
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", out.path])
try FileManager.default.copyItem(at: master, to: root.appendingPathComponent(".build/icon-preview.png"))
print("wrote \(out.path)")
