import NagaCore
import SwiftUI

struct ProfilesPanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        ScrollView {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("sections.profiles"))
                                .font(Theme.TypeScale.cardHeadingLarge)
                                .foregroundStyle(Theme.text0)
                            Text(l10n.t("profiles.subtitle"))
                                .font(Theme.TypeScale.caption)
                                .foregroundStyle(Theme.text2)
                        }
                        Spacer()
                        Button {
                            Task { await store.createProfile() }
                        } label: {
                            Label(l10n.t("sidebar.addProfile"), systemImage: "plus")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }

                    VStack(spacing: 8) {
                        ForEach(store.store.profiles, id: \.id) { item in
                            profileRow(item)
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.bg0)
    }

    private func profileRow(_ item: FfiNagaProfile) -> some View {
        let isActive = item.id == store.activeProfile.id
        let stageIndex = Int(item.dpi.activeStage) - 1
        let dpi = item.dpi.stages.indices.contains(stageIndex)
            ? item.dpi.stages[stageIndex].x
            : 1800

        return HStack(spacing: 12) {
            Button {
                Task { await store.selectProfile(id: item.id) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(Theme.TypeScale.bodySemibold)
                            .foregroundStyle(Theme.text0)
                        Text("\(dpi) \(l10n.t("sidebar.dpiSuffix")) · \(item.pollingRate)Hz")
                            .font(Theme.TypeScale.caption)
                            .foregroundStyle(Theme.text2)
                            .monospacedDigit()
                    }
                    Spacer()
                    Circle()
                        .fill(Color(hexString: item.rgb.color) ?? Theme.accent)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                isActive ? Theme.accentSoft : Theme.fillQuiet,
                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .strokeBorder(isActive ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.7), lineWidth: 1)
            )

            Button {
                Task { await store.deleteProfile(id: item.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(l10n.t("topbar.delete"))
        }
    }
}
