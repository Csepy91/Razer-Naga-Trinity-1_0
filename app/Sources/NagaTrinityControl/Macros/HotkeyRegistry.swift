import Foundation
import NagaCore
import os

/// Side-button trigger registry — thin wrapper over `DeviceKeyMonitor` (CGEventTap).
@MainActor
final class HotkeyRegistry {
    struct RegistrationResult: Equatable {
        var registered: Int
        var failed: Int
        var hidOk: Bool
        var hidSeized: Bool
        var accessibilityTrusted: Bool
    }

    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "HotkeyRegistry")
    private let deviceMonitor = DeviceKeyMonitor()

    func unregisterAll() {
        deviceMonitor.stop()
    }

    @discardableResult
    func register(profile: FfiNagaProfile) -> RegistrationResult {
        unregisterAll()

        let trusted = Accessibility.ensureTrusted(prompt: false)
        let bindingCount = DeviceKeyMonitor.buildActionsCount(profile: profile)
        let hid = deviceMonitor.start(profile: profile)

        let registered = hid.ok ? bindingCount : 0
        let failed = hid.ok ? 0 : bindingCount

        logger.info(
            "register ok=\(hid.ok) seized=\(hid.seized) count=\(registered) ax=\(trusted) — \(hid.message, privacy: .public)"
        )

        return RegistrationResult(
            registered: registered,
            failed: failed,
            hidOk: hid.ok,
            hidSeized: hid.seized,
            accessibilityTrusted: trusted
        )
    }
}
