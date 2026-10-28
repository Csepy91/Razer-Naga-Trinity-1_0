import Foundation
import NagaCore
import os

enum SectionId: String, CaseIterable, Identifiable {
    case overview
    case performance
    case lighting
    case buttons
    case macros
    case profiles
    case settings

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .lighting: return "lightbulb"
        case .buttons: return "keyboard"
        case .macros: return "cpu"
        case .profiles: return "person.crop.rectangle.stack"
        case .settings: return "gearshape"
        }
    }
}

enum NoticeTone: String {
    case info
    case success
    case error
}

struct Notice: Equatable {
    var ok: Bool
    var message: String
    var key: String?
    var params: [String: String]
    var stage: String?
    var tone: NoticeTone

    init(from result: FfiApplyResult, tone: NoticeTone) {
        self.ok = result.ok
        self.message = result.message
        self.key = result.key
        self.params = result.params
        self.stage = result.stage
        self.tone = tone
    }

    init(ok: Bool, message: String, key: String? = nil, params: [String: String] = [:], tone: NoticeTone) {
        self.ok = ok
        self.message = message
        self.key = key
        self.params = params
        self.stage = nil
        self.tone = tone
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var store: FfiProfileStore
    @Published var device: FfiDeviceInfo
    @Published var section: SectionId = .overview
    @Published var notice: Notice?
    @Published var isApplying = false
    @Published var hasUnsavedChanges = false
    @Published var settings: FfiAppSettings
    @Published var lastHotkeyResult: HotkeyRegistry.RegistrationResult?

    /// Called after a successful apply so the app can re-register macro hotkeys.
    var onProfileApplied: ((FfiNagaProfile) -> Void)?
    /// Called when language settings change so the tray can rebuild.
    var onSettingsChanged: ((FfiAppSettings) -> Void)?

    private var rgbPreviewTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "AppStore")

    init() {
        self.store = Self.fallbackStore()
        self.device = FfiDeviceInfo(
            connected: false,
            productName: nil,
            manufacturer: nil,
            vendorId: nil,
            productId: nil,
            interfaces: 0
        )
        self.settings = FfiAppSettings(rgbOffOnLock: true, language: nil)
    }

    var activeProfile: FfiNagaProfile {
        store.profiles.first(where: { $0.id == store.activeProfileId })
            ?? store.profiles.first
            ?? Self.fallbackProfile()
    }

    func initStore() async {
        await ensureStoreDir()
        async let storeTask = CoreClient.readStore()
        async let deviceTask = CoreClient.scanDevice()
        async let settingsTask = CoreClient.getSettings()
        store = await storeTask
        device = await deviceTask
        settings = await settingsTask
        L10n.shared.resolveLanguage(from: settings.language)
        onSettingsChanged?(settings)
    }

    func rescan() async {
        device = await CoreClient.scanDevice()
    }

    func setSection(_ section: SectionId) {
        guard self.section != section else { return }
        self.section = section
    }

    func selectProfile(id: String) async {
        store = await CoreClient.setActiveProfile(id: id)
        hasUnsavedChanges = false
    }

    func createProfile() async {
        let name = "Profil \(store.profiles.count + 1)"
        let profile = await CoreClient.createEmptyProfile(name: name)
        _ = await CoreClient.upsertProfile(profile)
        store = await CoreClient.setActiveProfile(id: profile.id)
        hasUnsavedChanges = false
    }

    func duplicateProfile() async {
        store = await CoreClient.duplicateProfile(id: store.activeProfileId)
        hasUnsavedChanges = false
    }

    func deleteProfile(id: String) async {
        store = await CoreClient.deleteProfile(id: id)
        hasUnsavedChanges = false
    }

    func updateActive(_ updater: (FfiNagaProfile) -> FfiNagaProfile) {
        var profile = activeProfile
        profile = updater(profile)
        profile.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        replaceActive(profile)
        hasUnsavedChanges = true
    }

    func updateRgb(_ updater: (FfiRgbSettings) -> FfiRgbSettings) {
        updateActive { profile in
            var next = profile
            next.rgb = updater(profile.rgb)
            return next
        }
        scheduleRgbPreview()
    }

