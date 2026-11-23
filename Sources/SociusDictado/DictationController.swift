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
    private var lastRecordingURL: URL?
    private var task: Task<Void, Never>?

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
                self.state = .recording
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    private func finishRecordingAndTranscribe() {
        guard let url = recorder.stop() else { state = .idle; return }
        lastRecordingURL = url
        level = 0
        runTranscription(url: url)
    }

    private func runTranscription(url: URL) {
        state = .transcribing
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await self.transcriber.transcribe(url: url)
                if Task.isCancelled { return }
                self.lastTranscript = text
                self.deliver(text)
            } catch {
                if Task.isCancelled { return }
                self.state = .error(self.short(error))
            }
        }
    }

    /// Paste at cursor if a text field is focused; otherwise leave on clipboard.
    private func deliver(_ text: String) {
        if Permissions.accessibilityTrusted(), Paster.hasEditableFocus() {
            Paster.pasteAtCursor(text)
            flashDone(.done)
        } else {
            Paster.copyToClipboard(text)
            flashDone(.copiedOnly)
        }
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
        runTranscription(url: url)
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
}
