import AppKit

/// Swabr's mascot: a small sailboat, drawn as vector paths so it stays sharp at any scale.
/// The animation tells the story of a clean deck: waves come up, the boat sails in, the sails are hoisted,
/// it rocks while the pennant flutters, and a sparkle says the deck is swabbed clean.
/// Used for the menu bar icon (template) and, in color, for the app icon (Tools/make_icon.swift).
enum Mascot {
    static let frameCount = 40
    /// Resting pose: upright, sails up, sparkle on.
    static let restFrame = frameCount - 1
    static let fps: Double = 12

    struct Pose {
        var enter: CGFloat = 1      // 0…1 boat sailing in from the left
        var sail: CGFloat = 1       // 0…1 sails hoisted
        var tilt: CGFloat = 0       // -1…1 rocking
        var flutter: CGFloat = 0    // pennant wave phase
        var sparkle: CGFloat = 1    // 0…1 sparkle size
        var wave: CGFloat = 0       // wave phase
    }

    static func pose(_ frame: Int) -> Pose {
        let f = CGFloat(min(max(frame, 0), frameCount - 1))
        var p = Pose()
        p.wave = f / 6
        p.flutter = f / 2.5
        switch f {
        case 0..<10:            // sailing in, sails down
            let t = f / 10
            p.enter = 1 - (1 - t) * (1 - t)
            p.sail = 0
            p.sparkle = 0
            p.tilt = sin(f / 1.6) * 0.25
        case 10..<17:           // hoisting the sails
            p.sail = (f - 10) / 7
            p.sparkle = 0
        case 17..<31:           // rocking on the waves
            p.tilt = sin((f - 17) / 14 * .pi * 2) * (1 - (f - 17) / 18)
            p.sparkle = 0
        case 31..<36:           // sparkle pops
            p.sparkle = min(1.3, (f - 31) / 3)
        default:
            break
        }
        return p
    }

