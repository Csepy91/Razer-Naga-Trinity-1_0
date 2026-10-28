import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: Theme.sidebarWidth, max: 260)
                .background(Theme.bg1)
        } detail: {
            VStack(spacing: 0) {
                TopbarView()
                NoticeBarView()
                ZStack {
                    keptAlive(.overview) { OverviewPanelView() }
                    keptAlive(.performance) { PerformancePanelView() }
                    keptAlive(.lighting) { LightingPanelView() }
                    keptAlive(.buttons) { ButtonsPanelView() }
                    keptAlive(.macros) { MacrosPanelView() }
                    keptAlive(.profiles) { ProfilesPanelView() }
                    keptAlive(.settings) { SettingsPanelView() }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .background(Theme.bg0)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.accent)
    }

    private func keptAlive<Content: View>(
        _ section: SectionId,
        @ViewBuilder content: () -> Content
    ) -> some View {
        KeptAlivePanel(
            section: section,
            activeSection: store.section,
            profileRevision: store.activeProfile.updatedAt,
            language: l10n.language,
            content: content()
        )
        .equatable()
    }
}

/// Skips body updates while inactive so background panels don't rebuild on every
/// store change (that thrash was dropping intermittent clicks). On activation,
/// `activeSection` changes and the panel refreshes from the current store.
private struct KeptAlivePanel<Content: View>: View {
    let section: SectionId
    let activeSection: SectionId
    let profileRevision: Int64
    let language: String
    let content: Content

    private var isActive: Bool { section == activeSection }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Collapse inactive panels so they don't inflate the ZStack's
            // ideal size (which locked window height) or re-layout on resize.
            .frame(
                minWidth: 0,
                maxWidth: isActive ? .infinity : 0,
                minHeight: 0,
                maxHeight: isActive ? .infinity : 0
            )
            .clipped()
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .disabled(!isActive)
            .accessibilityHidden(!isActive)
            .zIndex(isActive ? 1 : 0)
    }
}

extension KeptAlivePanel: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.section == rhs.section else { return false }
        let lhsInactive = lhs.activeSection != lhs.section
        let rhsInactive = rhs.activeSection != rhs.section
        // Both still inactive: treat as equal → don't refresh the frozen tree.
        if lhsInactive && rhsInactive {
            return true
        }
        return lhs.activeSection == rhs.activeSection
            && lhs.profileRevision == rhs.profileRevision
            && lhs.language == rhs.language
    }
}
