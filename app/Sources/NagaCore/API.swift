import Foundation

private let globalStoreLock = NSLock()
// Guarded by `globalStoreLock` in `withStore`.
private nonisolated(unsafe) var globalStore: ProfileStoreService = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let dir = home
        .appendingPathComponent("Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent("Naga Trinity Control")
    return ProfileStoreService(directory: dir)
}()

private func withStore<T>(_ body: (ProfileStoreService) -> T) -> T {
    globalStoreLock.lock()
    defer { globalStoreLock.unlock() }
    return body(globalStore)
}

public func setStoreDir(path: String) {
    withStore { $0.setDirectory(URL(fileURLWithPath: path, isDirectory: true)) }
}

public func scanDevice() -> FfiDeviceInfo {
    listDevices()
}

public func readStore() -> FfiProfileStore {
    withStore { $0.read() }
}

public func writeStore(store: FfiProfileStore) -> FfiProfileStore {
    withStore { $0.write(store) }
}

public func upsertProfile(profile: FfiNagaProfile) -> FfiProfileStore {
    withStore { $0.upsertProfile(profile) }
}

public func deleteProfile(id: String) -> FfiProfileStore {
    withStore { $0.deleteProfile(id: id) }
}

public func duplicateProfile(id: String) -> FfiProfileStore {
    withStore { $0.duplicateProfile(id: id) }
}

public func setActiveProfile(id: String) -> FfiProfileStore {
    withStore { $0.setActiveProfile(id: id) }
}

public func applyProfile(profile: FfiNagaProfile) -> FfiApplyResult {
    runApplyProfile(profile)
}

public func previewRgb(rgb: FfiRgbSettings) -> FfiApplyResult {
    runPreviewRgb(rgb)
}

public func setRgbOff() -> FfiApplyResult {
    runSetRgbOff()
}

public func getSettings() -> FfiAppSettings {
    withStore { $0.getSettings() }
}

public func updateSettings(partial: FfiSettingsPartial) -> FfiAppSettings {
    withStore {
        $0.updateSettings(rgbOffOnLock: partial.rgbOffOnLock, language: partial.language)
    }
}

/// Create a new profile with defaults (for the "+" button).
/// Matches upstream create-profile: renderer fallback has no macros.
public func createEmptyProfile(name: String) -> FfiNagaProfile {
    var profile = createDefaultProfile(name: name)
    profile.macros = []
    return profile
}
