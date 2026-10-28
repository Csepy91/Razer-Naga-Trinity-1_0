import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    private let primarySections: [SectionId] = [
        .overview, .performance, .lighting, .buttons, .macros,
    ]
    private let secondarySections: [SectionId] = [
        .profiles, .settings,
    ]

    var body: some View {
        VStack(spacing: 0) {
            brand
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

            List(selection: sectionBinding) {
                Section {
                    ForEach(primarySections) { section in
                        navRow(section)
                    }
                }
                Section {
                    ForEach(secondarySections) { section in
                        navRow(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            deviceFooter
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
        .background(Theme.bg1)
    }

    private var sectionBinding: Binding<SectionId?> {
        Binding(
            get: { store.section },
            set: { newValue in
                guard let newValue else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    store.setSection(newValue)
                }
            }
        )
    }

    private func navRow(_ section: SectionId) -> some View {
        Label {
            Text(l10n.t("sections.\(section.rawValue)"))
                .font(Theme.TypeScale.bodyMedium)
        } icon: {
            Image(systemName: section.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 18, alignment: .center)
        }
        .tag(section)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Naga Trinity")
                    .font(Theme.TypeScale.bodySemibold)
                    .foregroundStyle(Theme.text0)
                Text(l10n.t("sidebar.brandSub"))
                    .font(Theme.TypeScale.micro)
                    .foregroundStyle(Theme.text2)
            }
            Spacer(minLength: 0)
        }
    }

    private var deviceFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
                .opacity(0.85)

            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(store.device.connected ? Theme.accent : Theme.warn)
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.device.connected ? l10n.t("common.connected") : l10n.t("common.disconnected"))
                        .font(Theme.TypeScale.metaMedium)
                        .foregroundStyle(Theme.text0)
                    Text(store.device.productName ?? "Razer Naga Trinity")
                        .font(Theme.TypeScale.caption)
                        .foregroundStyle(Theme.text2)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            Button {
                Task { await store.rescan() }
            } label: {
                Text(l10n.t("sidebar.rescan"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(l10n.t("trademark.disclaimer"))
                .font(Theme.TypeScale.micro)
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
