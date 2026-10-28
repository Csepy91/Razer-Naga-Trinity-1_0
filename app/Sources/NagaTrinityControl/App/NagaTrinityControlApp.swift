import SwiftUI

@main
struct NagaTrinityControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var l10n = L10n.shared

    var body: some Scene {
        // Placeholder scene so SwiftUI still installs the standard menus.
        // The real window is owned by AppDelegate. This scene must not be
        // presented: macOS otherwise opens it as a blank "… Settings" window.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
            CommandGroup(replacing: .appTermination) {
                Button(l10n.t("tray.closeWindow")) {
                    appDelegate.hideWindow()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
