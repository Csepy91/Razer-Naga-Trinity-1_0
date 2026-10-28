import AppKit
import NagaCore
import SwiftUI

struct LightingPanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private var rgb: FfiRgbSettings { store.activeProfile.rgb }

    private var usesSecondary: Bool { rgb.effect == "breathing" }
    private var usesWaveDirection: Bool { rgb.effect == "wave" }
    private var usesReactiveSpeed: Bool { rgb.effect == "reactive" }
    private var supportsColor: Bool {
        rgb.effect == "static" || rgb.effect == "breathing" || rgb.effect == "reactive"
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 240), spacing: 16),
                    GridItem(.flexible(minimum: 280), spacing: 16),
                ],
                spacing: 16
            ) {
                previewCard
                effectsCard
                colorCard
                zonesCard
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.bg0)
    }

    private var previewCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                cardHead(
                    eyebrow: l10n.t("lighting.livePreviewEyebrow"),
                    title: l10n.t("lighting.livePreviewTitle"),
                    trailing: {
                        BadgeView(text: l10n.t("effects.\(rgb.effect).label"))
                    }
                )
                HStack {
                    Spacer()
                    MouseVisualizerView(profile: store.activeProfile)
                    Spacer()
                }
                Text(l10n.t("effects.\(rgb.effect).description"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)
            }
        }
    }

    private var effectsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                cardHead(
                    eyebrow: l10n.t("lighting.effectEyebrow"),
                    title: l10n.t("lighting.effectTitle")
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(Constants.rgbEffectIds, id: \.self) { effectId in
                        let isSelected = rgb.effect == effectId
                        Button {
                            store.updateRgb { current in
                                var next = current
                                next.effect = effectId
                                return next
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l10n.t("effects.\(effectId).label"))
                                    .font(Theme.TypeScale.bodySemibold)
                                    .foregroundStyle(isSelected ? Theme.accent : Theme.text0)
                                Text(l10n.t("effects.\(effectId).description"))
                                    .font(Theme.TypeScale.micro)
                                    .foregroundStyle(Theme.text2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
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
            }
        }
    }

    private var colorCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                cardHead(
                    eyebrow: l10n.t("lighting.colorEyebrow"),
                    title: l10n.t("lighting.primaryColor"),
                    trailing: {
                        Text(rgb.color.uppercased())
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text1)
                    }
                )

                colorRow(
                    color: rgb.color,
                    selected: rgb.color,
                    disabled: !supportsColor && rgb.effect != "spectrum",
                    aria: l10n.t("lighting.colorAria")
                ) { hex in
                    store.updateRgb { current in
                        var next = current
                        next.color = hex
                        return next
                    }
                }

                if usesSecondary {
                    cardHead(
                        eyebrow: l10n.t("lighting.colorEyebrow"),
                        title: l10n.t("lighting.secondaryColor"),
                        trailing: {
                            Text(rgb.secondaryColor.uppercased())
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.text1)
                        }
                    )
                    colorRow(
                        color: rgb.secondaryColor,
                        selected: rgb.secondaryColor,
                        disabled: false,
                        aria: l10n.t("lighting.secondaryColorAria")
                    ) { hex in
                        store.updateRgb { current in
                            var next = current
                            next.secondaryColor = hex
                            return next
                        }
                    }
                }

                HStack {
                    Text(l10n.t("lighting.brightness"))
                        .foregroundStyle(Theme.text1)
                    Slider(
                        value: Binding(
                            get: { Double(rgb.brightness) },
                            set: { value in
                                store.updateRgb { current in
                                    var next = current
                                    next.brightness = UInt8(value.rounded())
                                    return next
                                }
                            }
                        ),
                        in: 0...100
                    )
                    .tint(Theme.accent)
                    Text("\(rgb.brightness)%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 44, alignment: .trailing)
                }

                if usesWaveDirection {
                    segmentControl(
                        label: l10n.t("lighting.waveDirection"),
                        options: [
                            ("left", l10n.t("lighting.waveLeft")),
                            ("right", l10n.t("lighting.waveRight")),
                        ],
                        selected: rgb.waveDirection
                    ) { direction in
                        store.updateRgb { current in
                            var next = current
                            next.waveDirection = direction
                            return next
                        }
                    }
                }

                if usesReactiveSpeed {
                    segmentControl(
                        label: l10n.t("lighting.reactiveSpeed"),
                        options: Constants.reactiveSpeeds.map {
                            (String($0.value), l10n.t($0.labelKey))
                        },
                        selected: String(rgb.reactiveSpeed)
                    ) { value in
                        store.updateRgb { current in
                            var next = current
                            next.reactiveSpeed = UInt8(value) ?? current.reactiveSpeed
                            return next
                        }
                    }
                }
            }
        }
    }

    private var zonesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardHead(
                        eyebrow: l10n.t("lighting.zonesEyebrow"),
                        title: l10n.t("lighting.zonesTitle")
                    )
                    Spacer()
                    Button {
                        store.updateRgb { current in
                            var next = current
                            next.syncZones = !current.syncZones
                            return next
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: rgb.syncZones ? "link" : "link.badge.plus")
                            Text(rgb.syncZones ? l10n.t("lighting.zonesSync") : l10n.t("lighting.zonesIndividual"))
                        }
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(Constants.zoneIds, id: \.self) { zoneId in
                        zoneTile(zoneId)
                    }
                }
            }
        }
    }

    private func zoneTile(_ zoneId: String) -> some View {
        let config: FfiZoneConfig = {
            switch zoneId {
            case "logo": return rgb.zones.logo
            case "scroll": return rgb.zones.scroll
            default: return rgb.zones.side
            }
        }()
        let colorValue = rgb.syncZones ? rgb.color : config.color
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("zones.\(zoneId).label"))
                        .font(.system(size: 13, weight: .bold))
                    Text(l10n.t("zones.\(zoneId).description"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text2)
                }
                Spacer()
                Button {
                    store.updateRgb { current in
                        var next = current
                        switch zoneId {
                        case "logo":
                            next.zones.logo.enabled.toggle()
                        case "scroll":
                            next.zones.scroll.enabled.toggle()
                        default:
                            next.zones.side.enabled.toggle()
                        }
                        return next
                    }
                } label: {
                    Image(systemName: config.enabled ? "eye" : "eye.slash")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel(
                    "\(l10n.t("zones.\(zoneId).label")) \(config.enabled ? l10n.t("lighting.zoneDeactivate") : l10n.t("lighting.zoneActivate"))"
                )
            }
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hexString: colorValue) ?? Theme.accent },
                    set: { color in
                        let hex = color.toHexString()
                        store.updateRgb { current in
                            var next = current
                            if rgb.syncZones {
                                next.color = hex
                            } else {
                                switch zoneId {
                                case "logo": next.zones.logo.color = hex
                                case "scroll": next.zones.scroll.color = hex
                                default: next.zones.side.color = hex
                                }
                            }
                            return next
                        }
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .disabled(rgb.syncZones || !config.enabled)
            .opacity(config.enabled ? 1 : 0.45)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .opacity(config.enabled ? 1 : 0.7)
    }

    private func colorRow(
        color: String,
        selected: String,
        disabled: Bool,
        aria: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hexString: color) ?? Theme.accent },
                    set: { onSelect($0.toHexString()) }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .disabled(disabled)
            .frame(width: 44, height: 28)

            HStack(spacing: 8) {
                ForEach(Constants.colorSwatches, id: \.self) { swatch in
                    Button {
                        onSelect(swatch)
                    } label: {
                        Circle()
                            .fill(Color(hexString: swatch) ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selected == swatch ? Color.primary : Color.primary.opacity(0.15),
                                        lineWidth: selected == swatch ? 2 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    .accessibilityLabel("\(aria) \(swatch)")
                }
            }
            Spacer()
        }
        .opacity(disabled ? 0.45 : 1)
    }

    private func segmentControl(
        label: String,
        options: [(String, String)],
        selected: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
            HStack(spacing: 4) {
                ForEach(options, id: \.0) { value, title in
                    Button {
                        onSelect(value)
                    } label: {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(selected == value ? Theme.accent : Theme.text2)
                            .background(selected == value ? Theme.accentSoft : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func cardHead<Trailing: View>(
        eyebrow: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(Theme.TypeScale.eyebrow)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.text2)
                Text(title)
                    .font(Theme.TypeScale.cardHeadingLarge)
                    .foregroundStyle(Theme.text0)
            }
            Spacer()
            trailing()
        }
    }
}

extension Color {
    func toHexString() -> String {
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return "#00ff66" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
