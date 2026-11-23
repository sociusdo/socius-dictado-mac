import SwiftUI
import AppKit

/// Socius branding. `purpleHex` is the single source of truth for the brand
/// color — change it here (or it will be read from UserDefaults key
/// "SociusPurpleHex" if present) and the whole UI updates.
enum Theme {
    /// Elegant default Socius purple. Luis can confirm the exact brand hex;
    /// override at runtime without rebuilding via:
    ///   defaults write com.socius.dictado SociusPurpleHex "#5B21B6"
    static let defaultPurpleHex = "#6D28D9"

    static var purpleHex: String {
        UserDefaults.standard.string(forKey: "SociusPurpleHex") ?? defaultPurpleHex
    }

    static var purple: Color { Color(hex: purpleHex) ?? Color(hex: defaultPurpleHex)! }
    static var purpleDark: Color { purple.opacity(0.85) }

    static let recording = Color(hex: "#EF4444")!   // red while recording
    static let success   = Color(hex: "#22C55E")!   // green ~1s when done
    static let ringTrack = Color.white.opacity(0.25)

    static let nearBlack = Color(hex: "#0B0B0D")!

    /// Modern gradient: the color up top fading to near-black at the bottom.
    /// Derived from any base color, so a custom SociusPurpleHex still looks right.
    static func gradient(for base: Color) -> [Color] {
        [base.adjust(brightness: 0.10), base, nearBlack]
    }
}

extension Color {
    /// Shift brightness (in HSB space) by `delta`, keeping hue/saturation.
    func adjust(brightness delta: CGFloat) -> Color {
        guard let ns = NSColor(self).usingColorSpace(.deviceRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h),
                     saturation: Double(min(1, max(0, s))),
                     brightness: Double(min(1, max(0, b + delta))),
                     opacity: Double(a))
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
