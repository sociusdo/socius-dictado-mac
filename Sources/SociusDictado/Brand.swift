import AppKit

/// The Socius mark (the Ü), bundled into the app at build time as
/// Contents/Resources/SociusMark.png. Loaded once and reused for the orb.
enum Brand {
    static let mark: NSImage? = {
        if let url = Bundle.main.url(forResource: "SociusMark", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }()
}
