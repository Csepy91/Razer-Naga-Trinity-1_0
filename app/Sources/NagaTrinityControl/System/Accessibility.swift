import AppKit
import ApplicationServices
import Foundation
import os

enum Accessibility {
    private static let logger = Logger(subsystem: "local.naga-trinity-control", category: "Accessibility")

    /// Prompts the user for Accessibility trust if not already granted.
    @discardableResult
    static func ensureTrusted(prompt: Bool = true) -> Bool {
        // String form of kAXTrustedCheckOptionPrompt — avoids Swift 6 shared-mutable-state warnings.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            logger.warning("Accessibility not trusted — hotkeys and key injection will not work")
        }
        return trusted
    }

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func openSystemSettings() {
        openPrivacyPane(anchors: [
            "Privacy_Accessibility",
        ])
    }

    static func openInputMonitoringSettings() {
        openPrivacyPane(anchors: [
            "Privacy_ListenEvent",
            "Privacy_InputMonitoring",
        ])
    }

    private static func openPrivacyPane(anchors: [String]) {
        for anchor in anchors {
            let urls = [
                "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
            ]
            for url in urls {
                if let u = URL(string: url), NSWorkspace.shared.open(u) {
                    return
                }
            }
        }
    }
}
