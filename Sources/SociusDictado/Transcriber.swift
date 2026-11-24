import AVFoundation
import Foundation

enum TranscriberError: LocalizedError {
    case noAPIKey
    case http(Int, String)
    case emptyResult
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No hay API key de OpenAI configurada."
        case .http(let code, let body): return "OpenAI respondió \(code): \(body)"
        case .emptyResult: return "La transcripción vino vacía."
        case .cancelled: return "Cancelado."
        }
    }
}

/// Transcribes audio with the OpenAI API, mirroring the existing tool:
/// language auto-detected, chunked + parallel for long recordings, retry+backoff.
final class Transcriber {
    static let chunkSeconds: Double = 480     // 8 min per chunk
    static let chunkThreshold: Double = 600   // only split if longer than 10 min
    static let maxConcurrent = 4

    private var model: String {
        UserDefaults.standard.string(forKey: "SociusModel") ?? "gpt-4o-mini-transcribe"
    }

    func transcribe(url: URL) async throws -> String {
        guard let key = Keychain.get(), !key.isEmpty else { throw TranscriberError.noAPIKey }

        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds((try? await asset.load(.duration)) ?? .zero)

        if duration <= Self.chunkThreshold {
            return try await transcribeFile(url, key: key)
        }

        // Split into chunks and transcribe in parallel, preserving order.
        let chunks = try await split(asset: asset, duration: duration)
        defer { chunks.forEach { try? FileManager.default.removeItem(at: $0) } }

        var results = [String](repeating: "", count: chunks.count)
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            var next = 0
            var running = 0
            func submit(_ i: Int) {
                let u = chunks[i]
                group.addTask { (i, try await self.transcribeFile(u, key: key)) }
            }
            while next < chunks.count && running < Self.maxConcurrent {
                submit(next); next += 1; running += 1
            }
            while let (i, text) = try await group.next() {
                results[i] = text
                running -= 1
                if next < chunks.count { submit(next); next += 1; running += 1 }
            }
        }
        return results.joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - One request (with retries)
    private func transcribeFile(_ url: URL, key: String) async throws -> String {
        var lastError: Error = TranscriberError.emptyResult
        for attempt in 0..<6 {
            do {
                return try await postOnce(url, key: key)
            } catch let TranscriberError.http(code, body) {
                lastError = TranscriberError.http(code, body)
                if code == 429 || code >= 500 {
                    try await Task.sleep(nanoseconds: UInt64(min(20.0, pow(2.0, Double(attempt)) + 0.25) * 1_000_000_000))
                    continue
                }
                throw lastError
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: UInt64(min(20.0, pow(2.0, Double(attempt)) + 0.25) * 1_000_000_000))
            }
        }
        throw lastError
    }

    private func postOnce(_ fileURL: URL, key: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        field("model", model)
        field("response_format", "text")

        // Personal dictionary: bias recognition toward the user's terms (names,
        // brands like Kommo / Socius / Auto Lujosa) via the transcription prompt.
        let dict = (UserDefaults.standard.string(forKey: "SociusDictionary") ?? "")
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !dict.isEmpty {
            field("prompt", "Términos y nombres propios: " + dict.joined(separator: ", "))
        }

        // Language: auto-detect unless the user forced one.
        let lang = UserDefaults.standard.string(forKey: "SociusLanguage") ?? "auto"
        if lang == "es" || lang == "en" { field("language", lang) }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw TranscriberError.emptyResult }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw TranscriberError.http(http.statusCode, String(msg.prefix(300)))
        }
        // response_format=text returns raw text (not JSON)
        let text = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriberError.emptyResult }
        return text
    }

    // MARK: - Splitting (native, no ffmpeg dependency)
    private func split(asset: AVURLAsset, duration: Double) async throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("socius-dictado/chunks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var urls: [URL] = []
        var start = 0.0
        var idx = 0
        while start < duration {
            let len = min(Self.chunkSeconds, duration - start)
            let out = dir.appendingPathComponent(String(format: "chunk_%03d.m4a", idx))
            guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw TranscriberError.emptyResult
            }
            export.outputURL = out
            export.outputFileType = .m4a
            export.timeRange = CMTimeRange(
                start: CMTime(seconds: start, preferredTimescale: 600),
                duration: CMTime(seconds: len, preferredTimescale: 600))
            try await export.exportChunk(to: out, as: .m4a)
            urls.append(out)
            start += Self.chunkSeconds
            idx += 1
        }
        return urls
    }
}

// Back-compat shim: use the modern async export when available, fall back otherwise.
private extension AVAssetExportSession {
    func exportChunk(to url: URL, as type: AVFileType) async throws {
        if #available(macOS 15.0, *) {
            try await self.export(to: url, as: type)
        } else {
            self.outputURL = url
            self.outputFileType = type
            await withCheckedContinuation { cont in
                self.exportAsynchronously { cont.resume() }
            }
            if self.status != .completed {
                throw self.error ?? TranscriberError.emptyResult
            }
        }
    }
}
