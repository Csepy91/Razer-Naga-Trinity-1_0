import Foundation

public let razerVendorId: UInt16 = 0x1532
public let nagaTrinityProductId: UInt16 = 0x0067
public let storeVersion: UInt32 = 2

public struct FfiAppSettings: Codable, Equatable, Sendable, Hashable {
    public var rgbOffOnLock: Bool
    public var language: String?

    public init(rgbOffOnLock: Bool, language: String?) {
        self.rgbOffOnLock = rgbOffOnLock
        self.language = language
    }
}

public struct FfiApplyResult: Equatable, Sendable, Hashable {
    public var ok: Bool
    public var message: String
    public var key: String?
    public var params: [String: String]
    public var stage: String?

    public init(ok: Bool, message: String, key: String?, params: [String: String], stage: String?) {
        self.ok = ok
        self.message = message
        self.key = key
        self.params = params
        self.stage = stage
    }

    public static func okWith(key: String, message: String) -> FfiApplyResult {
        FfiApplyResult(ok: true, message: message, key: key, params: [:], stage: nil)
    }

    public static func notFound() -> FfiApplyResult {
        FfiApplyResult(
            ok: false,
            message: "Razer Naga Trinity not found.",
            key: "driverNotices.notFound",
            params: [:],
            stage: nil
        )
    }

    public static func usbError(_ detail: String) -> FfiApplyResult {
        FfiApplyResult(
            ok: false,
            message: detail.isEmpty ? "Unbekannter USB-Fehler." : detail,
            key: "driverNotices.usbError",
            params: ["detail": detail],
            stage: nil
        )
    }
}

public struct FfiButtonBinding: Codable, Equatable, Sendable, Hashable {
    public var id: String
    public var label: String
    public var hardwareIndex: UInt8
    public var action: String
    public var value: String
    public var macroId: String?

    public init(id: String, label: String, hardwareIndex: UInt8, action: String, value: String, macroId: String?) {
        self.id = id
        self.label = label
        self.hardwareIndex = hardwareIndex
        self.action = action
        self.value = value
        self.macroId = macroId
    }

    enum CodingKeys: String, CodingKey {
        case id, label, hardwareIndex, action, value, macroId
    }
}

public struct FfiDeviceInfo: Codable, Equatable, Sendable, Hashable {
    public var connected: Bool
    public var productName: String?
    public var manufacturer: String?
    public var vendorId: UInt16?
    public var productId: UInt16?
    public var interfaces: UInt8

    public init(
        connected: Bool,
        productName: String?,
        manufacturer: String?,
        vendorId: UInt16?,
        productId: UInt16?,
        interfaces: UInt8
    ) {
        self.connected = connected
        self.productName = productName
        self.manufacturer = manufacturer
        self.vendorId = vendorId
        self.productId = productId
        self.interfaces = interfaces
    }
}

public struct FfiDpiStage: Codable, Equatable, Sendable, Hashable {
    public var id: String
    public var x: UInt16
    public var y: UInt16

    public init(id: String, x: UInt16, y: UInt16) {
        self.id = id
        self.x = x
        self.y = y
    }
}

public struct FfiDpiSettings: Codable, Equatable, Sendable, Hashable {
    public var activeStage: UInt8
    public var stages: [FfiDpiStage]

    public init(activeStage: UInt8, stages: [FfiDpiStage]) {
        self.activeStage = activeStage
        self.stages = stages
    }
}

public struct FfiMacroStep: Codable, Equatable, Sendable, Hashable {
    public var id: String
    public var stepType: String
    public var value: String
    public var delayMs: UInt32

    public init(id: String, stepType: String, value: String, delayMs: UInt32) {
        self.id = id
        self.stepType = stepType
        self.value = value
        self.delayMs = delayMs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case stepType = "type"
        case value
        case delayMs
    }
}

public struct FfiMacro: Codable, Equatable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var steps: [FfiMacroStep]
    public var repeatMode: String
    public var repeatCount: UInt32

    public init(id: String, name: String, steps: [FfiMacroStep], repeatMode: String, repeatCount: UInt32) {
        self.id = id
        self.name = name
        self.steps = steps
        self.repeatMode = repeatMode
        self.repeatCount = repeatCount
    }
}

public struct FfiZoneConfig: Codable, Equatable, Sendable, Hashable {
    public var enabled: Bool
    public var color: String

    public init(enabled: Bool, color: String) {
        self.enabled = enabled
        self.color = color
    }
}

public struct FfiRgbZones: Codable, Equatable, Sendable, Hashable {
    public var logo: FfiZoneConfig
    public var scroll: FfiZoneConfig
    public var side: FfiZoneConfig

    public init(logo: FfiZoneConfig, scroll: FfiZoneConfig, side: FfiZoneConfig) {
        self.logo = logo
        self.scroll = scroll
        self.side = side
    }
}

public struct FfiRgbSettings: Codable, Equatable, Sendable, Hashable {
    public var effect: String
    public var color: String
    public var secondaryColor: String
    public var brightness: UInt8
    public var waveDirection: String
    public var reactiveSpeed: UInt8
    public var syncZones: Bool
    public var zones: FfiRgbZones

    public init(
        effect: String,
        color: String,
        secondaryColor: String,
        brightness: UInt8,
        waveDirection: String,
        reactiveSpeed: UInt8,
        syncZones: Bool,
        zones: FfiRgbZones
    ) {
        self.effect = effect
        self.color = color
        self.secondaryColor = secondaryColor
        self.brightness = brightness
        self.waveDirection = waveDirection
        self.reactiveSpeed = reactiveSpeed
        self.syncZones = syncZones
        self.zones = zones
    }
}

public struct FfiNagaProfile: Codable, Equatable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var sidePlate: String
    public var rgb: FfiRgbSettings
    public var dpi: FfiDpiSettings
    public var pollingRate: UInt16
    public var buttons: [FfiButtonBinding]
    public var macros: [FfiMacro]
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: String,
        name: String,
        sidePlate: String,
        rgb: FfiRgbSettings,
        dpi: FfiDpiSettings,
        pollingRate: UInt16,
        buttons: [FfiButtonBinding],
        macros: [FfiMacro],
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.name = name
        self.sidePlate = sidePlate
        self.rgb = rgb
        self.dpi = dpi
        self.pollingRate = pollingRate
        self.buttons = buttons
        self.macros = macros
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FfiProfileStore: Codable, Equatable, Sendable, Hashable {
    public var version: UInt32
    public var activeProfileId: String
    public var profiles: [FfiNagaProfile]
    public var settings: FfiAppSettings?

    public init(version: UInt32, activeProfileId: String, profiles: [FfiNagaProfile], settings: FfiAppSettings?) {
        self.version = version
        self.activeProfileId = activeProfileId
        self.profiles = profiles
        self.settings = settings
    }
}

public struct FfiSettingsPartial: Equatable, Sendable, Hashable {
    public var rgbOffOnLock: Bool?
    public var language: String?

    public init(rgbOffOnLock: Bool?, language: String?) {
        self.rgbOffOnLock = rgbOffOnLock
        self.language = language
    }
}

public enum LedZone: String {
    case logo
    case scroll
    case side
}

public enum PollingRate: UInt16 {
    case hz125 = 125
    case hz500 = 500
    case hz1000 = 1000

    public init(hz: UInt16) {
        switch hz {
        case 125: self = .hz125
        case 500: self = .hz500
        default: self = .hz1000
        }
    }
}
