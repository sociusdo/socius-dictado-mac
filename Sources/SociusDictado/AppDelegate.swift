import AppKit
import SwiftUI

/// NSHostingView that accepts the first click in a non-activating (background)
/// window. Without this, the panel never becomes key, so SwiftUI's first click on
/// a transient view (the hover menu) is swallowed to "activate" and the tap is
/// lost — which is why "Cancelar" never fired.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) { super.init(rootView: rootView) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var hitView: HitRegionView!
    private let controller = DictationController()
    private lazy var mainWindow = MainWindowController(controller: controller)

    // Fixed size: orb at the bottom, room above for the hover menu.
    private let panelSize = NSSize(width: 120, height: 210)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One-time silent migration: if launched with SOCIUS_SEED_KEY, the APP writes
        // the key to the Keychain so the app owns the item. An app-owned item is read
        // back with no password prompt, ever — including after a reboot.
        if let seed = ProcessInfo.processInfo.environment["SOCIUS_SEED_KEY"], !seed.isEmpty {
            Keychain.set(seed)
        }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // Bottom-right, clearly inside the visible area (above the Dock).
        let origin = NSPoint(x: screen.maxX - panelSize.width - 16,
                             y: screen.minY + 24)
        let rect = NSRect(origin: origin, size: panelSize)

        panel = FloatingPanel(contentRect: rect)

        hitView = HitRegionView(frame: NSRect(origin: .zero, size: panelSize))
        hitView.autoresizingMask = [.width, .height]
        // All clicks handled in AppKit (SwiftUI taps never fired in this panel).
        hitView.isMenuOpen = { [weak self] in
            guard let self else { return false }
            return self.controller.hovering
                || self.controller.state == .recording
                || self.controller.state == .transcribing
        }
        hitView.onOrbClick = { [weak self] in self?.controller.primaryTap() }
        hitView.onMenuClick = { [weak self] in self?.controller.menuAction() }
        hitView.onHoverChange = { [weak self] h in self?.controller.hovering = h }

        controller.openMainWindow = { [weak self] in self?.mainWindow.show() }

        let root = OrbView(controller: controller)
        let hosting = FirstMouseHostingView(rootView: root)
        hosting.frame = hitView.bounds
        hosting.autoresizingMask = [.width, .height]
        hitView.addSubview(hosting)

        panel.contentView = hitView
        panel.orderFrontRegardless()

        setupMenu()

        // Global shortcuts: ⌘⇧D show/hide, ⌘⇧Space start/stop dictation.
        HotKeyManager.shared.reload(
            visibility: { [weak self] in self?.toggleVisibility() },
            dictation:  { [weak self] in self?.controller.primaryTap() })

        // Log the Accessibility state at launch so we can confirm (not guess)
        // whether a granted permission actually took effect for this process.
        let trusted = Permissions.accessibilityTrusted()
        Diag.log("launch: AXIsProcessTrusted=\(trusted) path=\(Bundle.main.bundlePath)")
        // If not trusted, register with TCC now (adds the app to the list with the
        // CURRENT, stable signature). Once granted + relaunched, this never fires.
        if !trusted { Permissions.requestAccessibility() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Actions used by hotkeys / menu

    func toggleVisibility() {
        if panel.isVisible { panel.orderOut(nil) }
        else { panel.orderFrontRegardless() }
    }

    @objc func openWindowAction() { mainWindow.show() }
    @objc func showOrbAction() { panel.orderFrontRegardless() }

    /// Minimal menu so ⌘Q / ⌘W behave and there's a discoverable Quit + Open.
    private func setupMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Abrir Socius Dictado", action: #selector(openWindowAction), keyEquivalent: "o")
        appMenu.addItem(withTitle: "Mostrar el círculo", action: #selector(showOrbAction), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Salir de Socius Dictado", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // Standard Edit menu so Cmd+C/V/X/A work inside the window.
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edición")
        edit.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }
}
