import SwiftUI
import AppKit
import ServiceManagement

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
            w.setContentSize(NSSize(width: 760, height: 560))
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
        .frame(minWidth: 680, minHeight: 500)
    }
}

// MARK: - History

struct HistoryView: View {
    @ObservedObject private var store = TranscriptStore.shared
    @State private var selection: TranscriptItem.ID?
    @State private var search = ""

    private var filtered: [TranscriptItem] {
        guard !search.isEmpty else { return store.items }
        return store.items.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                empty
            } else {
                HSplitView {
                    VStack(spacing: 0) {
                        searchBar
                        list.frame(maxHeight: .infinity)
                    }
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 380)
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            if !store.items.isEmpty {
                ToolbarItemGroup {
                    Button { export() } label: { Label("Exportar", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { store.clearAll(); selection = nil } label: {
                        Label("Borrar todo", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 34, weight: .light)).foregroundStyle(Theme.purple)
            Text("Aún no hay transcripciones").font(.headline)
            Text("Dicta con el círculo (o ⌘⇧Espacio) y aparecerán aquí.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar", text: $search).textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.12))
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(filtered) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(item.text.isEmpty ? "(vacío)" : item.text)
                        .lineLimit(1).font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(Self.dateFmt.string(from: item.date))
                        Text("· \(Self.durationString(item.duration))")
                        Text("· \(item.words) palabras")
                    }
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
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
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title).font(.title3.weight(.semibold)).lineLimit(2)
                HStack(spacing: 10) {
                    Text(Self.dateFmt.string(from: item.date))
                    Text("·"); Text(Self.durationString(item.duration))
                    Text("·"); Text("\(item.words) palabras")
                    Text("·"); Text(item.model.replacingOccurrences(of: "-transcribe", with: ""))
                }
                .font(.system(size: 12)).foregroundStyle(.secondary)

                ScrollView {
                    Text(item.text).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 14))
                }

                HStack {
                    Button { Paster.copyToClipboard(item.text) } label: { Label("Copiar", systemImage: "doc.on.doc") }
                    Spacer()
                    Button(role: .destructive) { store.delete(item); selection = nil } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                }
            }
            .padding(18)
        } else {
            Text("Selecciona una transcripción").foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "socius-dictado.md"
        panel.allowedContentTypes = []
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let md = store.items.map { item in
            "## \(Self.dateFmt.string(from: item.date)) · \(Self.durationString(item.duration)) · \(item.words) palabras\n\n\(item.text)\n"
        }.joined(separator: "\n---\n\n")
        try? md.data(using: .utf8)?.write(to: url)
    }

    static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MM/dd/yy, h:mm a"; return f
    }()
    static func durationString(_ s: TimeInterval) -> String {
        let t = Int(s.rounded()); return t >= 60 ? "\(t / 60)m \(t % 60)s" : "\(t)s"
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject private var store = TranscriptStore.shared
    @AppStorage("SociusModel") private var model = "gpt-4o-mini-transcribe"
    @AppStorage("SociusPurpleHex") private var purpleHex = Theme.defaultPurpleHex
    @AppStorage("SociusAIMode") private var aiMode = AIMode.none.rawValue
    @AppStorage("SociusLanguage") private var language = "auto"
    @AppStorage("SociusSound") private var sound = true
    @AppStorage("SociusDictionary") private var dictionary = ""
    @State private var apiKeyField = ""
    @State private var keyStatus = ""
    @State private var launchAtLogin = SettingsView.loginEnabled()

    var body: some View {
        Form {
            Section("Transcripción") {
                Picker("Modelo", selection: $model) {
                    Text("Rápido  (gpt-4o-mini-transcribe)").tag("gpt-4o-mini-transcribe")
                    Text("Preciso  (gpt-4o-transcribe)").tag("gpt-4o-transcribe")
                }
                Picker("Idioma", selection: $language) {
                    Text("Automático").tag("auto")
                    Text("Español").tag("es")
                    Text("Inglés").tag("en")
                }
                Picker("Modo IA (antes de pegar)", selection: $aiMode) {
                    ForEach(AIMode.allCases) { m in Text(m.title).tag(m.rawValue) }
                }
            }

            Section("Diccionario personal") {
                Text("Un término por línea. Mejora cómo reconoce nombres y marcas (Kommo, Socius, Auto Lujosa…).")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                TextEditor(text: $dictionary)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 90)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
            }

            Section("API key de OpenAI") {
                Text(Keychain.exists() ? "✅ Configurada en el Keychain" : "⚠️ Falta la API key")
                    .font(.system(size: 12)).foregroundStyle(Keychain.exists() ? .green : .orange)
                SecureField("Pegar nueva key (sk-…)", text: $apiKeyField)
                HStack {
                    Button("Guardar key") {
                        let k = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !k.isEmpty else { return }
                        Keychain.set(k); apiKeyField = ""; keyStatus = "Guardada ✓"
                    }
                    .disabled(apiKeyField.isEmpty)
                    if !keyStatus.isEmpty { Text(keyStatus).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
            }

            Section("Atajos de teclado (globales)") {
                LabeledContent("Mostrar / ocultar el círculo", value: "⌘⇧D")
                LabeledContent("Empezar / parar dictado", value: "⌘⇧Espacio")
            }

            Section("General") {
                Toggle("Sonido al empezar y terminar", isOn: $sound)
                Toggle("Arrancar al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in Self.setLogin(newValue) }
            }

            Section("Apariencia") {
                HStack {
                    TextField("Color (hex)", text: $purpleHex).frame(width: 120)
                    RoundedRectangle(cornerRadius: 5).fill(Color(hex: purpleHex) ?? Theme.purple)
                        .frame(width: 26, height: 20)
                    Spacer()
                }
                Text("El círculo toma este color. Reabre la app si no cambia al instante.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Section("Uso (estimado)") {
                let minutes = store.items.reduce(0.0) { $0 + $1.duration } / 60.0
                let cost = store.items.reduce(0.0) { $0 + Self.estCost($1) }
                LabeledContent("Dictados", value: "\(store.items.count)")
                LabeledContent("Minutos transcritos", value: String(format: "%.1f", minutes))
                LabeledContent("Costo aproximado", value: String(format: "$%.3f", cost))
                Text("Estimado de transcripción; el modo IA agrega un costo menor de texto.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Section("Permisos") {
                permissionRow("Accesibilidad (pegar)", Permissions.accessibilityTrusted()) { Permissions.openAccessibilitySettings() }
                permissionRow("Micrófono", Permissions.micAuthorized()) { Permissions.openMicrophoneSettings() }
            }

            Section {
                Button(role: .destructive) { NSApp.terminate(nil) } label: {
                    Label("Salir de Socius Dictado", systemImage: "power")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 6)
    }

    private func permissionRow(_ title: String, _ ok: Bool, _ open: @escaping () -> Void) -> some View {
        HStack {
            Text((ok ? "✅ " : "⚠️ ") + title).foregroundStyle(ok ? .green : .orange)
            Spacer()
            Button("Abrir ajustes", action: open)
        }
    }

    // ~per-minute pricing (approx, USD): mini vs full transcribe.
    static func estCost(_ item: TranscriptItem) -> Double {
        let perMin = item.model.contains("mini") ? 0.003 : 0.006
        return (item.duration / 60.0) * perMin
    }

    static func loginEnabled() -> Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }
    static func setLogin(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
        catch { NSLog("login item error: \(error)") }
    }
}