    func saveActive() async {
        let active = activeProfile
        store = await CoreClient.upsertProfile(active)
        hasUnsavedChanges = false
        notice = Notice(
            ok: true,
            message: L10n.shared.t("storeNotices.profileSaved"),
            key: "storeNotices.profileSaved",
            tone: .success
        )
    }

    func applyActive() async {
        let active = activeProfile
        isApplying = true
        notice = nil
        let result = await CoreClient.applyProfile(active)
        if result.ok {
            store = await CoreClient.upsertProfile(active)
            store = await CoreClient.setActiveProfile(id: active.id)
            hasUnsavedChanges = false
            onProfileApplied?(activeProfile)
        }
        isApplying = false
        notice = Notice(from: result, tone: result.ok ? .success : .error)
        device = await CoreClient.scanDevice()
    }

    /// Daemon-style apply used at launch and from the tray (no UI dirty-state dance).
    func applyActiveFromDaemon() async {
        let active = activeProfile
        let result = await CoreClient.applyProfile(active)
        logger.info("daemon apply: \(result.ok ? "OK" : "FAIL", privacy: .public) — \(result.message, privacy: .public)")
        onProfileApplied?(active)
    }

    func setSidePlate(_ plate: String) {
        updateActive { profile in
            var next = profile
            next.sidePlate = plate
            next.buttons = Self.buildButtons(plate: plate)
            return next
        }
    }

    func addMacro() {
        updateActive { profile in
            var next = profile
            let step = FfiMacroStep(
                id: Self.newId(),
                stepType: "key",
                value: "G",
                delayMs: 0
            )
            let macro = FfiMacro(
                id: Self.newId(),
                name: "Makro \(profile.macros.count + 1)",
                steps: [step],
                repeatMode: "once",
                repeatCount: 1
            )
            next.macros.append(macro)
            return next
        }
    }

    func updateMacro(_ macro: FfiMacro) {
        updateActive { profile in
            var next = profile
            next.macros = profile.macros.map { $0.id == macro.id ? macro : $0 }
            return next
        }
    }

    func removeMacro(macroId: String) {
        updateActive { profile in
            var next = profile
            next.macros = profile.macros.filter { $0.id != macroId }
            return next
        }
    }

    func addMacroStep(macroId: String) {
        updateActive { profile in
            var next = profile
            next.macros = profile.macros.map { macro in
                guard macro.id == macroId else { return macro }
                var updated = macro
                updated.steps.append(
                    FfiMacroStep(id: Self.newId(), stepType: "key", value: "", delayMs: 50)
                )
                return updated
            }
            return next
        }
    }

    func updateMacroStep(macroId: String, step: FfiMacroStep) {
        updateActive { profile in
            var next = profile
            next.macros = profile.macros.map { macro in
                guard macro.id == macroId else { return macro }
                var updated = macro
                updated.steps = macro.steps.map { $0.id == step.id ? step : $0 }
                return updated
            }
            return next
        }
    }

