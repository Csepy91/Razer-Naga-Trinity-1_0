import Foundation

private func nowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}

private func newId() -> String {
    UUID().uuidString.lowercased()
}

public func defaultSettings() -> FfiAppSettings {
    FfiAppSettings(rgbOffOnLock: true, language: nil)
}

public func mergeSettings(_ incoming: FfiAppSettings?) -> FfiAppSettings {
    var settings = defaultSettings()
    guard let incoming else { return settings }
    settings.rgbOffOnLock = incoming.rgbOffOnLock
    if incoming.language != nil {
        settings.language = incoming.language
    }
    return settings
}

private func sidePlateLabels(_ plate: String) -> [String] {
    switch plate {
    case "two": return ["Side 1", "Side 2"]
    case "seven": return (1...7).map { "Side \($0)" }
    default: return (1...12).map { "Numpad \($0)" }
    }
}

private let baseButtons: [(String, String, String)] = [
    ("Left Click", "default", "Mouse 1"),
    ("Right Click", "default", "Mouse 2"),
    ("Scroll Click", "default", "Mouse 3"),
    ("Scroll Up", "default", "Wheel ↑"),
    ("Scroll Down", "default", "Wheel ↓"),
    ("Wheel Tilt Left", "default", "Browser ←"),
    ("Wheel Tilt Right", "default", "Browser →"),
    ("DPI Up", "dpi-up", "DPI +"),
    ("DPI Down", "dpi-down", "DPI -"),
]

public func buildButtonsForPlate(_ plate: String) -> [FfiButtonBinding] {
    var buttons: [FfiButtonBinding] = baseButtons.enumerated().map { index, item in
        FfiButtonBinding(
            id: "base-\(index + 1)",
            label: item.0,
            hardwareIndex: UInt8(index + 1),
            action: item.1,
            value: item.2,
            macroId: nil
        )
    }
    for (index, label) in sidePlateLabels(plate).enumerated() {
        let value = plate == "twelve" ? "\(index + 1)" : "F\(index + 1)"
        buttons.append(
            FfiButtonBinding(
                id: "side-\(index + 1)",
                label: label,
                hardwareIndex: UInt8(10 + index),
                action: "key",
                value: value,
                macroId: nil
            )
        )
    }
    return buttons
}

public func createDefaultMacro() -> FfiMacro {
    FfiMacro(
        id: newId(),
        name: "Potion + Confirm",
        steps: [
            FfiMacroStep(id: newId(), stepType: "key", value: "1", delayMs: 0),
            FfiMacroStep(id: newId(), stepType: "delay", value: "", delayMs: 120),
            FfiMacroStep(id: newId(), stepType: "key", value: "Enter", delayMs: 0),
        ],
        repeatMode: "once",
        repeatCount: 1
    )
}

public func defaultRgb() -> FfiRgbSettings {
    FfiRgbSettings(
        effect: "static",
        color: "#00ff66",
        secondaryColor: "#00b3ff",
        brightness: 80,
        waveDirection: "right",
        reactiveSpeed: 2,
        syncZones: true,
        zones: FfiRgbZones(
            logo: FfiZoneConfig(enabled: true, color: "#00ff66"),
            scroll: FfiZoneConfig(enabled: true, color: "#00ff66"),
            side: FfiZoneConfig(enabled: true, color: "#00ff66")
        )
    )
}

public func defaultDpi() -> FfiDpiSettings {
    FfiDpiSettings(
        activeStage: 2,
        stages: [800, 1800, 3200, 6400, 12000].map {
            FfiDpiStage(id: newId(), x: $0, y: $0)
        }
    )
}

public func migrateButtons(_ buttons: [FfiButtonBinding]?, plate: String) -> [FfiButtonBinding] {
    let expected = buildButtonsForPlate(plate)
    guard let buttons else { return expected }

    let isLegacy = buttons.first(where: { $0.id == "base-6" })?.action == "dpi-up"
    if isLegacy {
        let sideById = Dictionary(uniqueKeysWithValues: buttons.filter { $0.id.hasPrefix("side-") }.map { ($0.id, $0) })
        return expected.map { entry in
            if entry.id.hasPrefix("side-") {
                return sideById[entry.id] ?? entry
            }
            return entry
        }
    }

    let byId = Dictionary(uniqueKeysWithValues: buttons.map { ($0.id, $0) })
    return expected.map { byId[$0.id] ?? $0 }
}

