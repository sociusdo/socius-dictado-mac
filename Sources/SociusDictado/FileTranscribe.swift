import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Transcribes one or more dropped audio files, in the order they were given,
/// and joins them into a single transcript saved to the history with one AI title.
@MainActor
final class FileTranscribeModel: ObservableObject {
    struct Queued: Identifiable, Equatable { let id = UUID(); let url: URL }

    @Published var files: [Queued] = []
    @Published var running = false
    @Published var progress = ""
    @Published var error = ""
    @Published var savedID: UUID?

    private let transcriber = Transcriber()
    private var store: TranscriptStore { TranscriptStore.shared }

    static let audioExts: Set<String> = [
        "m4a", "m4b", "mp3", "mpga", "mpeg", "mpg", "wav", "caf", "aiff", "aif",
        "mp4", "mov", "oga", "ogg", "opus", "flac", "webm", "amr", "3gp",
    ]

    func add(_ urls: [URL]) {
        let have = Set(files.map { $0.url })
        for u in urls where !have.contains(u) && Self.audioExts.contains(u.pathExtension.lowercased()) {
            files.append(Queued(url: u))
        }
    }
    func remove(_ q: Queued) { files.removeAll { $0.id == q.id } }
    func move(from: IndexSet, to: Int) { files.move(fromOffsets: from, toOffset: to) }
    func clear() { files = []; error = ""; progress = ""; savedID = nil }

    func run() {
        guard !running, !files.isEmpty else { return }
        guard Keychain.exists() else { error = "Falta la API key. Agrégala en la pestaña Ajustes."; return }
        running = true; error = ""; progress = ""; savedID = nil
        let queue = files
        let model = UserDefaults.standard.string(forKey: "SociusModel") ?? "gpt-4o-mini-transcribe"
        Task {
            var parts: [String] = []
            var total = 0.0
            do {
                for (i, f) in queue.enumerated() {
                    progress = "Transcribiendo \(i + 1) de \(queue.count): \(f.url.lastPathComponent)"
                    let t = try await transcriber.transcribe(url: f.url)
                    parts.append(t)
                    total += await Self.duration(of: f.url)
                }
            } catch {
                self.error = "Error: \((error as? TranscriberError)?.errorDescription ?? error.localizedDescription)"
                self.running = false; self.progress = ""
                return
            }
            let combined = parts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            self.running = false
            self.progress = ""
            guard !combined.isEmpty else { self.error = "No se obtuvo texto de los archivos."; return }
            let id = store.add(text: combined, duration: total, model: model)
            self.savedID = id
            self.files = []
            Task { if let title = await TextTransformer.title(for: combined) { store.setTitle(id: id, title) } }
        }
    }

    static func duration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        let d = (try? await asset.load(.duration)) ?? .zero
        let s = CMTimeGetSeconds(d)
        return s.isFinite && s > 0 ? s : 0
    }
}

struct FilesTranscribeView: View {
    @StateObject private var model = FileTranscribeModel()
    @ObservedObject private var store = TranscriptStore.shared
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dropZone
            if !model.files.isEmpty { queueList }
            controls
            if model.running {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(model.progress).font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            if !model.error.isEmpty { Text(model.error).font(.system(size: 12)).foregroundStyle(.red) }
            if let id = model.savedID, let item = store.items.first(where: { $0.id == id }) {
                Divider()
                Text("Resultado — ya está en el Historial. Edítalo aquí si quieres.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                TranscriptDetailView(item: item).id(id).frame(minHeight: 240)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in handleDrop(providers); return true }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 30, weight: .light)).foregroundStyle(Theme.purple)
            Text("Arrastra aquí tus audios").font(.headline)
            Text("Uno o varios a la vez. Se transcriben en el orden que los sueltes y se unen en una sola transcripción.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Elegir archivos…") { pick() }.buttonStyle(.sociusSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(targeted ? 0.18 : 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7]))
            .foregroundStyle(targeted ? Theme.purple : Color.gray.opacity(0.4)))
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Orden (\(model.files.count)) — arrastra para reordenar")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            List {
                ForEach(Array(model.files.enumerated()), id: \.element.id) { idx, f in
                    HStack(spacing: 8) {
                        Text("\(idx + 1)").font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.purple).frame(width: 20)
                        Image(systemName: "waveform").foregroundStyle(.secondary)
                        Text(f.url.lastPathComponent).lineLimit(1)
                        Spacer()
                        Button { model.remove(f) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { model.move(from: $0, to: $1) }
            }
            .frame(height: min(CGFloat(model.files.count) * 32 + 12, 190))
        }
    }

    private var controls: some View {
        HStack {
            Button { model.run() } label: {
                Label(model.running ? "Transcribiendo…" : "Transcribir" + (model.files.isEmpty ? "" : " (\(model.files.count))"),
                      systemImage: "waveform")
            }
            .buttonStyle(.sociusPrimary)
            .disabled(model.files.isEmpty || model.running)
            .opacity(model.files.isEmpty || model.running ? 0.5 : 1)

            Button("Limpiar") { model.clear() }
                .buttonStyle(.sociusSecondary)
                .disabled(model.running || (model.files.isEmpty && model.savedID == nil))
            Spacer()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        var urls = [URL?](repeating: nil, count: providers.count)
        let group = DispatchGroup()
        for (i, p) in providers.enumerated() {
            group.enter()
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { itemData, _ in
                defer { group.leave() }
                if let data = itemData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls[i] = url
                } else if let url = itemData as? URL {
                    urls[i] = url
                }
            }
        }
        group.notify(queue: .main) { self.model.add(urls.compactMap { $0 }) }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .movie, .mpeg4Movie, .mp3, .wav]
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK { model.add(panel.urls) }
    }
}
