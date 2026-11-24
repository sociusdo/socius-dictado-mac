import SwiftUI
import AppKit

/// Editable transcript view — a notepad you can edit in place. Edits persist as
/// you type; finishing an edit (losing focus / leaving / "Guardar versión")
/// records a version. A clock button opens the Google-Docs-style version history.
struct TranscriptDetailView: View {
    let item: TranscriptItem
    var onDelete: (() -> Void)?
    @ObservedObject private var store = TranscriptStore.shared
    @State private var text: String
    @FocusState private var editing: Bool
    @State private var showVersions = false

    init(item: TranscriptItem, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onDelete = onDelete
        _text = State(initialValue: item.text)
    }

    private var versionCount: Int { item.versions?.count ?? 1 }
    private var wordCount: Int { text.split { $0 == " " || $0 == "\n" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title).font(.title3.weight(.semibold)).lineLimit(2)
                Spacer()
                Button { showVersions = true } label: {
                    Label("Versiones", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.borderless)
                .help("Ver versiones anteriores (como Google Docs)")
            }

            HStack(spacing: 10) {
                Text(HistoryView.dateFmt.string(from: item.date))
                Text("·"); Text(HistoryView.durationString(item.duration))
                Text("·"); Text("\(wordCount) palabras")
                if versionCount > 1 { Text("·"); Text("\(versionCount) versiones") }
            }
            .font(.system(size: 12)).foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.system(size: 14))
                .focused($editing)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: text) { _, new in store.updateText(id: item.id, new) }
                .onChange(of: editing) { _, now in if !now { store.snapshotVersion(id: item.id) } }

            HStack(spacing: 10) {
                Button { Paster.copyToClipboard(text) } label: { Label("Copiar", systemImage: "doc.on.doc") }
                Button { editing = false; store.snapshotVersion(id: item.id) } label: {
                    Label("Guardar versión", systemImage: "square.and.arrow.down")
                }
                Text("Se guarda solo mientras escribes").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                if let onDelete {
                    Button(role: .destructive, action: onDelete) { Label("Borrar", systemImage: "trash") }
                }
            }
        }
        .padding(18)
        .onDisappear { store.snapshotVersion(id: item.id) }
        .sheet(isPresented: $showVersions) {
            VersionHistoryView(item: item) { restored in text = restored }
        }
    }
}

/// Side-by-side version history: list of snapshots on the left (newest first,
/// current one tagged), the chosen snapshot's full text on the right with a
/// "Restaurar" button — mirrors the Google Docs version panel.
struct VersionHistoryView: View {
    let item: TranscriptItem
    var onRestore: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TranscriptStore.shared
    @State private var selectedID: UUID?

    private var versions: [TranscriptVersion] {
        let live = store.items.first(where: { $0.id == item.id })?.versionList ?? item.versionList
        return Array(live.reversed())   // newest first
    }
    private var selected: TranscriptVersion? {
        versions.first(where: { $0.id == selectedID }) ?? versions.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.purple)
                Text("Historial de versiones").font(.headline)
                Spacer()
                Button("Cerrar") { dismiss() }
            }
            .padding(12)
            Divider()

            HSplitView {
                List(versions, selection: $selectedID) { v in
                    let isCurrent = v.id == versions.first?.id
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(Self.fmt.string(from: v.date)).font(.system(size: 12, weight: .medium))
                            if isCurrent {
                                Text("Actual")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Theme.purple.opacity(0.18)).clipShape(Capsule())
                            }
                        }
                        Text(v.text.isEmpty ? "(vacío)" : v.text).lineLimit(1)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(v.id)
                }
                .frame(minWidth: 230, idealWidth: 250, maxWidth: 300)

                VStack(alignment: .leading, spacing: 10) {
                    if let v = selected {
                        ScrollView {
                            Text(v.text).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 13))
                        }
                        HStack {
                            Button { Paster.copyToClipboard(v.text) } label: { Label("Copiar", systemImage: "doc.on.doc") }
                            Spacer()
                            if v.id != versions.first?.id {
                                Button {
                                    store.restore(id: item.id, to: v)
                                    onRestore(v.text)
                                    dismiss()
                                } label: { Label("Restaurar esta versión", systemImage: "arrow.uturn.backward") }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Text("Versión actual").font(.system(size: 11)).foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Text("Selecciona una versión").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 470)
        .onAppear { selectedID = versions.first?.id }
    }

    static let fmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_DO"); f.dateFormat = "d MMM yyyy, h:mm a"; return f
    }()
}
