import AppKit
import SwiftUI

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case done          // green flash
    case copiedOnly    // transcribed but no text field focused -> on clipboard
    case error(String)
    case needsKey
}

@MainActor
final class DictationController: ObservableObject {
    @Published var state: DictationState = .idle
    @Published var level: Float = 0           // 0...1 mic level for animation
    @Published var lastTranscript: String = ""

    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let store = TranscriptStore.shared
    private var lastRecordingURL: URL?
    private var task: Task<Void, Never>?
    private var recordingStarted: Date?
    private var lastDuration: TimeInterval = 0

    /// Set by the AppDelegate so the hover "Abrir" button can open the main window.
    var openMainWindow: (() -> Void)?

    private var currentModel: String {
        UserDefaults.standard.string(forKey: "SociusModel") ?? "gpt-4o-mini-transcribe"
    }

    init() {
        recorder.onLevel = { [weak self] lvl in
            Task { @MainActor in self?.level = lvl }
        }
    }

    // MARK: Primary action (the circle tap)
    func primaryTap() {
        switch state {
        case .idle, .done, .copiedOnly, .error:
            beginRecording()
        case .recording:
            finishRecordingAndTranscribe()
        case .transcribing, .needsKey:
            break
        }
    }

    private func beginRecording() {
        guard Keychain.exists() else { state = .needsKey; presentNeedsKeyAlert(); return }
        Permissions.requestMic { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.state = .error("Falta permiso de micrófono")
                Permissions.openMicrophoneSettings()
                return
            }
            do {
                try self.recorder.start()
                self.recordingStarted = Date()
                self.playSound("Tink")
                self.state = .recording
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    private func finishRecordingAndTranscribe() {
        guard let url = recorder.stop() else { state = .idle; return }
        lastRecordingURL = url
        lastDuration = recordingStarted.map { Date().timeIntervalSince($0) } ?? 0
        recordingStarted = nil
        level = 0
        playSound("Pop")
        runTranscription(url: url, saveToHistory: true)
    }

    private func runTranscription(url: URL, saveToHistory: Bool) {
        state = .transcribing
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let raw = try await self.transcriber.transcribe(url: url)
                if Task.isCancelled { return }
                // Optional AI post-processing (clean / bullets / email / translate).
                let mode = AIMode(rawValue: UserDefaults.standard.string(forKey: "SociusAIMode") ?? "none") ?? .none
                let text = await TextTransformer.apply(mode, to: raw)
                if Task.isCancelled { return }
                self.lastTranscript = text
                if saveToHistory {
                    self.store.add(text: text, duration: self.lastDuration, model: self.currentModel)
                }
                self.deliver(text)
            } catch {
                if Task.isCancelled { return }
                self.state = .error(self.short(error))
            }
        }
    }

    /// Paste at the cursor wherever it is. The transcript is always left on the
    /// clipboard too, so even if the synthetic paste lands nowhere the user can
    /// Cmd+V it manually (and the "Copiar" menu always works).
    private func deliver(_ text: String) {
        Paster.copyToClipboard(text)   // safety net: transcript is always copied

        let trusted = Permissions.accessibilityTrusted()
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        Diag.log("deliver: trusted=\(trusted) front=\(front) chars=\(text.count)")

        guard trusted else {
            // No Accessibility permission -> cannot paste. Copy only + explain.
            flashDone(.copiedOnly)
            presentAccessibilityAlert()
            return
        }
        let ok = Paster.pasteAtCursor(text)   // don't gate on fragile focus detection
        Diag.log("deliver: pasteAtCursor returned \(ok)")
        flashDone(.done)
    }

    private func flashDone(_ s: DictationState) {
        state = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.state == s { self.state = .idle }
        }
    }

    // MARK: Hover menu actions
    func copy() {
        guard !lastTranscript.isEmpty else { return }
        Paster.copyToClipboard(lastTranscript)
        flashDone(.copiedOnly)
    }

    func retry() {
        guard let url = lastRecordingURL else { return }
        runTranscription(url: url, saveToHistory: false)
    }

    func cancel() {
        task?.cancel()
        task = nil
        if recorder.isRecording { recorder.cancel() }
        level = 0
        state = .idle
    }

    // MARK: Setup helpers
    func importKeyFromEnv(_ key: String) {
        Keychain.set(key)
        if state == .needsKey { state = .idle }
    }

    private func presentAccessibilityAlert() {
        Permissions.requestAccessibility()   // adds the app to the list / shows the system prompt
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Falta permiso de Accesibilidad para pegar"
        a.informativeText = """
        Tu texto YA quedó copiado (puedes pegarlo con ⌘V). Para que se pegue solo:

        1. Abre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.
        2. Si ves una entrada vieja "Socius Dictado", quítala con el botón −.
        3. Activa el switch de "Socius Dictado".
        4. Vuelve a dictar: ahora se pegará donde esté el cursor.
        """
        a.alertStyle = .warning
        a.addButton(withTitle: "Abrir Accesibilidad")
        a.addButton(withTitle: "Ahora no")
        if a.runModal() == .alertFirstButtonReturn {
            Permissions.openAccessibilitySettings()
        }
    }

    private func presentNeedsKeyAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Falta la API key de OpenAI"
        a.informativeText = "Corre el instalador una vez para guardar tu key en el Keychain:\n\n  ~/socius-dictado/install.sh\n\nDespués vuelve a hacer clic en el micrófono."
        a.alertStyle = .informational
        a.addButton(withTitle: "Entendido")
        a.runModal()
    }

    private func short(_ error: Error) -> String {
        let m = error.localizedDescription
        return String(m.prefix(80))
    }

    private func playSound(_ name: String) {
        guard UserDefaults.standard.object(forKey: "SociusSound") as? Bool ?? true else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
