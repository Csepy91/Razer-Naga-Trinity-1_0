import NagaCore
import SwiftUI

struct OverviewPanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private var profile: FfiNagaProfile { store.activeProfile }

    private var activeDpi: UInt16 {
        let index = Int(profile.dpi.activeStage) - 1
        if profile.dpi.stages.indices.contains(index) {
            return profile.dpi.stages[index].x
        }
        return profile.dpi.stages.first?.x ?? 1800
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                hero
                controls
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.bg0)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(store.device.productName ?? "Razer Naga Trinity")
                        .font(Theme.TypeScale.deviceTitle)
                        .foregroundStyle(Theme.text0)
                    statusChip
                }
                Text(l10n.t("effects.\(profile.rgb.effect).label"))
                    .font(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.text2)

                HStack {
                    Spacer(minLength: 0)
                    MouseVisualizerView(profile: profile)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            quickSettings
                .frame(width: 320)
        }
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.device.connected ? Theme.accent : Theme.warn)
                .frame(width: 6, height: 6)
            Text(store.device.connected ? l10n.t("common.connected") : l10n.t("common.disconnected"))
                .font(Theme.TypeScale.micro)
                .foregroundStyle(Theme.text0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            store.device.connected ? Theme.accentSoft : Theme.fillSubtle,
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(
                store.device.connected ? Theme.accent.opacity(0.35) : Theme.border.opacity(0.85),
                lineWidth: 1
            )
        )
    }

    private var quickSettings: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: l10n.t("overview.quickTitle"))
                    .padding(.bottom, 6)

                quickRow(
                    title: l10n.t("overview.dpi"),
                    value: "\(activeDpi) \(l10n.t("sidebar.dpiSuffix"))"
                ) {
                    store.setSection(.performance)
                }
                rowDivider
                quickRow(
                    title: l10n.t("overview.polling"),
                    value: "\(profile.pollingRate) Hz"
                ) {
                    store.setSection(.performance)
                }
                rowDivider
                quickRow(
                    title: l10n.t("overview.sidePlate"),
                    value: l10n.t("sidePlates.\(profile.sidePlate).label")
                ) {
                    store.setSection(.performance)
                }
                rowDivider
                quickRow(
                    title: l10n.t("overview.lighting"),
                    value: l10n.t("effects.\(profile.rgb.effect).label")
                ) {
                    store.setSection(.lighting)
                }

                Button {
                    store.setSection(.lighting)
                } label: {
                    Text(l10n.t("overview.customize"))
                        .font(Theme.TypeScale.bodyMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
                .padding(.top, 14)
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
            .opacity(0.75)
    }

    private func quickRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.text2)
                Spacer(minLength: 8)
                Text(value)
                    .font(Theme.TypeScale.bodyMedium)
                    .foregroundStyle(Theme.text0)
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: Theme.stackSpacing) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: l10n.t("performance.dpiStagesTitle"))
                        Spacer()
                        Text("\(activeDpi)")
                            .font(Theme.TypeScale.valueLarge)
                            .foregroundStyle(Theme.text0)
                            .monospacedDigit()
                        Text(l10n.t("sidebar.dpiSuffix"))
                            .font(Theme.TypeScale.metaMedium)
                            .foregroundStyle(Theme.text2)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(Array(profile.dpi.stages.enumerated()), id: \.element.id) { index, stage in
                            let isActive = index + 1 == Int(profile.dpi.activeStage)
                            Button {
                                store.updateActive { current in
                                    var next = current
                                    next.dpi.activeStage = UInt8(index + 1)
                                    return next
                                }
                            } label: {
                                SelectableTile(selected: isActive) {
                                    VStack(spacing: 4) {
                                        Text(l10n.t("overview.stage", params: ["n": "\(index + 1)"]))
                                            .font(Theme.TypeScale.micro)
                                            .foregroundStyle(isActive ? Theme.accent : Theme.text2)
                                        Text("\(stage.x)")
                                            .font(Theme.TypeScale.valueStage)
                                            .foregroundStyle(Theme.text0)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: l10n.t("performance.pollingTitle"))

                    pollingSelector

                    Text(l10n.t("performance.pollingNote"))
                        .font(Theme.TypeScale.caption)
                        .foregroundStyle(Theme.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 360)
        }
    }

    private var pollingSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(Constants.pollingRates.enumerated()), id: \.element.value) { index, rate in
                let isSelected = profile.pollingRate == rate.value
                Button {
                    store.updateActive { current in
                        var next = current
                        next.pollingRate = rate.value
                        return next
                    }
                } label: {
                    Text(rate.label)
                        .font(Theme.TypeScale.bodyMedium)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Theme.accent : Theme.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Theme.accentSoft : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < Constants.pollingRates.count - 1 {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1)
                        .padding(.vertical, 6)
                }
            }
        }
        .background(Theme.fillQuiet, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
    }
}
