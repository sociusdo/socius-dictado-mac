import Foundation
import Combine

/// A saved snapshot of a transcript's text at a point in time (Google-Docs-style
/// version history). The newest snapshot always matches the item's current text.
struct TranscriptVersion: Codable, Equatable, Identifiable {
    var id = UUID()
    let date: Date
    let text: String
}

/// One saved dictation.
struct TranscriptItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval   // seconds of audio recorded
    let model: String
    var text: String
    var aiTitle: String?         // short AI summary; filled in shortly after saving
    var versions: [TranscriptVersion]?   // edit history; nil for items saved before versioning

    var words: Int {
        text.split { $0 == " " || $0 == "\n" }.count
    }

    /// Version timeline, oldest→newest. Synthesizes a single version from the
    /// current text for old items that predate versioning.
    var versionList: [TranscriptVersion] {
        if let v = versions, !v.isEmpty { return v }
        return [TranscriptVersion(id: id, date: date, text: text)]
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
        let now = Date()
        let item = TranscriptItem(id: UUID(), date: now, duration: duration, model: model,
                                  text: text, aiTitle: nil,
                                  versions: [TranscriptVersion(date: now, text: text)])
        items.insert(item, at: 0)   // newest first
        save()
        return item.id
    }

    func setTitle(id: UUID, _ title: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].aiTitle = title
        save()
    }

    // MARK: - Editing + version history

    /// Live edit: update the current text (no new version). Called as the user types.
    func updateText(id: UUID, _ newText: String) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].text != newText else { return }
        items[i].text = newText
        save()
    }

    /// Snapshot the current text as a new version if it differs from the latest one.
    /// Called when the user finishes an edit (loses focus, leaves the row, or saves).
    func snapshotVersion(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        var vs = items[i].versionList
        let current = items[i].text
        if vs.last?.text != current {
            vs.append(TranscriptVersion(date: Date(), text: current))
            items[i].versions = vs
            save()
        } else if items[i].versions == nil {
            items[i].versions = vs   // persist the synthesized baseline for old items
            save()
        }
    }

    /// Restore a previous version: set it as current and record the restore as a new version.
    func restore(id: UUID, to version: TranscriptVersion) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        var vs = items[i].versionList
        items[i].text = version.text
        if vs.last?.text != version.text {
            vs.append(TranscriptVersion(date: Date(), text: version.text))
        }
        items[i].versions = vs
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
