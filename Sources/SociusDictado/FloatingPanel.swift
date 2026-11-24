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
        // Dragging is handled manually in HitRegionView so we can tell a tap
        // (record) from a drag (just move). The system's background drag would
        // swallow that distinction, so it's off.
        isMovableByWindowBackground = false
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
/// Owns ALL mouse handling for the orb + hover menu. SwiftUI only draws; clicks
/// are dispatched here in AppKit, because SwiftUI tap gestures never fired in this
/// borderless, non-activating panel. Hover is detected with a tracking area.
final class HitRegionView: NSView {
    var isMenuOpen: () -> Bool = { false }     // hovering OR recording/transcribing
    var onOrbClick: () -> Void = {}
    var onMenuClick: () -> Void = {}
    var onHoverChange: (Bool) -> Void = { _ in }

    private let orbCenterY: CGFloat = 30       // from the bottom edge (padding 6 + orb 48/2)
    private let orbRadius: CGFloat = 28
    private var hoverArea: NSTrackingArea?

    // Tap-vs-drag tracking. A press that moves more than `dragThreshold` points
    // is a drag (just move the orb); a press that doesn't is a tap (record / menu).
    private let dragThreshold: CGFloat = 4
    private var pressMouse: NSPoint?           // global screen point at mouseDown
    private var pressOrigin: NSPoint = .zero    // window origin at mouseDown
    private var didDrag = false
    private var downInOrb = false
    private var downInMenu = false

    // Interactive column at the bottom-center (orb + room for the menu above it).
    private var columnRect: CGRect {
        CGRect(x: bounds.midX - 60, y: 0, width: 120, height: 112)
    }
    private func inOrb(_ p: CGPoint) -> Bool {
        hypot(p.x - bounds.midX, p.y - orbCenterY) <= orbRadius
    }
    private func inMenu(_ p: CGPoint) -> Bool {
        isMenuOpen() && columnRect.contains(p) && p.y > orbCenterY + orbRadius
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = superview.map { convert(point, from: $0) } ?? point
        // Return self (not the SwiftUI subview) so WE get mouseDown. Everywhere
        // else returns nil so clicks pass through to the app underneath.
        return (inOrb(p) || inMenu(p)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        downInOrb = inOrb(p)
        downInMenu = inMenu(p)
        pressMouse = NSEvent.mouseLocation          // global, stays valid as window moves
        pressOrigin = window?.frame.origin ?? .zero
        didDrag = false
        // Don't act yet — wait for mouseUp to know if this was a tap or a drag.
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressMouse, let win = window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.x
        let dy = now.y - start.y
        if !didDrag && hypot(dx, dy) > dragThreshold { didDrag = true }
        if didDrag {
            win.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressMouse = nil }
        // A drag just moved the orb — never start a recording from it.
        guard !didDrag else { return }
        if downInOrb {
            onOrbClick()
        } else if downInMenu {
            onMenuClick()
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Hover detection for revealing the menu at rest.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let a = hoverArea { removeTrackingArea(a) }
        let a = NSTrackingArea(rect: columnRect,
                               options: [.activeAlways, .mouseEnteredAndExited, .enabledDuringMouseDrag],
                               owner: self, userInfo: nil)
        addTrackingArea(a)
        hoverArea = a
    }
    override func mouseEntered(with event: NSEvent) { onHoverChange(true) }
    override func mouseExited(with event: NSEvent) { onHoverChange(false) }
}
