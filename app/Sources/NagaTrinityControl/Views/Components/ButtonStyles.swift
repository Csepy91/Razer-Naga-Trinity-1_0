import SwiftUI

/// Dense panel controls with shared height / padding / radius tokens.
/// Prefer native `.bordered` / `.borderedProminent` in chrome toolbars.

struct GhostButtonStyle: ButtonStyle {
    var compact: Bool = false
    var danger: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .padding(.horizontal, compact ? Theme.Control.horizontalPaddingCompact : Theme.Control.horizontalPadding)
            .frame(minHeight: compact ? Theme.Control.heightCompact : Theme.Control.height)
            .foregroundStyle(foreground(configuration))
            .background(
                background(configuration),
                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .strokeBorder(Theme.border.opacity(configuration.isPressed ? 0.95 : 0.75), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .animation(Theme.animFast, value: configuration.isPressed)
    }

    private func foreground(_ configuration: ButtonStyleConfiguration) -> Color {
        if danger { return Theme.danger }
        return configuration.isPressed ? Theme.text0 : Theme.text1
    }

    private func background(_ configuration: ButtonStyleConfiguration) -> Color {
        configuration.isPressed ? Theme.fillHover : Theme.fillSubtle
    }
}

struct SoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, Theme.Control.horizontalPadding)
            .frame(minHeight: Theme.Control.height)
            .foregroundStyle(Theme.text0)
            .background(
                Theme.accentSoft.opacity(configuration.isPressed ? 1.4 : 1),
                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(configuration.isPressed ? 0.4 : 0.28), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .animation(Theme.animFast, value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: Theme.Control.height)
            .foregroundStyle(Theme.accentOnAccent)
            .background(
                (disabled ? Theme.accent.opacity(0.45) : Theme.accent)
                    .opacity(configuration.isPressed ? 0.88 : 1),
                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
            )
            .animation(Theme.animFast, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(configuration.isPressed ? Theme.text0 : Theme.text2)
            .frame(width: Theme.Control.heightIcon, height: Theme.Control.heightIcon)
            .background(
                (configuration.isPressed ? Theme.fillHover : Theme.fillSubtle),
                in: RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Theme.animFast, value: configuration.isPressed)
    }
}
