import SwiftUI

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
