import AppKit

/// A non-activating, always-on-top panel that shows on every Space and floats
/// above full-screen apps — like the iPhone AssistiveTouch button.
final class FloatingPanel: NSPanel, NSWindowDelegate {
    private var clamping = false

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
        delegate = self
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Fires on EVERY move (including the system's background drag, which bypasses
    // the setFrame overrides). Snap the orb back inside the visible screen.
    func windowDidMove(_ notification: Notification) {
        guard !clamping else { return }
        let clamped = clampedOrigin(frame.origin)
        if clamped.x != frame.origin.x || clamped.y != frame.origin.y {
            clamping = true
            setFrameOrigin(clamped)
            clamping = false
        }
    }

    // Keep the visible orb fully on screen while dragging. The orb sits at a
    // fixed spot inside this (taller, mostly transparent) panel, so we clamp the
    // window origin by the ORB's rect — not the whole window — otherwise the empty
    // area above the orb counts as "on screen" and the orb slips off the bottom.
    private let orbCenterYFromBottom: CGFloat = 30
    private let orbRadius: CGFloat = 24   // visual radius (orb is 48) so it touches edges exactly

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(clampedOrigin(point))
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var r = frameRect
        r.origin = clampedOrigin(frameRect.origin)
        super.setFrame(r, display: flag)
    }

    private func clampedOrigin(_ p: NSPoint) -> NSPoint {
        // Full screen frame (not visibleFrame) so the orb can rest right at any edge.
        guard let vf = (screen ?? NSScreen.main)?.frame else { return p }
        let cx = frame.width / 2
        let minX = vf.minX - (cx - orbRadius)
        let maxX = vf.maxX - (cx + orbRadius)
        let minY = vf.minY - (orbCenterYFromBottom - orbRadius)
        let maxY = vf.maxY - (orbCenterYFromBottom + orbRadius)
        return NSPoint(x: min(max(p.x, minX), maxX),
                       y: min(max(p.y, minY), maxY))
    }
}

/// Content view that only "catches" the mouse over the visible orb (idle) or
/// the whole column (while the hover menu is open). Everywhere else clicks pass
/// straight through to the app underneath — so the panel never blocks the corner.
final class HitRegionView: NSView {
    var expanded = false
    private let orbCenterY: CGFloat = 30   // from the bottom edge (padding 6 + orb 48/2)
    private let orbRadius: CGFloat = 28

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
