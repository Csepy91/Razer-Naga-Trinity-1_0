import NagaCore
import SwiftUI

struct PerformancePanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private var profile: FfiNagaProfile { store.activeProfile }
    private var dpi: FfiDpiSettings { profile.dpi }

    private var activeStage: FfiDpiStage {
        let index = Int(dpi.activeStage) - 1
        if dpi.stages.indices.contains(index) {
            return dpi.stages[index]
        }
        return dpi.stages.first ?? FfiDpiStage(id: "s1", x: 1800, y: 1800)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.stackSpacing) {
                dpiCard
                pollingCard
                plateCard
            }
            .padding(Theme.pagePadding)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.automatic)
        .background(Theme.bg0)
    }

    private var dpiCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(l10n.t("performance.sensitivityEyebrow"), systemImage: "scope")
                            .font(Theme.TypeScale.eyebrow)
                            .foregroundStyle(Theme.text2)
                            .labelStyle(.titleAndIcon)
                        Text(l10n.t("performance.dpiStagesTitle"))
                            .font(Theme.TypeScale.cardHeadingLarge)
                            .foregroundStyle(Theme.text0)
                    }
                    Spacer()
                    Button {
                        addStage()
                    } label: {
                        Label(l10n.t("performance.addStage"), systemImage: "plus.circle")
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                    .disabled(dpi.stages.count >= 5)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(activeStage.x)")
                            .font(Theme.TypeScale.valueHero)
                            .foregroundStyle(Theme.text0)
                            .monospacedDigit()
                        Text(l10n.t("performance.activeDpi"))
                            .font(Theme.TypeScale.caption)
                            .foregroundStyle(Theme.text2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("X · \(activeStage.x)")
                        Text("Y · \(activeStage.y)")
                    }
                    .font(Theme.TypeScale.metaMedium)
                    .foregroundStyle(Theme.text1)
                    .monospacedDigit()
                }

                VStack(spacing: 8) {
                    ForEach(Array(dpi.stages.enumerated()), id: \.element.id) { index, stage in
                        stageRow(index: index, stage: stage)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("performance.quickSelect"))
                        .font(Theme.TypeScale.caption)
                        .foregroundStyle(Theme.text2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 6)], spacing: 6) {
                        ForEach(Constants.dpiPresets, id: \.self) { value in
                            Button("\(value)") {
                                applyPreset(value)
                            }
                            .buttonStyle(GhostButtonStyle(compact: true))
                        }
                    }
                }
            }
        }
    }

    private func stageRow(index: Int, stage: FfiDpiStage) -> some View {
        let isActive = index + 1 == Int(dpi.activeStage)
        return HStack(spacing: 10) {
            Button {
                setActiveStage(index)
            } label: {
                Text("\(index + 1)")
                    .font(Theme.TypeScale.metaMedium)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isActive ? Theme.accent : Theme.text1)
                    .background(isActive ? Theme.accentSoft : Theme.fillSubtle)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(isActive ? Theme.accent.opacity(0.55) : Theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.t("performance.stageActivateAria", params: ["n": "\(index + 1)"]))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("X-DPI")
                        .font(Theme.TypeScale.micro)
                        .foregroundStyle(Theme.text2)
                    TextField(
                        "",
                        value: Binding(
                            get: { Int(stage.x) },
                            set: { setStageValue(index: index, value: $0) }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.plain)
                    .font(Theme.TypeScale.bodyMedium)
                    .monospacedDigit()
                    .frame(width: 64)
                    .padding(.horizontal, 6)
                    .frame(height: Theme.Control.heightCompact)
                    .background(Theme.fillSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous)
                            .strokeBorder(Theme.border.opacity(0.8), lineWidth: 1)
                    )
                }
                DpiSlider(
                    value: Binding(
                        get: { Double(stage.x) },
                        set: { setStageValue(index: index, value: Int($0.rounded())) }
                    )
                )
            }

            Button {
                removeStage(id: stage.id)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(IconButtonStyle())
            .disabled(dpi.stages.count <= 1)
            .accessibilityLabel(l10n.t("performance.removeStageAria"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isActive ? Theme.accentSoft : Theme.fillQuiet,
            in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .strokeBorder(isActive ? Theme.accent.opacity(0.45) : Theme.border.opacity(0.65), lineWidth: 1)
        )
    }

    private var pollingCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(l10n.t("performance.responseEyebrow"), systemImage: "gauge.with.dots.needle.67percent")
                        .font(Theme.TypeScale.eyebrow)
                        .foregroundStyle(Theme.text2)
                    Text(l10n.t("performance.pollingTitle"))
                        .font(Theme.TypeScale.cardHeadingLarge)
                        .foregroundStyle(Theme.text0)
                }
                HStack(spacing: 8) {
                    ForEach(Constants.pollingRates, id: \.value) { rate in
                        let isSelected = profile.pollingRate == rate.value
                        Button {
                            store.updateActive { current in
                                var next = current
                                next.pollingRate = rate.value
                                return next
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(rate.label)
                                    .font(Theme.TypeScale.bodySemibold)
                                    .monospacedDigit()
                                    .foregroundStyle(isSelected ? Theme.accent : Theme.text0)
                                Text(l10n.t(rate.sublabelKey))
                                    .font(Theme.TypeScale.micro)
                                    .foregroundStyle(Theme.text2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isSelected ? Theme.accentSoft : Theme.fillQuiet,
                                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Theme.accent.opacity(0.45) : Theme.border.opacity(0.7),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(l10n.t("performance.pollingNote"))
                    .font(Theme.TypeScale.caption)
                    .foregroundStyle(Theme.text3)
            }
        }
    }

    private var plateCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(l10n.t("performance.plateEyebrow"), systemImage: "square.stack.3d.up")
                        .font(Theme.TypeScale.eyebrow)
                        .foregroundStyle(Theme.text2)
                    Text(l10n.t("performance.plateTitle"))
                        .font(Theme.TypeScale.cardHeadingLarge)
                        .foregroundStyle(Theme.text0)
                }
                HStack(spacing: 8) {
                    ForEach(Constants.sidePlateIds, id: \.self) { plate in
                        let isSelected = profile.sidePlate == plate
                        Button {
                            store.setSidePlate(plate)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l10n.t("sidePlates.\(plate).label"))
                                    .font(Theme.TypeScale.bodySemibold)
                                    .foregroundStyle(isSelected ? Theme.accent : Theme.text0)
                                Text(l10n.t("sidePlates.\(plate).subtitle"))
                                    .font(Theme.TypeScale.micro)
                                    .foregroundStyle(Theme.text2)
                                Text("\(Constants.sidePlateButtons[plate] ?? 0) \(l10n.t("performance.plateButtons"))")
                                    .font(Theme.TypeScale.micro)
                                    .foregroundStyle(Theme.text1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                isSelected ? Theme.accentSoft : Theme.fillQuiet,
                                in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Theme.accent.opacity(0.45) : Theme.border.opacity(0.7),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(l10n.t("performance.plateNote"))
                    .font(Theme.TypeScale.caption)
                    .foregroundStyle(Theme.text3)
            }
        }
    }

    private func setStageValue(index: Int, value: Int) {
        let clamped = UInt16(min(16000, max(100, (value / 50) * 50)))
        store.updateActive { current in
            var next = current
            next.dpi.stages = current.dpi.stages.enumerated().map { i, stage in
                guard i == index else { return stage }
                return FfiDpiStage(id: stage.id, x: clamped, y: clamped)
            }
            return next
        }
    }

    private func addStage() {
        guard dpi.stages.count < 5 else { return }
        store.updateActive { current in
            var next = current
            next.dpi.stages.append(
                FfiDpiStage(id: UUID().uuidString.lowercased(), x: 3200, y: 3200)
            )
            return next
        }
    }

    private func removeStage(id: String) {
        guard dpi.stages.count > 1 else { return }
        store.updateActive { current in
            var next = current
            let stages = current.dpi.stages.filter { $0.id != id }
            next.dpi.stages = stages
            next.dpi.activeStage = UInt8(min(Int(current.dpi.activeStage), stages.count))
            if next.dpi.activeStage == 0 { next.dpi.activeStage = 1 }
            return next
        }
    }

    private func setActiveStage(_ index: Int) {
        store.updateActive { current in
            var next = current
            next.dpi.activeStage = UInt8(index + 1)
            return next
        }
    }

    private func applyPreset(_ value: UInt16) {
        store.updateActive { current in
            var next = current
            let activeIndex = Int(current.dpi.activeStage) - 1
            next.dpi.stages = current.dpi.stages.enumerated().map { index, stage in
                guard index == activeIndex else { return stage }
                return FfiDpiStage(id: stage.id, x: value, y: value)
            }
            return next
        }
    }
}
