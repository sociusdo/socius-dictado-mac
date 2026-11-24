import SwiftUI

/// Custom, non-generic button styles — a filled accent-gradient primary and a
/// tinted secondary — so actions feel designed while staying clean and legible.

struct SociusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accentGradient)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1))
            )
            .opacity(c.isPressed ? 0.88 : 1)
            .scaleEffect(c.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: c.isPressed)
    }
}

struct SociusSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.purple)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.purple.opacity(c.isPressed ? 0.22 : 0.12))
            )
            .scaleEffect(c.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: c.isPressed)
    }
}

extension ButtonStyle where Self == SociusPrimaryButtonStyle {
    static var sociusPrimary: SociusPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == SociusSecondaryButtonStyle {
    static var sociusSecondary: SociusSecondaryButtonStyle { .init() }
}
