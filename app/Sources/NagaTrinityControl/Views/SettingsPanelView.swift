import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n
    @EnvironmentObject private var appearance: AppearancePreference

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.stackSpacing) {
                appearanceCard
                startupCard
                languageCard
                powerCard
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .background(Theme.bg0)
    }

    private var appearanceCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.t("settings.appearance"))
                    .font(Theme.TypeScale.cardHeading)
                    .foregroundStyle(Theme.text0)
                Picker("", selection: $appearance.appearance) {
                    Text(l10n.t("settings.appearanceSystem")).tag(AppAppearance.system)
                    Text(l10n.t("settings.appearanceLight")).tag(AppAppearance.light)
                    Text(l10n.t("settings.appearanceDark")).tag(AppAppearance.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var startupCard: some View {
        CardView {
            Toggle(isOn: launchAtLoginBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("tray.launchAtLogin"))
                        .font(Theme.TypeScale.bodySemibold)
                        .foregroundStyle(Theme.text0)
                    Text(l10n.t("settings.launchAtLoginHint"))
                        .font(Theme.TypeScale.caption)
                        .foregroundStyle(Theme.text2)
                }
            }
            .toggleStyle(.switch)
            .tint(Theme.accent)
        }
    }

    private var languageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.t("topbar.language"))
                    .font(Theme.TypeScale.cardHeading)
                    .foregroundStyle(Theme.text0)
                Picker("", selection: languageBinding) {
                    ForEach(Constants.supportedLanguages, id: \.self) { code in
                        Text(code.uppercased()).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var powerCard: some View {
        CardView {
            Toggle(isOn: rgbOffBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("tray.rgbOffOnLock"))
                        .font(Theme.TypeScale.bodySemibold)
                        .foregroundStyle(Theme.text0)
                    Text(l10n.t("settings.rgbOffOnLockHint"))
                        .font(Theme.TypeScale.caption)
                        .foregroundStyle(Theme.text2)
                }
            }
            .toggleStyle(.switch)
            .tint(Theme.accent)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LoginItem.isEnabled },
            set: { newValue in
                _ = LoginItem.setEnabled(newValue)
            }
        )
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { l10n.language },
            set: { code in
                Task { await store.setLanguage(code) }
            }
        )
    }

    private var rgbOffBinding: Binding<Bool> {
        Binding(
            get: { store.settings.rgbOffOnLock },
            set: { enabled in
                Task { await store.setRgbOffOnLock(enabled) }
            }
        )
    }
}
