import NagaCore
import SwiftUI

struct MacrosPanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private var profile: FfiNagaProfile { store.activeProfile }

    var body: some View {
        ScrollView {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("macros.automationEyebrow"))
                                .font(Theme.TypeScale.eyebrow)
                                .foregroundStyle(Theme.text2)
                                .textCase(.uppercase)
                            Text("\(l10n.t("macros.title")) (\(profile.macros.count))")
                                .font(Theme.TypeScale.cardHeadingLarge)
                                .foregroundStyle(Theme.text0)
                        }
                        Spacer()
                        Button {
                            store.addMacro()
                        } label: {
                            Label(l10n.t("macros.newMacro"), systemImage: "plus")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }

                    if profile.macros.isEmpty {
                        VStack(spacing: 6) {
                            Text(l10n.t("macros.emptyTitle"))
                                .font(.system(size: 14, weight: .bold))
                            Text(l10n.t("macros.emptyBody"))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.text2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(profile.macros, id: \.id) { macro in
                                macroCard(macro)
                            }
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.bg0)
    }

    private func macroCard(_ macro: FfiMacro) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("", text: Binding(
                    get: { macro.name },
                    set: { name in
                        var next = macro
                        next.name = name
                        store.updateMacro(next)
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold))

                Picker("", selection: Binding(
                    get: { macro.repeatMode },
                    set: { mode in
                        var next = macro
                        next.repeatMode = mode
                        store.updateMacro(next)
                    }
                )) {
                    ForEach(Constants.repeatModeIds, id: \.self) { mode in
                        Text(l10n.t("macros.repeatModes.\(mode)")).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 130)

                if macro.repeatMode == "count" {
                    TextField(
                        "",
                        value: Binding(
                            get: { Int(macro.repeatCount) },
                            set: { count in
                                var next = macro
                                next.repeatCount = UInt32(max(1, min(999, count)))
                                store.updateMacro(next)
                            }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.plain)
                    .frame(width: 56)
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
                }

                Button {
                    store.removeMacro(macroId: macro.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(l10n.t("macros.deleteMacro"))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(macro.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.text3)
                            Text(stepPreview(step))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(chipColor(step.stepType))
                        .clipShape(Capsule())
                    }
                }
            }

            VStack(spacing: 6) {
                ForEach(macro.steps, id: \.id) { step in
                    StepRowView(
                        step: step,
                        onChange: { store.updateMacroStep(macroId: macro.id, step: $0) },
                        onRemove: { store.removeMacroStep(macroId: macro.id, stepId: step.id) }
                    )
                }
            }

            Button {
                store.addMacroStep(macroId: macro.id)
            } label: {
                Label(l10n.t("macros.addStep"), systemImage: "plus")
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
        .padding(14)
        .background(
            Theme.fillQuiet,
            in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
        )
    }

    private func stepPreview(_ step: FfiMacroStep) -> String {
        switch step.stepType {
        case "delay": return "\(step.delayMs) ms"
        case "text": return "\"\(step.value)\""
        default: return step.value.isEmpty ? step.stepType : step.value
        }
    }

    private func chipColor(_ type: String) -> Color {
        switch type {
        case "delay": return Theme.warn.opacity(0.18)
        case "text": return Theme.info.opacity(0.18)
        case "mouse": return Theme.accent.opacity(0.12)
        default: return Color.primary.opacity(0.06)
        }
    }
}

private struct StepRowView: View {
    @EnvironmentObject private var l10n: L10n

    let step: FfiMacroStep
    let onChange: (FfiMacroStep) -> Void
    let onRemove: () -> Void

    private var placeholder: String {
        switch step.stepType {
        case "text": return l10n.t("macros.stepPlaceholderText")
        case "mouse": return l10n.t("macros.stepPlaceholderMouse")
        default: return l10n.t("macros.stepPlaceholderKey")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { step.stepType },
                set: { type in
                    var next = step
                    next.stepType = type
                    onChange(next)
                }
            )) {
                ForEach(Constants.stepTypeIds, id: \.self) { type in
                    Text(l10n.t("macros.stepTypes.\(type)")).tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            if step.stepType == "delay" {
                TextField(
                    "",
                    value: Binding(
                        get: { Int(step.delayMs) },
                        set: { ms in
                            var next = step
                            next.delayMs = UInt32(max(0, min(5000, ms)))
                            onChange(next)
                        }
                    ),
                    format: .number
                )
                .textFieldStyle(.plain)
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
            } else {
                TextField(placeholder, text: Binding(
                    get: { step.value },
                    set: { value in
                        var next = step
                        next.value = value
                        onChange(next)
                    }
                ))
                .textFieldStyle(.plain)
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
            }

            Button(action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(l10n.t("macros.removeStep"))
        }
    }
}
