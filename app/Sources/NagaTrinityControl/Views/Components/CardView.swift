import SwiftUI

struct CardView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.TypeScale.cardHeading)
                .foregroundStyle(Theme.text0)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.TypeScale.caption)
                    .foregroundStyle(Theme.text2)
            }
        }
    }
}

struct BadgeView: View {
    let text: String
    var muted: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.TypeScale.micro)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(muted ? Theme.text2 : Theme.accent)
            .background(muted ? Theme.fillSubtle : Theme.accentSoft)
            .clipShape(Capsule())
    }
}

/// Selectable tile — selected state uses a precise accent border, not a saturated fill.
struct SelectableTile<Content: View>: View {
    let selected: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(
                selected ? Theme.accentSoft : Theme.fillQuiet,
                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.55) : Theme.border.opacity(0.65), lineWidth: 1)
            )
    }
}

/// Quiet interactive row used in quick-settings lists.
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Theme.fillHover : Color.clear
            )
            .animation(Theme.animFast, value: configuration.isPressed)
    }
}
