import AppKit
import Carbon.HIToolbox

/// Global keyboard shortcuts via Carbon RegisterEventHotKey. Carbon hotkeys work
/// system-wide, consume the keystroke, and need NO Accessibility permission.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private var counter: UInt32 = 0

    // Defaults: ⌘⇧D show/hide, ⌘⇧Space start/stop dictation.
    static let defVisibleCode = UInt32(kVK_ANSI_D)
    static let defVisibleMods = UInt32(cmdKey | shiftKey)
    static let defDictateCode = UInt32(kVK_Space)
    static let defDictateMods = UInt32(cmdKey | shiftKey)

    private init() {}

    func reload(visibility: @escaping () -> Void, dictation: @escaping () -> Void) {
        installHandler()
        clear()
        let d = UserDefaults.standard
        let vc = UInt32(d.object(forKey: "SociusHKVisibleCode") as? Int ?? Int(Self.defVisibleCode))
        let vm = UInt32(d.object(forKey: "SociusHKVisibleMods") as? Int ?? Int(Self.defVisibleMods))
        let dc = UInt32(d.object(forKey: "SociusHKDictateCode") as? Int ?? Int(Self.defDictateCode))
        let dm = UInt32(d.object(forKey: "SociusHKDictateMods") as? Int ?? Int(Self.defDictateMods))
        add(vc, vm, visibility)
        add(dc, dm, dictation)
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let id = hkID.id
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    mgr.actions[id]?()
                }
            }
            return noErr
        }, 1, &spec, ctx, nil)
        handlerInstalled = true
    }

    private func add(_ keyCode: UInt32, _ modifiers: UInt32, _ action: @escaping () -> Void) {
        counter += 1
        let id = counter
        actions[id] = action
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x53434453), id: id) // 'SCDS'
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }

    private func clear() {
        for r in hotKeyRefs { if let r { UnregisterEventHotKey(r) } }
        hotKeyRefs.removeAll()
        actions.removeAll()
    }
}