    /// Template image for the menu bar (macOS tints it for light and dark bars).
    static func image(frame: Int, size: CGFloat = 18) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(pose(frame), in: rect, template: true)
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Colored version for larger places such as the app icon.
    static func colorImage(frame: Int, size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(pose(frame), in: rect, template: false)
            return true
        }
    }

    struct Palette {
        let hull, hullStripe, sail, sailShade, mast, pennant, waterTop, waterBottom, sparkle: NSColor
        static let color = Palette(
            hull: NSColor(srgbRed: 0.80, green: 0.27, blue: 0.22, alpha: 1),
            hullStripe: NSColor(srgbRed: 0.98, green: 0.95, blue: 0.88, alpha: 1),
            sail: NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1),
            sailShade: NSColor(srgbRed: 0.86, green: 0.88, blue: 0.90, alpha: 1),
            mast: NSColor(srgbRed: 0.36, green: 0.27, blue: 0.20, alpha: 1),
            pennant: NSColor(srgbRed: 1.00, green: 0.78, blue: 0.24, alpha: 1),
            waterTop: NSColor(srgbRed: 0.33, green: 0.68, blue: 0.86, alpha: 1),
            waterBottom: NSColor(srgbRed: 0.16, green: 0.45, blue: 0.70, alpha: 1),
            sparkle: NSColor(srgbRed: 1.00, green: 0.96, blue: 0.76, alpha: 1))
        static let template = Palette(hull: .black, hullStripe: .black, sail: .black, sailShade: .black, mast: .black,
                                      pennant: .black, waterTop: .black, waterBottom: .black, sparkle: .black)
    }

    static func draw(_ p: Pose, in rect: NSRect, template: Bool) {
        let c = template ? Palette.template : Palette.color
        let u = rect.width / 18   // design grid: 18 × 18 points
        func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: rect.minX + x * u, y: rect.minY + y * u) }
        func clear(_ body: () -> Void) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            body()
            NSGraphicsContext.restoreGraphicsState()
        }

        // Boat, sailing in from the left and rocking around its keel.
        NSGraphicsContext.saveGraphicsState()
        let shift = (p.enter - 1) * 14
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX + (9 + shift) * u, yBy: rect.minY + 3.4 * u)
        transform.rotate(byDegrees: -p.tilt * 9)
        transform.translateX(by: -(rect.minX + 9 * u), yBy: -(rect.minY + 3.4 * u))
        transform.concat()

        // Mast.
        c.mast.setFill()
        NSBezierPath(rect: NSRect(x: rect.minX + 8.75 * u, y: rect.minY + 5 * u, width: 0.6 * u, height: 11.2 * u)).fill()

        // Pennant at the top, fluttering.
        let tipY = 15.3 + sin(p.flutter) * 0.5
        let pennant = NSBezierPath()
        pennant.move(to: pt(9.35, 16.2))
        pennant.curve(to: pt(12.4, tipY), controlPoint1: pt(10.4, 16.2 + sin(p.flutter + 1) * 0.4), controlPoint2: pt(11.4, tipY + 0.3))
        pennant.line(to: pt(9.35, 15.0))
        pennant.close()
        c.pennant.setFill()
        pennant.fill()

        // Sails, hoisted from the boom upwards.
        if p.sail > 0 {
            let top = 6.2 + 9.2 * p.sail
            let main = NSBezierPath()
            main.move(to: pt(9.6, top))
            main.curve(to: pt(14.6, 6.2), controlPoint1: pt(12.4, top - 3), controlPoint2: pt(14.2, 9))
            main.line(to: pt(9.6, 6.2))
            main.close()
            let jib = NSBezierPath()
            jib.move(to: pt(8.5, top - 1.4 * p.sail))
            jib.line(to: pt(8.5, 6.2))
            jib.line(to: pt(4.2, 6.2))
            jib.curve(to: pt(8.5, top - 1.4 * p.sail), controlPoint1: pt(5.6, 8.6), controlPoint2: pt(7.2, 11))
            jib.close()
            if template {
                NSColor.black.setFill()
                main.fill()
                jib.fill()
            } else {
                NSGradient(colors: [c.sail, c.sailShade])!.draw(in: main, angle: -30)
                NSGradient(colors: [c.sail, c.sailShade])!.draw(in: jib, angle: 210)
            }
        }

        // Hull: a short, round-bottomed boat.
        let hull = NSBezierPath()
        hull.move(to: pt(2.6, 5.6))
        hull.line(to: pt(15.4, 5.6))
        hull.curve(to: pt(12.6, 2.6), controlPoint1: pt(14.9, 4.2), controlPoint2: pt(13.9, 2.9))
        hull.line(to: pt(5.4, 2.6))
        hull.curve(to: pt(2.6, 5.6), controlPoint1: pt(4.1, 2.9), controlPoint2: pt(3.1, 4.2))
        hull.close()
        c.hull.setFill()
        hull.fill()
        let stripe = NSBezierPath(rect: NSRect(x: rect.minX + 3.2 * u, y: rect.minY + 4.4 * u, width: 11.6 * u, height: 0.55 * u))
        if template { clear { stripe.fill() } } else { c.hullStripe.setFill(); stripe.fill() }
        NSGraphicsContext.restoreGraphicsState()

        // Water in front of the hull, with a moving wave edge.
        let water = NSBezierPath()
        water.move(to: pt(0, 0))
        water.line(to: pt(0, 3.0))
        var x: CGFloat = 0
        while x <= 18 {
            water.line(to: pt(x, 3.0 + sin(x / 1.6 + p.wave) * 0.45))
            x += 0.5
        }
        water.line(to: pt(18, 0))
        water.close()
        if template {
            NSColor.black.setFill()
            water.fill()
            // A light wave line inside the water so it reads as water, not as a bar.
            let line = NSBezierPath()
            line.lineWidth = 0.5 * u
            x = 1.5
            line.move(to: pt(x, 1.5 + sin(x / 1.4 + p.wave + 1) * 0.35))
            while x <= 16.5 {
                line.line(to: pt(x, 1.5 + sin(x / 1.4 + p.wave + 1) * 0.35))
                x += 0.5
            }
            clear { line.stroke() }
        } else {
            NSGradient(colors: [c.waterTop, c.waterBottom])!.draw(in: water, angle: -90)
        }

        // Sparkle: the deck is swabbed clean.
        if p.sparkle > 0 {
            let s = 1.6 * p.sparkle
            let cx: CGFloat = 15.6, cy: CGFloat = 13.6
            let star = NSBezierPath()
            star.move(to: pt(cx, cy + s))
            star.curve(to: pt(cx + s, cy), controlPoint1: pt(cx + s * 0.15, cy + s * 0.15), controlPoint2: pt(cx + s * 0.15, cy + s * 0.15))
            star.curve(to: pt(cx, cy - s), controlPoint1: pt(cx + s * 0.15, cy - s * 0.15), controlPoint2: pt(cx + s * 0.15, cy - s * 0.15))
            star.curve(to: pt(cx - s, cy), controlPoint1: pt(cx - s * 0.15, cy - s * 0.15), controlPoint2: pt(cx - s * 0.15, cy - s * 0.15))
            star.curve(to: pt(cx, cy + s), controlPoint1: pt(cx - s * 0.15, cy + s * 0.15), controlPoint2: pt(cx - s * 0.15, cy + s * 0.15))
            c.sparkle.setFill()
            star.fill()
        }
    }
}
