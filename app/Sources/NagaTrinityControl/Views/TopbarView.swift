import NagaCore
import SwiftUI

struct TopbarView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private var active: FfiNagaProfile { store.activeProfile }
    private var showsProfileActions: Bool {
        store.section != .settings
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                if showsProfileActions {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l10n.t("topbar.profileEyebrow"))
                            .font(Theme.TypeScale.eyebrow)
                            .foregroundStyle(Theme.text2)
                            .textCase(.uppercase)
                            .tracking(0.4)
                        HStack(spacing: 8) {
                            TextField("", text: nameBinding)
                                .textFieldStyle(.plain)
                                .font(Theme.TypeScale.pageTitle)
                                .foregroundStyle(Theme.text0)
                            if store.hasUnsavedChanges {
                                Circle()
                                    .fill(Theme.warn)
                                    .frame(width: 7, height: 7)
                                    .accessibilityLabel(l10n.t("topbar.unsavedChanges"))
                            }
                        }
                    }
                } else {
                    Text(l10n.t("sections.settings"))
                        .font(Theme.TypeScale.pageTitle)
                        .foregroundStyle(Theme.text0)
                }

                Spacer(minLength: 12)

                if showsProfileActions {
                    HStack(spacing: 8) {
                        Button {
                            Task { await store.duplicateProfile() }
                        } label: {
                            Text(l10n.t("topbar.duplicate"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button(role: .destructive) {
                            Task { await store.deleteProfile(id: active.id) }
                        } label: {
                            Text(l10n.t("topbar.delete"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(Theme.danger)

                        Button {
                            Task { await store.saveActive() }
                        } label: {
                            Text(l10n.t("topbar.save"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button {
                            Task { await store.applyActive() }
                        } label: {
                            HStack(spacing: 6) {
                                if store.isApplying {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(store.isApplying ? l10n.t("topbar.applying") : l10n.t("topbar.applyToMouse"))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(Theme.accent)
                        .disabled(store.isApplying)
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
                .opacity(0.9)
        }
        .background(Theme.bg0)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { store.activeProfile.name },
            set: { newValue in
                store.updateActive { profile in
                    var next = profile
                    next.name = newValue
                    return next
                }
            }
        )
    }
}
