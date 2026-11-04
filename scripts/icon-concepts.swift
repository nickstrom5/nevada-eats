// Nevada icon concepts for Nick's pick, in the shared Eats Ranked icon style (state-prompts/ICON-STYLE.md v1):
// one flat, level, centred food on a plain background; no scenery, tilt, texture, gloss or gradients.
// Usage (from nv-eats/): swift scripts/icon-concepts.swift   -> playbook/brand/concept-{a,b,c}-1024.png and -512, -180, -60 copies
//   A  shrimp cocktail in a tulip glass (the downtown casino classic), on flag cobalt
//   B  a slice of prime rib with its fat cap and roasted edge (the casino carving-station classic), on gold
//   C  a stack of silver-dollar pancakes with butter and syrup (the graveyard-shift diner), on Valley of Fire sandstone
// Palettes (the prompt's): cobalt #0047AB, sagebrush #5C6E52, sandstone #C1440E, silver #A7A9AC, gold #F2B705 (fill only).
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let COBALT: UInt32 = 0x0047AB, SAND: UInt32 = 0xC1440E, GOLD: UInt32 = 0xF2B705, SILVER: UInt32 = 0xA7A9AC

// MARK: A, shrimp cocktail (upright: front elevation, CoreGraphics y-up). A silver tulip glass (foot, stem, bowl) holding red cocktail
// sauce, three plump shrimp hooked over the rim. 0.72 tall. Tones: glass #A7A9AC, glass rim #C9CACC (lighter up-facing plane), sauce
// #C1440E, shrimp #F59A74.
func shrimpCocktail(_ c: CGContext, _ s: CGFloat) {
    let dn: CGFloat = 0.035   // the bowl and shrimp carry the mass: the whole glass sits a little low, as the style asks
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: (y - dn) * s) }
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: (y - dn) * s, width: w * s, height: h * s) }
    c.setFillColor(rgb(SILVER))
    // foot and stem
    c.addPath(CGPath(roundedRect: R(0.31, 0.14, 0.38, 0.06), cornerWidth: 0.03 * s, cornerHeight: 0.03 * s, transform: nil)); c.fillPath()
    c.fill(R(0.46, 0.18, 0.08, 0.20))
    // bowl: a tulip, narrow at the stem and widening to the rim
    let bowl = CGMutablePath()
    bowl.move(to: P(0.44, 0.37))
    bowl.addLine(to: P(0.56, 0.37))
    bowl.addCurve(to: P(0.76, 0.66), control1: P(0.70, 0.40), control2: P(0.77, 0.52))
    bowl.addLine(to: P(0.24, 0.66))
    bowl.addCurve(to: P(0.44, 0.37), control1: P(0.23, 0.52), control2: P(0.30, 0.40))
    bowl.closeSubpath()
    c.addPath(bowl); c.fillPath()
    // the sauce fills the top of the bowl; a lighter rim band above it
    c.saveGState(); c.addPath(bowl); c.clip()
    c.setFillColor(rgb(SAND)); c.fill(R(0, 0.47, 1, 0.16))
    c.setFillColor(rgb(0xC9CACC)); c.fill(R(0, 0.63, 1, 0.05))
    c.restoreGState()
    // three shrimp hooked over the rim: thick round-cap arcs
    c.setStrokeColor(rgb(0xF59A74)); c.setLineWidth(0.075 * s); c.setLineCap(.round)
    for (cx, cy, r, a0, a1) in [(0.33, 0.70, 0.075, 0.05, 2.9), (0.50, 0.745, 0.08, 0.15, 3.0), (0.67, 0.70, 0.075, 0.25, 3.1)] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
        c.addArc(center: P(cx, cy), radius: r * s, startAngle: a0, endAngle: a1, clockwise: false); c.strokePath()
    }
}

