// Nevada Eats brand: the app icon (Nick's pick 2026-10-27: concept C of scripts/icon-concepts.swift, a stack of five silver-dollar
// pancakes with a butter pat and syrup, on Valley of Fire sandstone; the shared Eats Ranked icon style, state-prompts/ICON-STYLE.md,
// no backing shape). The pancake drawing is copied from icon-concepts.swift unchanged, so the icon is the approved concept.
// Usage, from nv-eats/: swift scripts/make-brand.swift   -> NevadaEats/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png,
// docs/ favicons and touch icons, docs/og.png. scripts/make-site.py draws the same mark as its inline SVG: change both together.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let COBALT: UInt32 = 0x0047AB, SAND: UInt32 = 0xC1440E, SAGE: UInt32 = 0x5C6E52, SILVER: UInt32 = 0xA7A9AC

/// Silver-dollar pancakes (front elevation): a stack of five small pancakes, the top one with a lighter up-facing plane, a pat
// of butter and syrup running down the front. 0.72 wide. Tones: pancake #D99A4A, top plane #EBC07A, seams #B9772F, butter #FFF1B8,
// syrup #6E2F10.
func pancakes(_ c: CGContext, _ s: CGFloat) {
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    let h: CGFloat = 0.085, gap: CGFloat = 0.012, y0: CGFloat = 0.26
    for i in 0..<5 {
        let y = y0 + CGFloat(i) * (h + gap)
        let inset: CGFloat = i % 2 == 0 ? 0 : 0.015
        c.setFillColor(rgb(0xB9772F))   // the seam under each pancake
        c.addPath(CGPath(roundedRect: R(0.14 + inset, y - gap, 0.72 - 2 * inset, h + gap), cornerWidth: h / 2 * s, cornerHeight: h / 2 * s, transform: nil)); c.fillPath()
        c.setFillColor(rgb(0xD99A4A))
        c.addPath(CGPath(roundedRect: R(0.14 + inset, y, 0.72 - 2 * inset, h), cornerWidth: h / 2 * s, cornerHeight: h / 2 * s, transform: nil)); c.fillPath()
    }
    // the top pancake's lighter up-facing plane
    let top = CGPath(roundedRect: R(0.14, y0 + 4 * (h + gap), 0.72, h), cornerWidth: h / 2 * s, cornerHeight: h / 2 * s, transform: nil)
    c.saveGState(); c.addPath(top); c.clip()
    c.setFillColor(rgb(0xEBC07A)); c.fill(R(0, y0 + 4 * (h + gap) + h * 0.5, 1, 1))
    c.restoreGState()
    // syrup over the top and down the front in two runs
    let syrup = CGMutablePath()
    syrup.move(to: P(0.30, y0 + 4 * (h + gap) + h))
    syrup.addLine(to: P(0.70, y0 + 4 * (h + gap) + h))
    syrup.addLine(to: P(0.70, 0.50))
    syrup.addCurve(to: P(0.62, 0.50), control1: P(0.70, 0.455), control2: P(0.62, 0.455))
    syrup.addLine(to: P(0.62, 0.60))
    syrup.addLine(to: P(0.44, 0.60))
    syrup.addLine(to: P(0.44, 0.44))
    syrup.addCurve(to: P(0.36, 0.44), control1: P(0.44, 0.395), control2: P(0.36, 0.395))
    syrup.addLine(to: P(0.36, 0.60))
    syrup.addLine(to: P(0.30, 0.62))
    syrup.closeSubpath()
    c.setFillColor(rgb(0x6E2F10)); c.addPath(syrup); c.fillPath()
    // a pat of butter on top
    c.setFillColor(rgb(0xFFF1B8))
    c.addPath(CGPath(roundedRect: R(0.42, y0 + 4 * (h + gap) + h - 0.01, 0.16, 0.085), cornerWidth: 0.02 * s, cornerHeight: 0.02 * s, transform: nil)); c.fillPath()
}


func render(_ n: Int, _ path: String, background: Bool) {
    let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: background ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    if background { ctx.setFillColor(rgb(SAND)); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n)) }
    pancakes(ctx, CGFloat(n))
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("wrote", path)
}
render(1024, "NevadaEats/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png", background: true)
try? FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
for (n, name) in [(512, "icon-512.png"), (192, "icon-192.png"), (180, "apple-touch-icon.png"), (32, "favicon-32.png")] {
    render(n, "docs/" + name, background: true)
}

/// The share image (1200 x 630): flag cobalt, the pancakes on a sandstone square at the left, the name and tagline at the right, and
/// the Basin and Range ridgeline from the app's Home screen along the bottom over a sandstone band.
func og(_ path: String) {
    let W = 1200, H = 630
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.setFillColor(rgb(COBALT)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    // Basin and Range (CoreGraphics y-up): tilted ranges over flat valleys, silver far ranges and sagebrush near ones, over a sandstone band
    let Wf = CGFloat(W)
    for (pts, hex) in [([(0, 40.0), (90, 40.0), (150, 98.0), (230, 50.0), (300, 40.0), (380, 40.0), (450, 108.0), (560, 54.0), (620, 40.0),
                         (720, 40.0), (790, 90.0), (880, 48.0), (950, 40.0), (1040, 40.0), (1100, 100.0), (1170, 58.0), (1200, 44.0)], SILVER),
                       ([(0, 24.0), (120, 24.0), (190, 62.0), (260, 28.0), (340, 24.0), (470, 24.0), (520, 66.0), (600, 28.0), (680, 24.0),
                         (840, 24.0), (900, 58.0), (980, 28.0), (1060, 24.0), (1200, 24.0)], SAGE)] as [([(CGFloat, CGFloat)], UInt32)] {
        let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 0))
        for (x, y) in pts { p.addLine(to: CGPoint(x: x * Wf / 1200, y: y)) }
        p.addLine(to: CGPoint(x: Wf, y: 0)); p.closeSubpath()
        ctx.setFillColor(rgb(hex)); ctx.addPath(p); ctx.fillPath()
    }
    ctx.setFillColor(rgb(SAND)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: 14))
    // the app icon's sandstone square with the pancakes
    let sq = CGRect(x: 70, y: 150, width: 400, height: 400)
    ctx.saveGState(); ctx.addPath(CGPath(roundedRect: sq, cornerWidth: 88, cornerHeight: 88, transform: nil)); ctx.clip()
    ctx.setFillColor(rgb(SAND)); ctx.fill(sq)
    ctx.translateBy(x: sq.minX, y: sq.minY); pancakes(ctx, 400)
    ctx.restoreGState()
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let title = NSFont(name: "AvenirNextCondensed-Heavy", size: 104) ?? NSFont.boldSystemFont(ofSize: 92)
    let sub = NSFont(name: "AvenirNextCondensed-DemiBold", size: 38) ?? NSFont.boldSystemFont(ofSize: 34)
    NSAttributedString(string: "NEVADA", attributes: [.font: title, .foregroundColor: NSColor.white]).draw(at: NSPoint(x: 520, y: 380))
    NSAttributedString(string: "EATS", attributes: [.font: title, .foregroundColor: NSColor.white]).draw(at: NSPoint(x: 520, y: 270))
    NSAttributedString(string: "RESTAURANTS FROM VEGAS TO TAHOE", attributes: [.font: sub, .foregroundColor: NSColor(srgbRed: 0.973, green: 0.882, blue: 0.839, alpha: 1)]).draw(at: NSPoint(x: 524, y: 214))
    NSGraphicsContext.restoreGraphicsState()
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("wrote", path)
}
og("docs/og.png")