    func removeMacroStep(macroId: String, stepId: String) {
        updateActive { profile in
            var next = profile
            next.macros = profile.macros.map { macro in
                guard macro.id == macroId else { return macro }
                var updated = macro
                updated.steps = macro.steps.filter { $0.id != stepId }
                return updated
            }
            return next
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func setLanguage(_ code: String) async {
        L10n.shared.setLanguage(code)
        settings = await CoreClient.updateSettings(
            FfiSettingsPartial(rgbOffOnLock: nil, language: code)
        )
        onSettingsChanged?(settings)
    }

    func setRgbOffOnLock(_ enabled: Bool) async {
        settings = await CoreClient.updateSettings(
            FfiSettingsPartial(rgbOffOnLock: enabled, language: nil)
        )
        onSettingsChanged?(settings)
    }

    func previewActiveRgb() async {
        _ = await CoreClient.previewRgb(activeProfile.rgb)
    }

    // MARK: - Private

    private func replaceActive(_ profile: FfiNagaProfile) {
        var next = store
        next.profiles = store.profiles.map { $0.id == profile.id ? profile : $0 }
        store = next
    }

    private func scheduleRgbPreview() {
        rgbPreviewTask?.cancel()
        let rgb = activeProfile.rgb
        rgbPreviewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            _ = await CoreClient.previewRgb(rgb)
            _ = self
        }
    }

    private func ensureStoreDir() async {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let support else { return }
        let dir = support.appendingPathComponent("NagaTrinityControl", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        await CoreClient.setStoreDir(path: dir.path)
    }

    private static func newId() -> String {
        UUID().uuidString.lowercased()
    }

    private static let sidePlateLabels: [String: [String]] = [
        "two": ["Side 1", "Side 2"],
        "seven": ["Side 1", "Side 2", "Side 3", "Side 4", "Side 5", "Side 6", "Side 7"],
        "twelve": (1...12).map { "Numpad \($0)" },
    ]

    static func buildButtons(plate: String) -> [FfiButtonBinding] {
        let base: [FfiButtonBinding] = [
            .init(id: "base-1", label: "Left Click", hardwareIndex: 1, action: "default", value: "Mouse 1", macroId: nil),
            .init(id: "base-2", label: "Right Click", hardwareIndex: 2, action: "default", value: "Mouse 2", macroId: nil),
            .init(id: "base-3", label: "Scroll Click", hardwareIndex: 3, action: "default", value: "Mouse 3", macroId: nil),
            .init(id: "base-4", label: "Scroll Up", hardwareIndex: 4, action: "default", value: "Wheel ↑", macroId: nil),
            .init(id: "base-5", label: "Scroll Down", hardwareIndex: 5, action: "default", value: "Wheel ↓", macroId: nil),
            .init(id: "base-6", label: "Wheel Tilt Left", hardwareIndex: 6, action: "default", value: "Browser ←", macroId: nil),
            .init(id: "base-7", label: "Wheel Tilt Right", hardwareIndex: 7, action: "default", value: "Browser →", macroId: nil),
            .init(id: "base-8", label: "DPI Up", hardwareIndex: 8, action: "dpi-up", value: "DPI +", macroId: nil),
            .init(id: "base-9", label: "DPI Down", hardwareIndex: 9, action: "dpi-down", value: "DPI -", macroId: nil),
        ]
        let labels = sidePlateLabels[plate] ?? sidePlateLabels["twelve"] ?? []
        let side: [FfiButtonBinding] = labels.enumerated().map { index, label in
            FfiButtonBinding(
                id: "side-\(index + 1)",
                label: label,
                hardwareIndex: UInt8(10 + index),
                action: "key",
                value: plate == "twelve" ? "\(index + 1)" : "F\(index + 1)",
                macroId: nil
            )
        }
        return base + side
    }

    private static func fallbackProfile() -> FfiNagaProfile {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return FfiNagaProfile(
            id: "fallback",
            name: "Naga Trinity",
            sidePlate: "twelve",
            rgb: FfiRgbSettings(
                effect: "static",
                color: "#00ff66",
                secondaryColor: "#00d9ff",
                brightness: 80,
                waveDirection: "right",
                reactiveSpeed: 2,
                syncZones: true,
                zones: FfiRgbZones(
                    logo: FfiZoneConfig(enabled: true, color: "#00ff66"),
                    scroll: FfiZoneConfig(enabled: true, color: "#00ff66"),
                    side: FfiZoneConfig(enabled: true, color: "#00ff66")
                )
            ),
            dpi: FfiDpiSettings(
                activeStage: 2,
                stages: [
                    FfiDpiStage(id: "s1", x: 800, y: 800),
                    FfiDpiStage(id: "s2", x: 1800, y: 1800),
                    FfiDpiStage(id: "s3", x: 3200, y: 3200),
                    FfiDpiStage(id: "s4", x: 6400, y: 6400),
                    FfiDpiStage(id: "s5", x: 12000, y: 12000),
                ]
            ),
            pollingRate: 1000,
            buttons: buildButtons(plate: "twelve"),
            macros: [],
            createdAt: now,
            updatedAt: now
        )
    }

    private static func fallbackStore() -> FfiProfileStore {
        let profile = fallbackProfile()
        return FfiProfileStore(
            version: 2,
            activeProfileId: profile.id,
            profiles: [profile],
            settings: FfiAppSettings(rgbOffOnLock: true, language: nil)
        )
    }
}