private func mergeRgb(_ incoming: [String: Any]?) -> FfiRgbSettings {
    var rgb = defaultRgb()
    guard let obj = incoming else { return rgb }
    if let v = obj["effect"] as? String { rgb.effect = v }
    if let v = obj["color"] as? String { rgb.color = v }
    if let v = obj["secondaryColor"] as? String { rgb.secondaryColor = v }
    if let v = obj["brightness"] as? Int { rgb.brightness = UInt8(clamping: v) }
    if let v = obj["waveDirection"] as? String { rgb.waveDirection = v }
    if let v = obj["reactiveSpeed"] as? Int { rgb.reactiveSpeed = UInt8(clamping: v) }
    if let v = obj["syncZones"] as? Bool { rgb.syncZones = v }
    if let zones = obj["zones"] as? [String: Any] {
        if let z = zones["logo"] as? [String: Any] {
            rgb.zones.logo = FfiZoneConfig(
                enabled: z["enabled"] as? Bool ?? rgb.zones.logo.enabled,
                color: z["color"] as? String ?? rgb.zones.logo.color
            )
        }
        if let z = zones["scroll"] as? [String: Any] {
            rgb.zones.scroll = FfiZoneConfig(
                enabled: z["enabled"] as? Bool ?? rgb.zones.scroll.enabled,
                color: z["color"] as? String ?? rgb.zones.scroll.color
            )
        }
        if let z = zones["side"] as? [String: Any] {
            rgb.zones.side = FfiZoneConfig(
                enabled: z["enabled"] as? Bool ?? rgb.zones.side.enabled,
                color: z["color"] as? String ?? rgb.zones.side.color
            )
        }
    }
    return rgb
}

private func mergeDpi(_ incoming: [String: Any]?) -> FfiDpiSettings {
    let base = defaultDpi()
    guard let obj = incoming else { return base }
    let activeStage = UInt8(clamping: obj["activeStage"] as? Int ?? Int(base.activeStage))

    if let stages = obj["stages"] as? [[String: Any]], !stages.isEmpty {
        let parsed: [FfiDpiStage] = stages.compactMap { (s) -> FfiDpiStage? in
            guard let id = s["id"] as? String else { return nil }
            let xInt = s["x"] as? Int ?? 800
            let yInt = s["y"] as? Int ?? xInt
            return FfiDpiStage(id: id, x: UInt16(clamping: xInt), y: UInt16(clamping: yInt))
        }
        if !parsed.isEmpty {
            return FfiDpiSettings(activeStage: activeStage, stages: parsed)
        }
    }

    if let x = obj["x"] as? Int, let y = obj["y"] as? Int {
        return FfiDpiSettings(
            activeStage: activeStage,
            stages: [FfiDpiStage(id: newId(), x: UInt16(clamping: x), y: UInt16(clamping: y))]
        )
    }

    return FfiDpiSettings(activeStage: activeStage, stages: base.stages)
}

private func decodeButtons(_ value: Any?) -> [FfiButtonBinding]? {
    guard let value, JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value),
          let buttons = try? JSONDecoder().decode([FfiButtonBinding].self, from: data)
    else { return nil }
    return buttons
}

private func decodeMacros(_ value: Any?) -> [FfiMacro]? {
    guard let value, JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value),
          let macros = try? JSONDecoder().decode([FfiMacro].self, from: data)
    else { return nil }
    return macros
}

private func createDefaultProfileFromPartial(_ partial: [String: Any]) -> FfiNagaProfile {
    let now = nowMs()
    let plate = (partial["sidePlate"] as? String) ?? "twelve"
    let buttons = decodeButtons(partial["buttons"])
    let macros = decodeMacros(partial["macros"])
    let polling: UInt16
    if let p = partial["pollingRate"] as? Int {
        polling = UInt16(clamping: p)
    } else {
        polling = 1000
    }
    return FfiNagaProfile(
        id: (partial["id"] as? String) ?? newId(),
        name: (partial["name"] as? String) ?? "Standardprofil",
        sidePlate: plate,
        rgb: mergeRgb(partial["rgb"] as? [String: Any]),
        dpi: mergeDpi(partial["dpi"] as? [String: Any]),
        pollingRate: PollingRate(hz: polling).rawValue,
        buttons: migrateButtons(buttons, plate: plate),
        macros: macros ?? [createDefaultMacro()],
        createdAt: (partial["createdAt"] as? Int).map { Int64($0) } ?? now,
        updatedAt: (partial["updatedAt"] as? Int).map { Int64($0) } ?? now
    )
}

public func createDefaultProfile(name: String = "Standardprofil") -> FfiNagaProfile {
    createDefaultProfileFromPartial(["name": name])
}

public func createInitialStore() -> FfiProfileStore {
    let profile = createDefaultProfileFromPartial(["name": "Raid / Produktiv"])
    return FfiProfileStore(
        version: storeVersion,
        activeProfileId: profile.id,
        profiles: [profile],
        settings: defaultSettings()
    )
}

