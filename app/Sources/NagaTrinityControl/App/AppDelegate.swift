import AppKit
import Foundation
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppStore()
    let l10n = L10n.shared
    let appearance = AppearancePreference()
    let hotkeys = HotkeyRegistry()
    let powerMonitor = PowerMonitor()
    let tray = TrayController()

    private var window: NSWindow?
    private var isQuitting = false
    private var closingSettingsWindows: Set<ObjectIdentifier> = []
    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "AppDelegate")

    private var launchedHidden: Bool {
        CommandLine.arguments.contains("--hidden")
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(placeholderSettingsWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        closePlaceholderSettingsWindows()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        closePlaceholderSettingsWindows()
        Accessibility.ensureTrusted(prompt: true)

        store.onProfileApplied = { [weak self] profile in
            guard let self else { return }
            let result = self.hotkeys.register(profile: profile)
            self.store.lastHotkeyResult = result
            self.logger.info(
                "sideTriggers registered=\(result.registered) failed=\(result.failed) hid=\(result.hidOk) seized=\(result.hidSeized) ax=\(result.accessibilityTrusted)"
            )
            if !result.accessibilityTrusted || (!result.hidOk && result.failed > 0) {
                self.store.notice = Notice(
                    ok: false,
                    message: L10n.shared.t("accessibility.required"),
                    key: "accessibility.required",
                    tone: .error
                )
            } else if result.hidOk && result.registered > 0 && !result.hidSeized {
                self.store.notice = Notice(
                    ok: false,
                    message: L10n.shared.t("accessibility.hidListenOnly"),
                    key: "accessibility.hidListenOnly",
                    tone: .error
                )
                Accessibility.openInputMonitoringSettings()
            } else if result.hidOk && result.registered > 0 {
                self.store.notice = Notice(
                    ok: true,
                    message: L10n.shared.t("accessibility.tapActive"),
                    key: "accessibility.tapActive",
                    tone: .info
                )
            }
        }
        store.onSettingsChanged = { [weak self] _ in
            self?.tray.rebuildMenu()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.store.initStore()
            self.powerMonitor.start(store: self.store)
            self.tray.install(
                store: self.store,
                onOpenWindow: { [weak self] in self?.showWindow() },
                onReapply: { [weak self] in
                    Task { await self?.store.applyActiveFromDaemon() }
                },
                onQuit: { [weak self] in
                    self?.isQuitting = true
                    NSApp.terminate(nil)
                }
            )

            self.closePlaceholderSettingsWindows()
            if self.launchedHidden {
                NSApp.setActivationPolicy(.accessory)
            } else {
                self.showWindow()
            }
            self.closePlaceholderSettingsWindows()

            await self.store.applyActiveFromDaemon()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    /// The only SwiftUI scene is an empty `Settings` view. macOS treats that as
    /// the untitled document and opens a blank settings window at launch.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.unregisterAll()
        powerMonitor.stop()
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = ContentView()
            .environmentObject(store)
            .environmentObject(l10n)
            .environmentObject(appearance)

        let hosting = NSHostingController(rootView: root)
        // Don't let SwiftUI's ideal content size lock the window — otherwise
        // height can't shrink and resize fights Auto Layout every frame.
        hosting.sizingOptions = []

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Theme.windowDefault.width,
                height: Theme.windowDefault.height
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Naga Trinity Control"
        window.identifier = NSUserInterfaceItemIdentifier("local.naga-trinity-control.main")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Theme.bg0)
        window.contentViewController = hosting
        window.contentMinSize = NSSize(width: Theme.windowMin.width, height: Theme.windowMin.height)
        window.setContentSize(NSSize(width: Theme.windowDefault.width, height: Theme.windowDefault.height))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func hideWindow() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension AppDelegate {
    @objc fileprivate func placeholderSettingsWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        closeIfPlaceholderSettings(window)
    }

    fileprivate func closePlaceholderSettingsWindows() {
        for window in NSApp.windows {
            closeIfPlaceholderSettings(window)
        }
    }

    private func closeIfPlaceholderSettings(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard !closingSettingsWindows.contains(id) else { return }
        guard isPlaceholderSettingsWindow(window) else { return }
        closingSettingsWindows.insert(id)
        window.orderOut(nil)
        window.close()
        closingSettingsWindows.remove(id)
    }

    private func isPlaceholderSettingsWindow(_ window: NSWindow) -> Bool {
        if window === self.window { return false }
        if window.identifier?.rawValue == "local.naga-trinity-control.main" { return false }

        let markers = [window.identifier?.rawValue, window.frameAutosaveName].compactMap { $0 }
        if markers.contains(where: isSwiftUISettingsMarker) {
            return true
        }

        let title = window.title
        return title.hasSuffix(" Settings") || title.hasSuffix(" Einstellungen")
    }

    private func isSwiftUISettingsMarker(_ value: String) -> Bool {
        let folded = value.lowercased()
        return folded.contains("swiftui") && folded.contains("settings")
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isQuitting {
            return true
        }
        hideWindow()
        return false
    }
}
