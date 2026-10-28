import Foundation
import NagaCore

/// Async wrappers over the blocking NagaCore FFI. All USB/store I/O runs off the main actor.
enum CoreClient {
    static func scanDevice() async -> FfiDeviceInfo {
        await Task.detached(priority: .userInitiated) {
            NagaCore.scanDevice()
        }.value
    }

    static func readStore() async -> FfiProfileStore {
        await Task.detached(priority: .userInitiated) {
            NagaCore.readStore()
        }.value
    }

    static func writeStore(_ store: FfiProfileStore) async -> FfiProfileStore {
        await Task.detached(priority: .userInitiated) {
            NagaCore.writeStore(store: store)
        }.value
    }

    static func upsertProfile(_ profile: FfiNagaProfile) async -> FfiProfileStore {
        await Task.detached(priority: .userInitiated) {
            NagaCore.upsertProfile(profile: profile)
        }.value
    }

    static func deleteProfile(id: String) async -> FfiProfileStore {
        await Task.detached(priority: .userInitiated) {
            NagaCore.deleteProfile(id: id)
        }.value
    }

    static func duplicateProfile(id: String) async -> FfiProfileStore {
        await Task.detached(priority: .userInitiated) {
            NagaCore.duplicateProfile(id: id)
        }.value
    }

    static func setActiveProfile(id: String) async -> FfiProfileStore {
        await Task.detached(priority: .userInitiated) {
            NagaCore.setActiveProfile(id: id)
        }.value
    }

    static func applyProfile(_ profile: FfiNagaProfile) async -> FfiApplyResult {
        await Task.detached(priority: .userInitiated) {
            NagaCore.applyProfile(profile: profile)
        }.value
    }

    static func previewRgb(_ rgb: FfiRgbSettings) async -> FfiApplyResult {
        await Task.detached(priority: .userInitiated) {
            NagaCore.previewRgb(rgb: rgb)
        }.value
    }

    static func setRgbOff() async -> FfiApplyResult {
        await Task.detached(priority: .userInitiated) {
            NagaCore.setRgbOff()
        }.value
    }

    static func getSettings() async -> FfiAppSettings {
        await Task.detached(priority: .userInitiated) {
            NagaCore.getSettings()
        }.value
    }

    static func updateSettings(_ partial: FfiSettingsPartial) async -> FfiAppSettings {
        await Task.detached(priority: .userInitiated) {
            NagaCore.updateSettings(partial: partial)
        }.value
    }

    static func createEmptyProfile(name: String) async -> FfiNagaProfile {
        await Task.detached(priority: .userInitiated) {
            NagaCore.createEmptyProfile(name: name)
        }.value
    }

    static func setStoreDir(path: String) async {
        await Task.detached(priority: .userInitiated) {
            NagaCore.setStoreDir(path: path)
        }.value
    }
}
