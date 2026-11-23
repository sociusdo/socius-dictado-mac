import AppKit

/// A non-activating, always-on-top panel that shows on every Space and floats
/// above full-screen apps — like the iPhone AssistiveTouch button.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Content view that only "catches" the mouse over the visible orb (idle) or
/// the whole column (while the hover menu is open). Everywhere else clicks pass
/// straight through to the app underneath — so the panel never blocks the corner.
final class HitRegionView: NSView {
    var expanded = false
    private let orbCenterY: CGFloat = 42   // from the bottom edge
    private let orbRadius: CGFloat = 40

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = superview.map { convert(point, from: $0) } ?? point
        if expanded {
            return bounds.contains(p) ? super.hitTest(point) : nil
        }
        let center = CGPoint(x: bounds.midX, y: orbCenterY)
        return hypot(p.x - center.x, p.y - center.y) <= orbRadius ? super.hitTest(point) : nil
    }

    // Allow clicking the orb even when the app isn't active (non-activating panel).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
