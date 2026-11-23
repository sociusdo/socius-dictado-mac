import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var hitView: HitRegionView!
    private let controller = DictationController()

    // Fixed size: orb at the bottom, room above for the hover menu.
    private let panelSize = NSSize(width: 120, height: 210)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.maxX - panelSize.width - 12,
                             y: screen.minY + 70)
        let rect = NSRect(origin: origin, size: panelSize)

        panel = FloatingPanel(contentRect: rect)

        hitView = HitRegionView(frame: NSRect(origin: .zero, size: panelSize))
        hitView.autoresizingMask = [.width, .height]

        let root = OrbView(controller: controller) { [weak self] expand in
            self?.hitView.expanded = expand   // widen click-through while menu is open
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = hitView.bounds
        hosting.autoresizingMask = [.width, .height]
        hitView.addSubview(hosting)

        panel.contentView = hitView
        panel.orderFrontRegardless()

        // Ask for Accessibility up front (needed to paste). Non-blocking prompt.
        if !Permissions.accessibilityTrusted() {
            Permissions.requestAccessibility()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