// MARK: B, prime rib (long food: side elevation of a thick slice, cut face toward us). A roasted brown edge all around, a cream fat
// cap under the top edge, rosy meat below, and the rib bone at the left end. 0.72 wide, 0.42 tall. Tones: roast edge #7E3F22, fat cap
// #F1DDB5 (also the bone), meat #D2645A, meat centre #E2837A.
func primeRib(_ c: CGContext, _ s: CGFloat) {
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    let dn: CGFloat = 0.02
    func Q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { P(x, y - dn) }
    // the slice: a broad rounded slab, a little taller at the left where the eye of the rib sits
    let slab = CGMutablePath()
    slab.move(to: Q(0.20, 0.30))
    slab.addLine(to: Q(0.76, 0.30))
    slab.addCurve(to: Q(0.86, 0.48), control1: Q(0.84, 0.30), control2: Q(0.87, 0.40))
    slab.addCurve(to: Q(0.52, 0.70), control1: Q(0.84, 0.62), control2: Q(0.70, 0.70))
    slab.addCurve(to: Q(0.20, 0.66), control1: Q(0.38, 0.70), control2: Q(0.27, 0.69))
    slab.addCurve(to: Q(0.20, 0.30), control1: Q(0.15, 0.56), control2: Q(0.15, 0.36))
    slab.closeSubpath()
    // the rib bone at the left end, under the slab
    c.setFillColor(rgb(0xF1DDB5))
    c.addPath(CGPath(roundedRect: CGRect(x: 0.14 * s, y: (0.34 - dn) * s, width: 0.12 * s, height: 0.30 * s), cornerWidth: 0.05 * s, cornerHeight: 0.05 * s, transform: nil)); c.fillPath()
    c.setFillColor(rgb(0x7E3F22)); c.addPath(slab); c.fillPath()
    // inside the roasted edge: fat cap above, meat below (one inset shape, split by a curved line)
    let inner = CGMutablePath()
    inner.move(to: Q(0.24, 0.34))
    inner.addLine(to: Q(0.75, 0.34))
    inner.addCurve(to: Q(0.82, 0.48), control1: Q(0.80, 0.34), control2: Q(0.83, 0.41))
    inner.addCurve(to: Q(0.52, 0.66), control1: Q(0.80, 0.59), control2: Q(0.68, 0.66))
    inner.addCurve(to: Q(0.24, 0.62), control1: Q(0.40, 0.66), control2: Q(0.30, 0.65))
    inner.addCurve(to: Q(0.24, 0.34), control1: Q(0.20, 0.54), control2: Q(0.20, 0.38))
    inner.closeSubpath()
    c.setFillColor(rgb(0xF1DDB5)); c.addPath(inner); c.fillPath()
    c.saveGState(); c.addPath(inner); c.clip()
    let meat = CGMutablePath()
    meat.move(to: Q(0.0, 0.0)); meat.addLine(to: Q(1.0, 0.0)); meat.addLine(to: Q(1.0, 0.50))
    meat.addCurve(to: Q(0.0, 0.55), control1: Q(0.70, 0.60), control2: Q(0.35, 0.60))
    meat.closeSubpath()
    c.setFillColor(rgb(0xD2645A)); c.addPath(meat); c.fillPath()
    // the rosier eye of the meat
    c.setFillColor(rgb(0xE2837A)); c.fillEllipse(in: CGRect(x: 0.36 * s, y: (0.38 - dn) * s, width: 0.30 * s, height: 0.14 * s))
    c.restoreGState()
}

// MARK: C, silver-dollar pancakes (front elevation): a stack of five small pancakes, the top one with a lighter up-facing plane, a pat
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

// MARK: - main
let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent().path
let out = root + "/playbook/brand"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func canvas(_ n: Int) -> CGContext {
    let c = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.setAllowsAntialiasing(true); c.setShouldAntialias(true); c.interpolationQuality = .high
    return c
}
func save(_ img: CGImage, _ name: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out + "/" + name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(name)") }
}
for (key, bg, draw) in [("a", COBALT, shrimpCocktail), ("b", GOLD, primeRib), ("c", SAND, pancakes)] as [(String, UInt32, (CGContext, CGFloat) -> Void)] {
    let c = canvas(1024)
    c.setFillColor(rgb(bg)); c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    draw(c, 1024)
    let full = c.makeImage()!
    save(full, "concept-\(key)-1024.png")
    for n in [512, 180, 60] {
        let sm = canvas(n); sm.draw(full, in: CGRect(x: 0, y: 0, width: n, height: n)); save(sm.makeImage()!, "concept-\(key)-\(n).png")
    }
    print("wrote concept-\(key)")
}
