// Draws the Swabr app icon (the sailboat from App/MenuBar/Mascot.swift on a deep-blue tile) and writes the
// macOS AppIcon set. Usage:
//   swiftc Tools/make_icon.swift App/MenuBar/Mascot.swift -o /tmp/make_icon && /tmp/make_icon Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let outDir: String = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// A deck swab: wooden handle from `top` to `base`, a fan of rope strands below `base`.
func swab(top: NSPoint, base: NSPoint, length: CGFloat, width: CGFloat, handle: CGFloat) {
    let dx = base.x - top.x, dy = base.y - top.y
    let len = hypot(dx, dy), ux = dx / len, uy = dy / len   // along the handle, towards the head
    let nx = -uy, ny = ux                                     // across
    let h = NSBezierPath()
    h.lineWidth = handle; h.lineCapStyle = .round
    h.move(to: top); h.line(to: base)
    color(0x8A5A34).setStroke(); h.stroke()
    let hl = NSBezierPath()
    hl.lineWidth = handle * 0.3; hl.lineCapStyle = .round
    hl.move(to: NSPoint(x: top.x + nx * handle * 0.18, y: top.y + ny * handle * 0.18))
    hl.line(to: NSPoint(x: base.x + nx * handle * 0.18, y: base.y + ny * handle * 0.18))
    color(0xB07C4F).setStroke(); hl.stroke()
    let strands = 9
    for i in 0..<strands {
        let t = CGFloat(i) / CGFloat(strands - 1) - 0.5
        let start = NSPoint(x: base.x + nx * t * width * 0.45, y: base.y + ny * t * width * 0.45)
        let spread = t * width
        let end = NSPoint(x: base.x + ux * length + nx * spread, y: base.y + uy * length + ny * spread)
        let bend = t * width * 0.2
        let mid = NSPoint(x: base.x + ux * length * 0.55 + nx * (spread * 0.75 - bend), y: base.y + uy * length * 0.55 + ny * (spread * 0.75 - bend))
        let p = NSBezierPath()
        p.lineWidth = width / CGFloat(strands) * 1.25; p.lineCapStyle = .round
        p.move(to: start); p.curve(to: end, controlPoint1: mid, controlPoint2: mid)
        (i % 2 == 0 ? color(0xF4EFE3) : color(0xDCD3BF)).setStroke(); p.stroke()
    }
    let collar = NSBezierPath()
    collar.lineWidth = handle * 1.35
    collar.move(to: NSPoint(x: base.x - ux * handle * 0.2, y: base.y - uy * handle * 0.2))
    collar.line(to: NSPoint(x: base.x + ux * handle * 0.55, y: base.y + uy * handle * 0.55))
    color(0x3E6A93).setStroke(); collar.stroke()
}

/// A water drop with a small highlight.
func drop(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: cx, y: cy + r * 1.7))
    p.curve(to: NSPoint(x: cx + r, y: cy), controlPoint1: NSPoint(x: cx + r * 0.35, y: cy + r * 1.05), controlPoint2: NSPoint(x: cx + r, y: cy + r * 0.6))
    p.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: 0, endAngle: 180, clockwise: true)
    p.curve(to: NSPoint(x: cx, y: cy + r * 1.7), controlPoint1: NSPoint(x: cx - r, y: cy + r * 0.6), controlPoint2: NSPoint(x: cx - r * 0.35, y: cy + r * 1.05))
    color(0x7CC4F0).setFill(); p.fill()
    color(0xFFFFFF, 0.7).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - r * 0.45, y: cy - r * 0.05, width: r * 0.32, height: r * 0.5)).fill()
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / 1024
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * s, y: y * s, width: w * s, height: h * s) }

    // Squircle background (macOS grid: 824 pt body inside 1024 canvas).
    let body = NSBezierPath(roundedRect: r(100, 100, 824, 824), xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [color(0x2C5E8C), color(0x13294A)])!.draw(in: body, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    body.addClip()

    // Sparkles: the app cleans.
    func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx * s, y: (cy + rad) * s))
        p.curve(to: NSPoint(x: (cx + rad) * s, y: cy * s), controlPoint1: NSPoint(x: (cx + rad * 0.15) * s, y: (cy + rad * 0.15) * s), controlPoint2: NSPoint(x: (cx + rad * 0.15) * s, y: (cy + rad * 0.15) * s))
        p.curve(to: NSPoint(x: cx * s, y: (cy - rad) * s), controlPoint1: NSPoint(x: (cx + rad * 0.15) * s, y: (cy - rad * 0.15) * s), controlPoint2: NSPoint(x: (cx + rad * 0.15) * s, y: (cy - rad * 0.15) * s))
        p.curve(to: NSPoint(x: (cx - rad) * s, y: cy * s), controlPoint1: NSPoint(x: (cx - rad * 0.15) * s, y: (cy - rad * 0.15) * s), controlPoint2: NSPoint(x: (cx - rad * 0.15) * s, y: (cy - rad * 0.15) * s))
        p.curve(to: NSPoint(x: cx * s, y: (cy + rad) * s), controlPoint1: NSPoint(x: (cx - rad * 0.15) * s, y: (cy + rad * 0.15) * s), controlPoint2: NSPoint(x: (cx - rad * 0.15) * s, y: (cy + rad * 0.15) * s))
        color(0xFFF4C2).setFill()
        p.fill()
    }
    sparkle(250, 720, 40)
    sparkle(820, 580, 26)

    // The boat comes from the menu bar mascot, so icon and animation match.
    Mascot.colorImage(frame: Mascot.restFrame, size: 880 * s).draw(in: r(92, 60, 840, 840))

    // A deck swab leaning on the deck, with a few drops: the app swabs the deck.
    swab(top: NSPoint(x: 170 * s, y: 600 * s), base: NSPoint(x: 262 * s, y: 372 * s), length: 74 * s, width: 92 * s, handle: 22 * s)
    drop(330 * s, 420 * s, 15 * s)
    drop(210 * s, 405 * s, 11 * s)
    NSGraphicsContext.restoreGraphicsState()
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        writePNG(drawIcon(size: CGFloat(px)), pixels: px, to: outDir + "/" + name)
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: outDir + "/Contents.json"))
print("AppIcon geschrieben nach \(outDir)")
