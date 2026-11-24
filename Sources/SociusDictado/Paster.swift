import AppKit
import ApplicationServices

enum Paster {
    /// Puts text on the clipboard (does not paste).
    static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// True if the system-wide focused UI element looks like an editable text field.
    static func hasEditableFocus() -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return false }
        let el = element as! AXUIElement

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        if role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
            return true
        }
        // Fallback: the element exposes a settable text value (covers web inputs & editors)
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue {
            return true
        }
        return false
    }

    /// Pastes the text at the current cursor via Cmd+V. The text is expected to
    /// already be on the clipboard (deliver copies it first) and is left there,
    /// so a manual Cmd+V still works if the synthetic one lands nowhere.
    /// Requires Accessibility permission. Returns false if it isn't granted.
    @discardableResult
    static func pasteAtCursor(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        guard let src = CGEventSource(stateID: .combinedSessionState) else { return false }
        let vKey: CGKeyCode = 9 // 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return true
    }
}
