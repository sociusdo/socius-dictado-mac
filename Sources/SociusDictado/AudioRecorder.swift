import AVFoundation
import Foundation

/// Records the microphone to a compact mono 16kHz AAC .m4a file — the same
/// STT-friendly format the existing OpenAI Transcriber used. No duration limit.
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var outputURL: URL?

    /// Called frequently with a 0...1 level for the waveform/pulse animation.
    var onLevel: ((Float) -> Void)?
    private var levelTimer: Timer?

    var isRecording: Bool { recorder?.isRecording ?? false }

    func start() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("socius-dictado", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("rec-\(Int(Date().timeIntervalSince1970)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.delegate = self
        rec.isMeteringEnabled = true
        guard rec.prepareToRecord(), rec.record() else {
            throw NSError(domain: "SociusDictado", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No se pudo iniciar la grabación."])
        }
        recorder = rec
        outputURL = url

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let r = self.recorder, r.isRecording else { return }
            r.updateMeters()
            // dBFS (-160...0) -> 0...1 with a gentle curve
            let db = r.averagePower(forChannel: 0)
            let norm = max(0, (db + 55) / 55)
            self.onLevel?(norm * norm)
        }
    }

    /// Stops recording and returns the finished file URL.
    func stop() -> URL? {
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        let url = outputURL
        recorder = nil
        return url
    }

    func cancel() {
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        if let url = outputURL { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        outputURL = nil
    }
}
