import SwiftUI

struct OrbView: View {
    @ObservedObject var controller: DictationController
    /// Lets the window grow (menu) / shrink as the pointer enters & leaves.
    var onHover: (Bool) -> Void

    @State private var hovering = false
    @State private var ringRotation = 0.0

    private let orbSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 8) {
            if hovering && !menuItems.isEmpty {
                menu.transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            orb
        }
        .padding(.bottom, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { hovering = h }
            onHover(h)
        }
    }

    // MARK: Orb
    private var orb: some View {
        ZStack {
            // Frosted translucency — the desktop shows through faintly.
            Circle().fill(.ultraThinMaterial)

            // Modern translucent gradient (lighter → base → deeper).
            Circle()
                .fill(LinearGradient(colors: Theme.gradient(for: baseColor),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.82)

            // Glossy top highlight.
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.5), .clear],
                                     center: UnitPoint(x: 0.32, y: 0.22),
                                     startRadius: 1, endRadius: orbSize * 0.7))
                .blendMode(.screen)

            Circle().stroke(Color.white.opacity(0.28), lineWidth: 1)

            if controller.state == .transcribing {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: orbSize - 8, height: orbSize - 8)
                    .rotationEffect(.degrees(ringRotation))
            }

            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: controller.state == .recording)
        }
        .frame(width: orbSize, height: orbSize)
        .shadow(color: baseColor.opacity(0.5), radius: 12, y: 5)
        .scaleEffect(controller.state == .recording ? 1.0 + CGFloat(controller.level) * 0.16 : 1.0)
        .animation(.easeOut(duration: 0.08), value: controller.level)
        .contentShape(Circle())
        .onTapGesture { controller.primaryTap() }
        .onAppear { startRingIfNeeded() }
        .onChange(of: controller.state) { startRingIfNeeded() }
    }

    private func startRingIfNeeded() {
        if controller.state == .transcribing {
            ringRotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }

    // MARK: Hover menu
    private struct MenuItem: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let action: () -> Void
    }

    private var menuItems: [MenuItem] {
        switch controller.state {
        case .recording:
            return [MenuItem(label: "Cancelar", icon: "xmark", action: controller.cancel)]
        case .transcribing:
            return [MenuItem(label: "Cancelar", icon: "xmark", action: controller.cancel)]
        case .done, .copiedOnly, .idle, .error:
            var items: [MenuItem] = []
            if !controller.lastTranscript.isEmpty {
                items.append(MenuItem(label: "Copiar", icon: "doc.on.doc", action: controller.copy))
                items.append(MenuItem(label: "Reintentar", icon: "arrow.clockwise", action: controller.retry))
            }
            items.append(MenuItem(label: "Cancelar", icon: "xmark", action: controller.cancel))
            return items
        case .needsKey:
            return []
        }
    }

    private var menu: some View {
        VStack(spacing: 6) {
            ForEach(menuItems) { item in
                Button(action: item.action) {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 11, weight: .semibold))
                        Text(item.label).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 112)
    }

    // MARK: Appearance
    private var baseColor: Color {
        switch controller.state {
        case .recording: return Theme.recording
        case .done, .copiedOnly: return Theme.success
        case .error: return Theme.recording
        default: return Theme.purple
        }
    }

    private var icon: String {
        switch controller.state {
        case .idle, .needsKey: return "mic.fill"
        case .recording: return "stop.fill"
        case .transcribing: return "mic.fill"
        case .done: return "checkmark"
        case .copiedOnly: return "doc.on.doc.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
