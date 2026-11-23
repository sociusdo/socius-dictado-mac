import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private let controller = DictationController()

    private let collapsed = NSSize(width: 70, height: 70)
    private let expanded  = NSSize(width: 120, height: 210)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.maxX - collapsed.width - 24,
                             y: screen.minY + 90)
        let rect = NSRect(origin: origin, size: collapsed)

        panel = FloatingPanel(contentRect: rect)

        let root = OrbView(controller: controller) { [weak self] expand in
            self?.setExpanded(expand)
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)

        panel.orderFrontRegardless()

        // Ask for Accessibility up front (needed to paste). Non-blocking prompt.
        if !Permissions.accessibilityTrusted() {
            Permissions.requestAccessibility()
        }
    }

    /// Grow the window upward (menu area) on hover; shrink back on exit.
    /// Keeps the orb's horizontal center and bottom edge fixed.
    private func setExpanded(_ expand: Bool) {
        let f = panel.frame
        let target = expand ? expanded : collapsed
        let centerX = f.midX
        let bottomY = f.minY
        let newFrame = NSRect(x: centerX - target.width / 2,
                              y: bottomY,
                              width: target.width,
                              height: target.height)
        panel.setFrame(newFrame, display: true, animate: false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
