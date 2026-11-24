import SwiftUI
import AppKit

// MARK: - Window host (accessory app has no WindowGroup, so we make an NSWindow)

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let controller: DictationController

    init(controller: DictationController) {
        self.controller = controller
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: MainWindowView(controller: controller))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Socius Dictado"
            w.setContentSize(NSSize(width: 720, height: 520))
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.isReleasedWhenClosed = false
            w.center()
            w.delegate = self
            window = w
        }
        NSApp.setActivationPolicy(.regular)       // show in dock + allow key window while open
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // Back to menu-bar-less accessory once the window is closed (keeps the orb only).
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Root

struct MainWindowView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        TabView {
            HistoryView()
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .frame(minWidth: 640, minHeight: 460)
    }
}

// MARK: - History

struct HistoryView: View {
    @ObservedObject private var store = TranscriptStore.shared
    @State private var selection: TranscriptItem.ID?

    var body: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Theme.purple)
                    Text("Aún no hay transcripciones")
                        .font(.headline)
                    Text("Dicta con el círculo y tus transcripciones aparecerán aquí.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    list
                        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            if !store.items.isEmpty {
                ToolbarItem {
                    Button(role: .destructive) { store.clearAll() } label: {
                        Label("Borrar todo", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(store.items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.text.isEmpty ? "(vacío)" : item.text)
                        .lineLimit(2)
                        .font(.system(size: 13))
                    HStack(spacing: 8) {
                        Text(Self.dateFmt.string(from: item.date))
                        Text("· \(Self.durationString(item.duration))")
                        Text("· \(item.words) palabras")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
                .tag(item.id)
                .contextMenu {
                    Button("Copiar") { Paster.copyToClipboard(item.text) }
                    Button("Borrar", role: .destructive) { store.delete(item) }
                }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let id = selection, let item = store.items.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(Self.dateFmt.string(from: item.date)).font(.headline)
                    Spacer()
                    Text(Self.durationString(item.duration))
                    Text("·")
                    Text("\(item.words) palabras")
                    Text("·")
                    Text(item.model.replacingOccurrences(of: "-transcribe", with: ""))
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

                ScrollView {
                    Text(item.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 14))
                }

                HStack {
                    Button { Paster.copyToClipboard(item.text) } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                    Spacer()
                    Button(role: .destructive) { store.delete(item); selection = nil } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                }
            }
            .padding(18)
        } else {
            Text("Selecciona una transcripción")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es")
        f.dateFormat = "d MMM, h:mm a"
        return f
    }()

    static func durationString(_ s: TimeInterval) -> String {
        let total = Int(s.rounded())
        return total >= 60 ? "\(total / 60)m \(total % 60)s" : "\(total)s"
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("SociusModel") private var model = "gpt-4o-mini-transcribe"
    @AppStorage("SociusPurpleHex") private var purpleHex = Theme.defaultPurpleHex
    @State private var apiKeyField = ""
    @State private var keyStatus = ""

    var body: some View {
        Form {
            Section("Transcripción") {
                Picker("Modelo", selection: $model) {
                    Text("Rápido  (gpt-4o-mini-transcribe)").tag("gpt-4o-mini-transcribe")
                    Text("Preciso  (gpt-4o-transcribe)").tag("gpt-4o-transcribe")
                }
                .pickerStyle(.radioGroup)
            }

            Section("API key de OpenAI") {
                Text(Keychain.exists() ? "✅ Configurada en el Keychain" : "⚠️ Falta la API key")
                    .font(.system(size: 12))
                    .foregroundStyle(Keychain.exists() ? .green : .orange)
                SecureField("Pegar nueva key (sk-…)", text: $apiKeyField)
                HStack {
                    Button("Guardar key") {
                        let k = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !k.isEmpty else { return }
                        Keychain.set(k)
                        apiKeyField = ""
                        keyStatus = "Guardada ✓"
                    }
                    .disabled(apiKeyField.isEmpty)
                    if !keyStatus.isEmpty { Text(keyStatus).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
            }

            Section("Apariencia") {
                HStack {
                    TextField("Color (hex)", text: $purpleHex)
                        .frame(width: 120)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: purpleHex) ?? Theme.purple)
                        .frame(width: 26, height: 20)
                    Spacer()
                }
                Text("El círculo toma este color. Reabre la app si no cambia al instante.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Section("Permisos") {
                HStack {
                    Text(Permissions.accessibilityTrusted() ? "✅ Accesibilidad (pegar)" : "⚠️ Accesibilidad (pegar)")
                        .foregroundStyle(Permissions.accessibilityTrusted() ? .green : .orange)
                    Spacer()
                    Button("Abrir ajustes") { Permissions.openAccessibilitySettings() }
                }
                HStack {
                    Text(Permissions.micAuthorized() ? "✅ Micrófono" : "⚠️ Micrófono")
                        .foregroundStyle(Permissions.micAuthorized() ? .green : .orange)
                    Spacer()
                    Button("Abrir ajustes") { Permissions.openMicrophoneSettings() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 6)
    }
}
