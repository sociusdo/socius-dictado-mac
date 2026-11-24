import SwiftUI

/// The floating orb. At rest it IS the Socius mark (the Ü) — a mini of the app
/// icon — so the brand is always present. State is conveyed around it: a colored
/// ring, audio-level scaling while recording, a spinning arc while transcribing,
/// and a small corner badge for the brief done / copied / error moments.
struct OrbView: View {
    @ObservedObject var controller: DictationController

    @State private var ringRotation = 0.0
    @State private var breathe = false

    private let orbSize: CGFloat = 48

    private var busy: Bool {
        controller.state == .recording || controller.state == .transcribing
    }
    private var showMenu: Bool { (controller.hovering || busy) && !menuItems.isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            if showMenu {
                menu.transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
            }
            orb
        }
        .padding(6)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        // Critically-damped spring (Apple default): graceful, non-distracting.
        .animation(.spring(response: 0.32, dampingFraction: 1.0), value: showMenu)
    }

    // MARK: Orb
    private var orb: some View {
        ZStack {
            markFace
            // State ring — sits on the mark's edge; color says what's happening.
            Circle()
                .strokeBorder(ringColor, lineWidth: ringWidth)
                .frame(width: orbSize, height: orbSize)
                .opacity(ringColor == .clear ? 0 : 1)

            // Transcribing: a spinning arc on top of the ring.
            if controller.state == .transcribing {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Theme.purple.adjust(brightness: 0.35),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .frame(width: orbSize, height: orbSize)
                    .rotationEffect(.degrees(ringRotation))
            }
        }
        .frame(width: orbSize, height: orbSize)
        // Brief completion / warning / error badge in the corner (the Ü stays).
        .overlay(alignment: .bottomTrailing) { badge }
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: controller.state)
        .animation(.easeOut(duration: 0.08), value: controller.level)
        .onAppear { startAnimations() }
        .onChange(of: controller.state) { startAnimations() }
    }

    // The mark's own indigo background — so a smaller centered Ü blends seamlessly.
    private let markBG = Color(hex: "#3B3293")!

    // The Socius mark at 50% size, centered on the matching indigo, circle-clipped,
    // with depth and a light-catching rim.
    private var markFace: some View {
        ZStack {
            markBG
            if let mark = Brand.mark {
                Image(nsImage: mark).resizable().interpolation(.high).scaledToFit()
                    .frame(width: orbSize * 0.75, height: orbSize * 0.75)
            }
        }
        .frame(width: orbSize, height: orbSize)
        .clipShape(Circle())
        .overlay(
            // A faint top-light rim so the orb reads as a physical object.
            // INSIDE the circle only — the panel is transparent, so any shadow or
            // stroke outside the orb would smear onto the desktop. Never add an
            // outer .shadow here.
            Circle().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.03)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
        )
    }

    private var scale: CGFloat {
        switch controller.state {
        case .recording: return 1.0 + CGFloat(controller.level) * 0.16
        default:         return 1.0
        }
    }

    private func startAnimations() {
        if controller.state == .transcribing {
            ringRotation = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }

    // MARK: State styling
    private var ringColor: Color {
        switch controller.state {
        case .recording:   return Theme.recording
        case .transcribing:return Theme.purple.opacity(0.35)
        case .done:        return Theme.success
        case .copiedOnly:  return Theme.warning
        case .error:       return Theme.recording
        default:           return .white.opacity(0.16)   // calm idle rim
        }
    }
    private var ringWidth: CGFloat { busy || isFeedbackState ? 3 : 1.5 }
    private var isFeedbackState: Bool {
        switch controller.state { case .done, .copiedOnly, .error: return true; default: return false }
    }

    @ViewBuilder private var badge: some View {
        if let (glyph, color) = badgeInfo {
            Image(systemName: glyph)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Circle().fill(color))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .offset(x: 3, y: 3)
                .transition(.scale.combined(with: .opacity))
        }
    }
    private var badgeInfo: (String, Color)? {
        switch controller.state {
        case .done:       return ("checkmark", Theme.success)
        case .copiedOnly: return ("doc.on.doc.fill", Theme.warning)
        case .error:      return ("exclamationmark", Theme.recording)
        default:          return nil
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
            return [MenuItem(label: "Cancelar", icon: "xmark", action: controller.cancel)]
        default:
            return [MenuItem(label: "Abrir", icon: "macwindow", action: { self.controller.openMainWindow?() })]
        }
    }

    private var menu: some View {
        // Visual only — clicks are dispatched in AppKit (HitRegionView.onMenuClick).
        VStack(spacing: 6) {
            ForEach(menuItems) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.icon).font(.system(size: 11, weight: .semibold))
                    Text(item.label).font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Capsule().fill(.black.opacity(0.82))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                )
                .contentShape(Capsule())
            }
        }
        .frame(width: 116)
    }
}
