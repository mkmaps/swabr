// Draft icons for "Swabr": A = sailboat with a deck swab, B = crossed deck swabs.
import AppKit

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let S: CGFloat = 1024
func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

func tile() -> NSBezierPath {
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(colors: [color(0x2C5E8C), color(0x13294A)])!.draw(in: body, angle: -90)
    return body
}

func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat, _ c: NSColor = color(0xFFF4C2)) {
    let k = rad * 0.15
    let p = NSBezierPath()
    p.move(to: P(cx, cy + rad))
    p.curve(to: P(cx + rad, cy), controlPoint1: P(cx + k, cy + k), controlPoint2: P(cx + k, cy + k))
    p.curve(to: P(cx, cy - rad), controlPoint1: P(cx + k, cy - k), controlPoint2: P(cx + k, cy - k))
    p.curve(to: P(cx - rad, cy), controlPoint1: P(cx - k, cy - k), controlPoint2: P(cx - k, cy - k))
    p.curve(to: P(cx, cy + rad), controlPoint1: P(cx - k, cy + k), controlPoint2: P(cx - k, cy + k))
    c.setFill(); p.fill()
}

/// A deck swab: wooden handle from `top` to `base`, a fan of rope strands below `base`.
func swab(top: NSPoint, base: NSPoint, length: CGFloat, width: CGFloat, handle: CGFloat) {
    let dx = base.x - top.x, dy = base.y - top.y
    let len = hypot(dx, dy), ux = dx / len, uy = dy / len   // along the handle, towards the head
    let nx = -uy, ny = ux                                     // across
    // Handle.
    let h = NSBezierPath()
    h.lineWidth = handle; h.lineCapStyle = .round
    h.move(to: top); h.line(to: base)
    color(0x8A5A34).setStroke(); h.stroke()
    let hl = NSBezierPath()
    hl.lineWidth = handle * 0.3; hl.lineCapStyle = .round
    hl.move(to: P(top.x + nx * handle * 0.18, top.y + ny * handle * 0.18))
    hl.line(to: P(base.x + nx * handle * 0.18, base.y + ny * handle * 0.18))
    color(0xB07C4F).setStroke(); hl.stroke()
    // Rope head: strands fanning out from a collar.
    let strands = 9
    for i in 0..<strands {
        let t = CGFloat(i) / CGFloat(strands - 1) - 0.5           // -0.5…0.5
        let start = P(base.x + nx * t * width * 0.45, base.y + ny * t * width * 0.45)
        let spread = t * width
        let end = P(base.x + ux * length + nx * spread, base.y + uy * length + ny * spread)
        let mid = P(base.x + ux * length * 0.55 + nx * spread * 0.75 - nx * t * 18,
                    base.y + uy * length * 0.55 + ny * spread * 0.75 - ny * t * 18)
        let s = NSBezierPath()
        s.lineWidth = width / CGFloat(strands) * 1.25; s.lineCapStyle = .round
        s.move(to: start); s.curve(to: end, controlPoint1: mid, controlPoint2: mid)
        (i % 2 == 0 ? color(0xF4EFE3) : color(0xDCD3BF)).setStroke(); s.stroke()
    }
    // Collar.
    let c = NSBezierPath()
    c.lineWidth = handle * 1.35; c.lineCapStyle = .butt
    c.move(to: P(base.x - ux * handle * 0.2, base.y - uy * handle * 0.2))
    c.line(to: P(base.x + ux * handle * 0.55, base.y + uy * handle * 0.55))
    color(0x3E6A93).setStroke(); c.stroke()
}

func drop(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let p = NSBezierPath()
    p.move(to: P(cx, cy + r * 1.7))
    p.curve(to: P(cx + r, cy), controlPoint1: P(cx + r * 0.35, cy + r * 1.05), controlPoint2: P(cx + r, cy + r * 0.6))
    p.appendArc(withCenter: P(cx, cy), radius: r, startAngle: 0, endAngle: 180, clockwise: true)
    p.curve(to: P(cx, cy + r * 1.7), controlPoint1: P(cx - r, cy + r * 0.6), controlPoint2: P(cx - r * 0.35, cy + r * 1.05))
    color(0x7CC4F0).setFill(); p.fill()
    let hl = NSBezierPath(ovalIn: NSRect(x: cx - r * 0.45, y: cy - r * 0.05, width: r * 0.32, height: r * 0.5))
    color(0xFFFFFF, 0.7).setFill(); hl.fill()
}

func wave(_ y: CGFloat, _ amp: CGFloat, _ c1: UInt32, _ c2: UInt32) {
    let w = NSBezierPath()
    w.move(to: P(80, 80)); w.line(to: P(80, y))
    var x: CGFloat = 80
    while x < 960 {
        w.curve(to: P(x + 220, y), controlPoint1: P(x + 70, y + amp), controlPoint2: P(x + 150, y - amp))
        x += 220
    }
    w.line(to: P(960, 80)); w.close()
    NSGradient(colors: [color(c1), color(c2)])!.draw(in: w, angle: -90)
}

func render(_ draw: () -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocus(); draw(); img.unlockFocus()
    return img
}

// A: the existing sailboat, a swab leaning on deck, extra sparkles.
let iconA = render {
    let body = tile()
    NSGraphicsContext.saveGraphicsState(); body.addClip()
    sparkle(250, 720, 40)
    sparkle(820, 580, 26)
    Mascot.colorImage(frame: Mascot.restFrame, size: 880).draw(in: NSRect(x: 92, y: 60, width: 840, height: 840))
    swab(top: P(170, 600), base: P(262, 372), length: 74, width: 92, handle: 22)
    drop(330, 420, 15)
    drop(210, 405, 11)
    NSGraphicsContext.restoreGraphicsState()
}

// B: two crossed deck swabs as an emblem, droplets and sparkles, a calm wave.
let iconB = render {
    let body = tile()
    NSGraphicsContext.saveGraphicsState(); body.addClip()
    wave(250, 28, 0x4FA8DE, 0x2E7DB8)
    swab(top: P(735, 790), base: P(400, 400), length: 140, width: 175, handle: 38)
    swab(top: P(289, 790), base: P(624, 400), length: 140, width: 175, handle: 38)
    drop(512, 640, 30)
    sparkle(250, 700, 48)
    sparkle(790, 560, 34)
    sparkle(705, 845, 22)
    NSGraphicsContext.restoreGraphicsState()
}

func write(_ image: NSImage, _ px: Int, _ path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments[1]
for (name, img) in [("A", iconA), ("B", iconB)] {
    for px in [1024, 128, 32] { write(img, px, "\(out)/swabr-\(name)-\(px).png") }
}
print("ok")
