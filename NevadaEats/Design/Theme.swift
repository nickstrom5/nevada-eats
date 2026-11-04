import SwiftUI
import UIKit
import CoreText

/// Nevada palette (Nick's pick, 2026-10-27), light only: flag cobalt #0047AB (8.4:1 on white) for titles, tint and accents; Valley of
/// Fire sandstone #C1440E (5.1:1 on white, white on it 5.1:1) for the hand-checked Nevada guide cards under white text and for MICHELIN
/// chips; gold #F2B705 and silver #A7A9AC only as fills under dark text (never text); sagebrush #5C6E52 in the header ridgeline. Silver
/// stays secondary so the look never reads as Wolf Pack navy and silver; no team colors or marks (UNLV, Nevada, Raiders, Golden Knights).
/// The names `green`/`gold` are kept from Wisconsin Eats so the shared views read the same; here `green` is cobalt and `gold` sandstone.
enum Theme {
    static let green = Color(hex: 0x0047AB)      // flag cobalt: titles, tint, primary text accents
    static let green2 = Color(hex: 0x1F5FB8)
    static let gold = Color(hex: 0xC1440E)       // Valley of Fire sandstone: card fills under white text, chips
    static let goldSoft = Color(hex: 0xF8E1D6)   // soft sandstone
    static let lime = Color(hex: 0xF2B705)       // gold, fills only (hand-checked pins), under dark text
    static let limeSoft = Color(hex: 0xFCEFC2)
    static let sand = Color(hex: 0xF4F6FA)       // the Home background, a cool off-white
    static let red = Color(hex: 0xC1440E)        // MICHELIN chips (sandstone; white on it 5.1:1)
    static let sage = Color(hex: 0x5C6E52)       // sagebrush, the ridgeline
    static let silver = Color(hex: 0xA7A9AC)     // the far ranges, a fill only
    static let ink = Color(hex: 0x0C1A33)
    static let ink2 = Color(hex: 0x26354F)
    static let muted = Color(hex: 0x56627A)
    static let surface = Color.white
    static let surface2 = Color(hex: 0xF2F4F8)
    static let surface3 = Color(hex: 0xE1E6EF)
    static let rule = Color(hex: 0xDCE2EC)
    static let rule2 = Color(hex: 0xB5C0D3)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// A small uppercase label: "CHINATOWN", "1 MICHELIN STAR".
struct Chip: View {
    enum Style { case gold, green, red, plain, dashed }
    let text: String
    var style: Style = .plain

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.4)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(style == .green || style == .red ? Color.white : style == .dashed ? Theme.muted : style == .gold ? Theme.ink : Theme.green)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(style == .gold ? Theme.goldSoft : style == .green ? Theme.green : style == .red ? Theme.red
                                                       : style == .dashed ? .clear : Theme.surface2)
            }
            .overlay {
                if style == .dashed { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.rule2, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
            }
            .accessibilityLabel(text)
    }
}

/// Nevada Eats' lettering: the system face drawn compressed and heavy for titles and guide names (like a show poster), and the
/// system monospaced face for numbers, dates and small labels. No bundled fonts.
struct DisplayFont: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .black
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.6), weight: weight).width(.compressed))
    }
}

/// Numbers, dates and small labels in the system monospaced face, scaled like DisplayFont.
struct MonoFont: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .semibold
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.6), weight: weight, design: .monospaced))
    }
}

extension View {
    func displayFont(_ size: CGFloat, weight: Font.Weight = .black) -> some View {
        modifier(DisplayFont(size: size, weight: weight))
    }

    func monoFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        modifier(MonoFont(size: size, weight: weight))
    }
}

/// The band under the Home title: Basin and Range. Long tilted ranges over flat valleys, silver far ranges and sagebrush near ones,
/// over a sandstone band, under a thin cobalt rule (the leaderboard's header draws the same ridgeline).
struct Stripes: View {
    var height: CGFloat = 6

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, rule = max(2, h * 0.1), band = max(2, h * 0.12)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: rule)), with: .color(Theme.green))
            // each layer: (x, height above the band) as fractions, west to east: a range rises steeply on one side and falls gently
            // to a flat valley on the other, again and again across the state
            let layers: [([(CGFloat, CGFloat)], Color)] = [
                ([(0, 0.27), (0.075, 0.27), (0.125, 0.85), (0.19, 0.38), (0.25, 0.27), (0.317, 0.27), (0.375, 0.96), (0.467, 0.42),
                  (0.517, 0.27), (0.6, 0.27), (0.658, 0.77), (0.733, 0.35), (0.792, 0.27), (0.867, 0.27), (0.917, 0.88), (0.975, 0.46), (1, 0.31)], Theme.silver),
                ([(0, 0.12), (0.1, 0.12), (0.158, 0.5), (0.217, 0.15), (0.283, 0.12), (0.392, 0.12), (0.433, 0.54), (0.5, 0.15),
                  (0.567, 0.12), (0.7, 0.12), (0.75, 0.46), (0.817, 0.15), (0.883, 0.12), (1, 0.12)], Theme.sage),
            ]
            for (pts, color) in layers {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: h - band))
                for (x, y) in pts { p.addLine(to: CGPoint(x: x * w, y: h - band - y * (h - rule - band))) }
                p.addLine(to: CGPoint(x: w, y: h - band))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
            }
            ctx.fill(Path(CGRect(x: 0, y: h - band, width: w, height: band)), with: .color(Theme.gold))
        }
        .frame(height: height * 4)
        .accessibilityHidden(true)
    }
}

extension View {
    /// An inline navigation title in the display type. UINavigationBar.appearance() didn't reach every SwiftUI bar on iOS 27
    /// (the Map title went from compressed blue to plain black after a push and pop; place titles were always plain), so the
    /// title is our own view in the bar. The navigation title is still set, for the back button and VoiceOver.
    func inlineTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).displayFont(19, weight: .heavy).foregroundStyle(Theme.green)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
