import AppKit
import Foundation
import os

@MainActor
final class TrayController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var store: AppStore?
    private var onOpenWindow: (() -> Void)?
    private var onQuit: (() -> Void)?
    private var onReapply: (() -> Void)?
    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "Tray")

    func install(
        store: AppStore,
        onOpenWindow: @escaping () -> Void,
        onReapply: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.store = store
        self.onOpenWindow = onOpenWindow
        self.onReapply = onReapply
        self.onQuit = onQuit

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.trayImage()
            button.image?.isTemplate = true
            button.toolTip = "Naga Trinity Control"
            button.target = self
            button.action = #selector(trayClicked)
        }
        statusItem = item
        rebuildMenu()
    }

    func rebuildMenu() {
        guard let store else { return }
        let l10n = L10n.shared
        let menu = NSMenu()

        let open = NSMenuItem(
            title: l10n.t("tray.openWindow"),
            action: #selector(openWindow),
            keyEquivalent: ""
        )
        open.target = self
        menu.addItem(open)

        let reapply = NSMenuItem(
            title: l10n.t("tray.reapplyProfile"),
            action: #selector(reapplyProfile),
            keyEquivalent: ""
        )
        reapply.target = self
        menu.addItem(reapply)

        menu.addItem(.separator())

        let login = NSMenuItem(
            title: l10n.t("tray.launchAtLogin"),
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let rgbOff = NSMenuItem(
            title: l10n.t("tray.rgbOffOnLock"),
            action: #selector(toggleRgbOff(_:)),
            keyEquivalent: ""
        )
        rgbOff.target = self
        rgbOff.state = store.settings.rgbOffOnLock ? .on : .off
        menu.addItem(rgbOff)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: l10n.t("tray.quit"),
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
    }

    @objc private func trayClicked() {
        onOpenWindow?()
    }

    @objc private func openWindow() {
        onOpenWindow?()
    }

    @objc private func reapplyProfile() {
        onReapply?()
    }

    @objc private func quitApp() {
        onQuit?()
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let enabled = sender.state != .on
        _ = LoginItem.setEnabled(enabled)
        rebuildMenu()
    }

    @objc private func toggleRgbOff(_ sender: NSMenuItem) {
        let enabled = sender.state != .on
        Task { @MainActor in
            await store?.setRgbOffOnLock(enabled)
            rebuildMenu()
        }
    }

    private static func trayImage() -> NSImage {
        // Upstream diamond 16×16 template PNG (electron/main.ts TRAY_ICON_DATA_URL).
        let base64 =
            "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAO0lEQVR4nGNgGOzgPxRTpJksQ9A1k2QILs1EGUJIM15DiNWM0xCKDaDYC8QaQhSgSDMuQ9gCFGmmDwAAhdVTrfcfBBYAAAAASUVORK5CYII="
        if let data = Data(base64Encoded: base64), let image = NSImage(data: data) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            return image
        }
        let fallback = NSImage(size: NSSize(width: 16, height: 16))
        fallback.isTemplate = true
        return fallback
    }
}