public func migrate(_ raw: Any) -> FfiProfileStore {
    if let arr = raw as? [[String: Any]] {
        let profiles = arr.map(createDefaultProfileFromPartial)
        if profiles.isEmpty { return createInitialStore() }
        return FfiProfileStore(
            version: storeVersion,
            activeProfileId: profiles[0].id,
            profiles: profiles,
            settings: nil
        )
    }

    if let obj = raw as? [String: Any], obj["profiles"] != nil {
        let settingsObj = obj["settings"] as? [String: Any]
        let settings: FfiAppSettings? = {
            guard let settingsObj else { return nil }
            return mergeSettings(
                FfiAppSettings(
                    rgbOffOnLock: settingsObj["rgbOffOnLock"] as? Bool ?? true,
                    language: settingsObj["language"] as? String
                )
            )
        }()

        let profiles: [FfiNagaProfile]
        if let arr = obj["profiles"] as? [[String: Any]] {
            profiles = arr.map(createDefaultProfileFromPartial)
        } else {
            profiles = []
        }
        if profiles.isEmpty { return createInitialStore() }

        let active = obj["activeProfileId"] as? String
        let activeProfileId = active.flatMap { id in profiles.contains(where: { $0.id == id }) ? id : nil }
            ?? profiles[0].id

        return FfiProfileStore(
            version: storeVersion,
            activeProfileId: activeProfileId,
            profiles: profiles,
            settings: settings
        )
    }

    return createInitialStore()
}

public final class ProfileStoreService: @unchecked Sendable {
    private let lock = NSLock()
    private var fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("profiles.json")
    }

    public func setDirectory(_ directory: URL) {
        lock.lock()
        defer { lock.unlock() }
        fileURL = directory.appendingPathComponent("profiles.json")
    }

    public func path() -> URL {
        lock.lock()
        defer { lock.unlock() }
        return fileURL
    }

    public func read() -> FfiProfileStore {
        let url = path()
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data)
        else {
            return createInitialStore()
        }
        return migrate(raw)
    }

    public func write(_ store: FfiProfileStore) -> FfiProfileStore {
        let next = FfiProfileStore(
            version: storeVersion,
            activeProfileId: store.activeProfileId,
            profiles: store.profiles,
            settings: mergeSettings(store.settings)
        )
        let url = path()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(next) {
            try? data.write(to: url, options: .atomic)
        }
        return next
    }

    public func upsertProfile(_ profile: FfiNagaProfile) -> FfiProfileStore {
        var store = read()
        var stamped = profile
        stamped.updatedAt = nowMs()
        if let idx = store.profiles.firstIndex(where: { $0.id == stamped.id }) {
            store.profiles[idx] = stamped
        } else {
            store.profiles.append(stamped)
        }
        return write(store)
    }

    public func deleteProfile(id: String) -> FfiProfileStore {
        var store = read()
        store.profiles.removeAll { $0.id == id }
        if store.profiles.isEmpty {
            store.profiles.append(createDefaultProfile())
        }
        if store.activeProfileId == id {
            store.activeProfileId = store.profiles[0].id
        }
        return write(store)
    }

    public func duplicateProfile(id: String) -> FfiProfileStore {
        let store = read()
        guard let source = store.profiles.first(where: { $0.id == id }) else { return store }
        var partial: [String: Any] = [
            "id": newId(),
            "name": "\(source.name) – Kopie",
            "sidePlate": source.sidePlate,
            "pollingRate": Int(source.pollingRate),
        ]
        if let rgbData = try? JSONEncoder().encode(source.rgb),
           let rgbObj = try? JSONSerialization.jsonObject(with: rgbData) {
            partial["rgb"] = rgbObj
        }
        if let dpiData = try? JSONEncoder().encode(source.dpi),
           let dpiObj = try? JSONSerialization.jsonObject(with: dpiData) {
            partial["dpi"] = dpiObj
        }
        if let buttonsData = try? JSONEncoder().encode(source.buttons),
           let buttonsObj = try? JSONSerialization.jsonObject(with: buttonsData) {
            partial["buttons"] = buttonsObj
        }
        if let macrosData = try? JSONEncoder().encode(source.macros),
           let macrosObj = try? JSONSerialization.jsonObject(with: macrosData) {
            partial["macros"] = macrosObj
        }
        let copy = createDefaultProfileFromPartial(partial)
        var next = store
        next.activeProfileId = copy.id
        next.profiles.append(copy)
        return write(next)
    }

    public func setActiveProfile(id: String) -> FfiProfileStore {
        var store = read()
        guard store.profiles.contains(where: { $0.id == id }) else { return store }
        store.activeProfileId = id
        return write(store)
    }

    public func getSettings() -> FfiAppSettings {
        mergeSettings(read().settings)
    }

    public func updateSettings(rgbOffOnLock: Bool?, language: String?) -> FfiAppSettings {
        var store = read()
        var settings = mergeSettings(store.settings)
        if let rgbOffOnLock {
            settings.rgbOffOnLock = rgbOffOnLock
        }
        if language != nil {
            settings.language = language
        }
        store.settings = settings
        _ = write(store)
        return settings
    }
}
