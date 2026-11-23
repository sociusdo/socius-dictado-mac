import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // agent app: no Dock icon, no menu bar
    app.run()                             // retains `delegate` for the app's lifetime
}
