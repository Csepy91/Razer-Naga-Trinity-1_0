import Foundation

enum Constants {
    static let rgbEffectIds = ["static", "breathing", "spectrum", "wave", "reactive", "off"]

    static let pollingRates: [(value: UInt16, label: String, sublabelKey: String)] = [
        (125, "125 Hz", "polling.lowSub"),
        (500, "500 Hz", "polling.midSub"),
        (1000, "1000 Hz", "polling.highSub"),
    ]

    static let sidePlateIds = ["two", "seven", "twelve"]

    static let sidePlateButtons: [String: Int] = [
        "two": 2,
        "seven": 7,
        "twelve": 12,
    ]

    static let dpiPresets: [UInt16] = [400, 800, 1600, 1800, 3200, 6400, 12000, 16000]

    static let colorSwatches = [
        "#00ff66",
        "#00d9ff",
        "#7c5cff",
        "#ff3ea5",
        "#ff7a00",
        "#ffd60a",
        "#ff2d55",
        "#a3ff12",
    ]

    static let buttonActionIds = [
        "default",
        "key",
        "macro",
        "dpi-up",
        "dpi-down",
        "dpi-cycle",
        "profile-cycle",
        "mouse-button",
        "disabled",
    ]

    static let mouseButtons = ["Mouse 1", "Mouse 2", "Mouse 3", "Mouse 4", "Mouse 5"]

    static let reactiveSpeeds: [(value: UInt8, labelKey: String)] = [
        (1, "reactive.fast"),
        (2, "reactive.medium"),
        (3, "reactive.slow"),
        (4, "reactive.verySlow"),
    ]

    static let zoneIds = ["logo", "scroll", "side"]
    static let repeatModeIds = ["once", "count", "while-held", "toggle"]
    static let stepTypeIds = ["key", "text", "mouse", "delay"]
    static let sectionIds = ["lighting", "performance", "buttons", "macros"]

    static let supportedLanguages = ["de", "en"]
}
