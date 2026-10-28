import Foundation
import os
import ServiceManagement

@MainActor
enum LoginItem {
    private static let logger = Logger(subsystem: "local.naga-trinity-control", category: "LoginItem")
    private static let plistName = "local.naga-trinity-control.plist"

    static var isEnabled: Bool {
        SMAppService.agent(plistName: plistName).status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.agent(plistName: plistName)
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return isEnabled
        } catch {
            logger.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
            let main = SMAppService.mainApp
            do {
                if enabled {
                    try main.register()
                } else {
                    try main.unregister()
                }
                return main.status == .enabled
            } catch {
                logger.error("mainApp login item failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }
}
