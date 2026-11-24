import Foundation
import Combine

/// One saved dictation.
struct TranscriptItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval   // seconds of audio recorded
    let model: String
    var text: String

    var words: Int {
        text.split { $0 == " " || $0 == "\n" }.count
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

    func add(text: String, duration: TimeInterval, model: String) {
        let item = TranscriptItem(id: UUID(), date: Date(), duration: duration, model: model, text: text)
        items.insert(item, at: 0)   // newest first
        save()
    }

    func delete(_ item: TranscriptItem) {
        items.removeAll { $0.id == item.id }
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
