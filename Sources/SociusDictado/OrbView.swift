import SwiftUI

struct OrbView: View {
    @ObservedObject var controller: DictationController

    @State private var ringRotation = 0.0

    private let orbSize: CGFloat = 48

    private var busy: Bool {
        controller.state == .recording || controller.state == .transcribing
    }
    // Hover state comes from AppKit (controller.hovering); clicks are handled in
    // AppKit too. SwiftUI here only draws.
    private var showMenu: Bool { (controller.hovering || busy) && !menuItems.isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            if showMenu {
                menu.transition(.opacity)
            }
            orb
        }
        .padding(6)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.easeOut(duration: 0.16), value: showMenu)
    }

    // MARK: Orb
    private var orb: some View {
        ZStack {
            // Modern gradient: color up top fading to near-black at the bottom.
            Circle()
                .fill(LinearGradient(colors: Theme.gradient(for: baseColor),
                                     startPoint: .top, endPoint: .bottom))

            // Subtle same-hue sheen near the top (no white).
            Circle()
                .fill(RadialGradient(colors: [baseColor.adjust(brightness: 0.22).opacity(0.5), .clear],
                                     center: UnitPoint(x: 0.3, y: 0.18),
                                     startRadius: 1, endRadius: orbSize * 0.65))

            if controller.state == .transcribing {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(baseColor.adjust(brightness: 0.4),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: orbSize - 8, height: orbSize - 8)
                    .rotationEffect(.degrees(ringRotation))
            }

            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: controller.state == .recording)
        }
        .frame(width: orbSize, height: orbSize)
        .clipShape(Circle())                       // only the circle — no shadow/shade outside it
        .scaleEffect(controller.state == .recording ? 1.0 + CGFloat(controller.level) * 0.16 : 1.0)
        .animation(.easeOut(duration: 0.08), value: controller.level)
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
        case .recording, .transcribing:
            // While busy, the only action is to stop/cancel.
            return [MenuItem(label: "Cancelar", icon: "xmark", action: controller.cancel)]
        default:
            // At rest (idle / done / copied / error / needs key): just open the window.
            return [MenuItem(label: "Abrir", icon: "macwindow", action: { self.controller.openMainWindow?() })]
        }
    }

    private var menu: some View {
        // Tap gestures (not Buttons): a non-activating panel doesn't make AppKit
        // controls clickable on the first click, but SwiftUI gestures work — same
        // as the orb tap. This is what makes "Cancelar" actually cancel.
        VStack(spacing: 6) {
            ForEach(menuItems) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.icon).font(.system(size: 11, weight: .semibold))
                    Text(item.label).font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Capsule().fill(Color.black.opacity(0.7)))
                // Clicks are handled in AppKit (HitRegionView.onMenuClick); this is
                // visual only.
                .contentShape(Capsule())
            }
        }
        .frame(width: 112)
    }

    // MARK: Appearance
    private var baseColor: Color {
        switch controller.state {
        case .recording: return Theme.recording
        case .done: return Theme.success
        case .copiedOnly: return Theme.warning   // amber: copied but NOT pasted
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
