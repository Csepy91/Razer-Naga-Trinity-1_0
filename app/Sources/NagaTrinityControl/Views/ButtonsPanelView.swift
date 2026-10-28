import NagaCore
import SwiftUI

struct ButtonsPanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private var profile: FfiNagaProfile { store.activeProfile }

    private var baseButtons: [FfiButtonBinding] {
        profile.buttons.filter { $0.id.hasPrefix("base-") }
    }

    private var sideButtons: [FfiButtonBinding] {
        profile.buttons.filter { $0.id.hasPrefix("side-") }
    }

    private var plateBadge: String {
        switch profile.sidePlate {
        case "twelve": return "MMO"
        case "seven": return "MOBA"
        default: return "FPS"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.stackSpacing) {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n.t("buttons.baseEyebrow"))
                                    .font(Theme.TypeScale.eyebrow)
                                    .foregroundStyle(Theme.text2)
                                    .textCase(.uppercase)
                                Text(l10n.t("buttons.baseTitle"))
                                    .font(Theme.TypeScale.cardHeadingLarge)
                                    .foregroundStyle(Theme.text0)
                            }
                            Spacer()
                            BadgeView(
                                text: "\(baseButtons.count) \(l10n.t("buttons.bindings"))",
                                muted: true
                            )
                        }
                        VStack(spacing: 8) {
                            ForEach(baseButtons, id: \.id) { button in
                                BindingRowView(binding: button, macros: profile.macros, onChange: updateButton)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(l10n.t("buttons.sidePlateEyebrow")) \(profile.sidePlate.uppercased())")
                                    .font(Theme.TypeScale.eyebrow)
                                    .foregroundStyle(Theme.text2)
                                    .textCase(.uppercase)
                                Text(l10n.t("buttons.sideTitle", params: ["count": "\(sideButtons.count)"]))
                                    .font(Theme.TypeScale.cardHeadingLarge)
                                    .foregroundStyle(Theme.text0)
                            }
                            Spacer()
                            BadgeView(text: plateBadge, muted: true)
                        }
                        VStack(spacing: 8) {
                            ForEach(sideButtons, id: \.id) { button in
                                BindingRowView(binding: button, macros: profile.macros, onChange: updateButton)
                            }
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.bg0)
    }

    private func updateButton(_ next: FfiButtonBinding) {
        store.updateActive { current in
            var updated = current
            updated.buttons = current.buttons.map { $0.id == next.id ? next : $0 }
            return updated
        }
    }
}

private struct BindingRowView: View {
    @EnvironmentObject private var l10n: L10n

    let binding: FfiButtonBinding
    let macros: [FfiMacro]
    let onChange: (FfiButtonBinding) -> Void

    private var showInput: Bool {
        binding.action == "key" || binding.action == "mouse-button" || binding.action == "macro"
    }

    private var displayLabel: String {
        let key = "buttons.labels.\(binding.id)"
        return l10n.exists(key) ? l10n.t(key) : binding.label
    }

    /// Side-panel ordinal (1…N) so remapping matches the mouse visualizer labels.
    /// Base buttons keep their stored hardware index.
    private var indexBadge: Int {
        if binding.id.hasPrefix("side-"), let n = Int(binding.id.dropFirst(5)) {
            return n
        }
        return Int(binding.hardwareIndex)
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("#\(indexBadge)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.text3)
                    .frame(width: 28, alignment: .leading)
                Text(displayLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text0)
                    .lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)

            Picker("", selection: actionBinding) {
                ForEach(Constants.buttonActionIds, id: \.self) { action in
                    Text(l10n.t("actions.\(action)")).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 160)

            valueControl
                .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(
            Theme.fillQuiet,
            in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
        )
    }

    private var actionBinding: Binding<String> {
        Binding(
            get: { binding.action },
            set: { newAction in
                var next = binding
                next.action = newAction
                if newAction == "mouse-button" {
                    next.value = "Mouse 4"
                }
                onChange(next)
            }
        )
    }

    @ViewBuilder
    private var valueControl: some View {
        if showInput && binding.action == "macro" {
            Picker("", selection: macroBinding) {
                Text(l10n.t("buttons.macroPick")).tag("")
                ForEach(macros, id: \.id) { macro in
                    Text(macro.name).tag(macro.id)
                }
            }
            .labelsHidden()
        } else if showInput && binding.action == "mouse-button" {
            Picker("", selection: valueBinding) {
                ForEach(Constants.mouseButtons, id: \.self) { mouseButton in
                    Text(mouseButton).tag(mouseButton)
                }
            }
            .labelsHidden()
        } else if showInput {
            TextField(
                binding.action == "key" ? l10n.t("buttons.keyPlaceholder") : "Mouse 4",
                text: valueBinding
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
        } else {
            Text(binding.value.isEmpty ? "—" : binding.value)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { binding.value },
            set: { newValue in
                var next = binding
                next.value = newValue
                onChange(next)
            }
        )
    }

    private var macroBinding: Binding<String> {
        Binding(
            get: { binding.macroId ?? "" },
            set: { newValue in
                var next = binding
                next.macroId = newValue.isEmpty ? nil : newValue
                next.value = newValue
                onChange(next)
            }
        )
    }
}
