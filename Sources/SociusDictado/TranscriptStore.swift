import Foundation
import Combine

/// One saved dictation.
struct TranscriptItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval   // seconds of audio recorded
    let model: String
    var text: String
    var aiTitle: String?         // short AI summary; filled in shortly after saving

    var words: Int {
        text.split { $0 == " " || $0 == "\n" }.count
    }

    /// What the UI shows: the AI summary when ready, else a first-line fallback.
    var title: String {
        if let t = aiTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { return t }
        return fallbackTitle
    }

    /// Instant local title (first clause) used until the AI title arrives, and for
    /// old history items that were saved before AI titles existed.
    var fallbackTitle: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "(vacío)" }
        var clause = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        if let end = clause.firstIndex(where: { ".!?".contains($0) }) {
            let head = String(clause[..<end])
            if head.count >= 12 { clause = head }
        }
        let maxLen = 46
        if clause.count <= maxLen { return Self.capFirst(clause) }
        let idx = clause.index(clause.startIndex, offsetBy: maxLen)
        var cut = String(clause[..<idx])
        if let sp = cut.lastIndex(of: " ") { cut = String(cut[..<sp]) }
        return Self.capFirst(cut) + "…"
    }

    private static func capFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}

/// Persists the dictation history to Application Support/SociusDictado/history.json.
@MainActor
final class TranscriptStore: ObservableObject {
    static let shared = TranscriptStore()

    @Published private(set) var items: [TranscriptItem] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let base = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SociusDictado", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("history.json")
        load()
    }

    @discardableResult
    func add(text: String, duration: TimeInterval, model: String) -> UUID {
        let item = TranscriptItem(id: UUID(), date: Date(), duration: duration, model: model, text: text, aiTitle: nil)
        items.insert(item, at: 0)   // newest first
        save()
        return item.id
    }

    func setTitle(id: UUID, _ title: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].aiTitle = title
        save()
    }

    func delete(_ item: TranscriptItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func delete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        save()
    }

    func clearAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([TranscriptItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
