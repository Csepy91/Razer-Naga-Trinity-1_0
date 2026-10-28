import Foundation

public let razerSideButtonSourceOffset: UInt8 = 0x40

/// Razer default HID for side buttons 1–12: keys 1–0, `-`, `=`.
public let razerDefaultSideHid: [UInt8] = [
    0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2d, 0x2e,
]

/// Macro mapping: F13–F24.
public let sideButtonMacroHid: [UInt8] = [
    0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73,
]

public struct SideKeyStroke: Equatable, Sendable {
    public var modifiers: UInt8
    public var hid: UInt8

    public init(modifiers: UInt8 = 0, hid: UInt8) {
        self.modifiers = modifiers
        self.hid = hid
    }

    public static func plain(_ hid: UInt8) -> SideKeyStroke {
        SideKeyStroke(modifiers: 0, hid: hid)
    }
}

public func encodeSideButtonBinding(slot: UInt8, buttonIndex: UInt8, stroke: SideKeyStroke) -> Report {
    var report = createReport(
        commandClass: buttonClass,
        commandId: 0x0c,
        dataSize: 0x0a,
        transactionId: txTrinityEffect
    )
    report[8] = slot
    report[9] = razerSideButtonSourceOffset &+ (buttonIndex &- 1)
    report[10] = 0x00
    report[11] = 0x02
    report[12] = 0x02
    report[13] = stroke.modifiers
    report[14] = stroke.hid
    return finalize(report)
}

public func encodeWheelTiltBinding(slot: UInt8, source: UInt8, action: UInt8) -> Report {
    var report = createReport(
        commandClass: buttonClass,
        commandId: 0x0c,
        dataSize: 0x0a,
        transactionId: txTrinityEffect
    )
    report[8] = slot
    report[9] = source
    report[10] = 0x00
    report[11] = 0x01
    report[12] = 0x01
    report[13] = action
    return finalize(report)
}

public func parseKeyBinding(_ value: String) -> SideKeyStroke? {
    let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty { return nil }

    var modifiers: UInt8 = 0
    var rest = raw
    while let idx = rest.firstIndex(of: "+") {
        let head = String(rest[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(rest[rest.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if head.isEmpty || tail.isEmpty { break }
        guard let bit = modifierBit(head) else { break }
        modifiers |= bit
        rest = tail
    }

    guard let key = parseSingleToken(rest) else { return nil }
    return SideKeyStroke(modifiers: modifiers | key.modifiers, hid: key.hid)
}

public func hidCodeForKey(_ value: String) -> UInt8? {
    parseKeyBinding(value)?.hid
}

private func parseSingleToken(_ token: String) -> SideKeyStroke? {
    let lower = token.lowercased()
    if let hid = namedKeyHid(lower) {
        return .plain(hid)
    }
    if lower.hasPrefix("f"), let n = UInt8(lower.dropFirst()) {
        let hid: UInt8?
        switch n {
        case 1...12: hid = 0x3a + (n - 1)
        case 13...24: hid = 0x68 + (n - 13)
        default: hid = nil
        }
        if let hid { return .plain(hid) }
    }
    if let stroke = numpadKeyHid(lower) {
        return stroke
    }
    if token.count == 1, let c = token.first {
        return charToStroke(c)
    }
    return nil
}

private func modifierBit(_ name: String) -> UInt8? {
    switch name.lowercased() {
    case "ctrl", "control", "lctrl", "leftctrl", "strg", "steuerung": return 0x01
    case "shift", "lshift", "leftshift", "umschalt": return 0x02
    case "alt", "option", "lalt", "leftalt": return 0x04
    case "gui", "cmd", "command", "meta", "win", "super", "lgui", "leftgui": return 0x08
    case "rctrl", "rightctrl": return 0x10
    case "rshift", "rightshift": return 0x20
    case "ralt", "rightalt", "altgr": return 0x40
    case "rgui", "rightgui", "rightcmd": return 0x80
    default: return nil
    }
}

private func namedKeyHid(_ lower: String) -> UInt8? {
    switch lower {
    case "enter", "return": return 0x28
    case "esc", "escape": return 0x29
    case "backspace", "bksp", "back": return 0x2a
    case "tab": return 0x2b
    case "space", "spacebar": return 0x2c
    case "capslock", "caps": return 0x39
    case "printscreen", "prtsc", "print", "snapshot": return 0x46
    case "scrolllock", "scroll": return 0x47
    case "pause", "break": return 0x48
    case "insert", "ins": return 0x49
    case "home": return 0x4a
    case "pageup", "pgup": return 0x4b
    case "delete", "del": return 0x4c
    case "end": return 0x4d
    case "pagedown", "pgdn": return 0x4e
    case "arrowright", "right": return 0x4f
    case "arrowleft", "left": return 0x50
    case "arrowdown", "down": return 0x51
    case "arrowup", "up": return 0x52
    case "application", "menu", "app", "contextmenu": return 0x65
    case "lctrl", "ctrl", "control", "leftctrl", "strg", "steuerung": return 0xe0
    case "lshift", "shift", "leftshift", "umschalt": return 0xe1
    case "lalt", "alt", "option", "leftalt": return 0xe2
    case "lgui", "cmd", "command", "meta", "win", "super", "leftgui": return 0xe3
    case "rctrl", "rightctrl": return 0xe4
    case "rshift", "rightshift": return 0xe5
    case "ralt", "rightalt", "altgr": return 0xe6
    case "rgui", "rightgui", "rightcmd": return 0xe7
    default: return nil
    }
}

private func numpadKeyHid(_ lower: String) -> SideKeyStroke? {
    let rest: String
    if lower.hasPrefix("numpad") {
        rest = String(lower.dropFirst(6))
    } else if lower.hasPrefix("num") {
        rest = String(lower.dropFirst(3))
    } else if lower.hasPrefix("kp") {
        rest = String(lower.dropFirst(2))
    } else {
        return nil
    }
    let hid: UInt8
    switch rest {
    case "0": hid = 0x62
    case "1": hid = 0x59
    case "2": hid = 0x5a
    case "3": hid = 0x5b
    case "4": hid = 0x5c
    case "5": hid = 0x5d
    case "6": hid = 0x5e
    case "7": hid = 0x5f
    case "8": hid = 0x60
    case "9": hid = 0x61
    case "enter", "return": hid = 0x58
    case "/", "divide", "div": hid = 0x54
    case "*", "multiply", "mul": hid = 0x55
    case "-", "minus", "sub": hid = 0x56
    case "+", "plus", "add": hid = 0x57
    case ".", "decimal", "dot", "comma": hid = 0x63
    case "=", "equal": hid = 0x67
    default: return nil
    }
    return .plain(hid)
}

private func charToStroke(_ c: Character) -> SideKeyStroke? {
    if let hid: UInt8 = {
        switch c {
        case "a"..."z": return 0x04 + UInt8(c.asciiValue! - Character("a").asciiValue!)
        case "A"..."Z": return 0x04 + UInt8(c.asciiValue! - Character("A").asciiValue!)
        case "1"..."9": return 0x1e + UInt8(c.asciiValue! - Character("1").asciiValue!)
        case "0": return 0x27
        case "-": return 0x2d
        case "=": return 0x2e
        case "[": return 0x2f
        case "]": return 0x30
        case "\\": return 0x31
        case ";": return 0x33
        case "'": return 0x34
        case "`": return 0x35
        case ",": return 0x36
        case ".": return 0x37
        case "/": return 0x38
        default: return nil
        }
    }() {
        return .plain(hid)
    }

    let shift: UInt8 = 0x02
    let hid: UInt8
    switch c {
    case "!": hid = 0x1e
    case "@": hid = 0x1f
    case "#": hid = 0x20
    case "$": hid = 0x21
    case "%": hid = 0x22
    case "^": hid = 0x23
    case "&": hid = 0x24
    case "*": hid = 0x25
    case "(": hid = 0x26
    case ")": hid = 0x27
    case "_": hid = 0x2d
    case "+": hid = 0x2e
    case "{": hid = 0x2f
    case "}": hid = 0x30
    case "|": hid = 0x31
    case ":": hid = 0x33
    case "\"": hid = 0x34
    case "~": hid = 0x35
    case "<": hid = 0x36
    case ">": hid = 0x37
    case "?": hid = 0x38
    default: return nil
    }
    return SideKeyStroke(modifiers: shift, hid: hid)
}

private func hardwareSlotForSide(profile: FfiNagaProfile, sideIndex0: Int) -> Int? {
    switch profile.sidePlate {
    case "two":
        switch sideIndex0 {
        case 0: return 11 // side-1 (top) → button 12
        case 1: return 8 // side-2 (bottom) → button 9
        default: return nil
        }
    case "seven", "twelve":
        return sideIndex0 < 12 ? sideIndex0 : nil
    default:
        return sideIndex0 < 12 ? sideIndex0 : nil
    }
}

/// Build the 12 side-button strokes from a profile.
public func buildSideBindings(_ profile: FfiNagaProfile) -> [SideKeyStroke] {
    var codes = razerDefaultSideHid.map(SideKeyStroke.plain)

    switch profile.sidePlate {
    case "twelve":
        return codes
    case "seven":
        codes[0] = .plain(0x59)
        codes[1] = .plain(0x5a)
        codes[2] = .plain(0x5b)
        return codes
    default:
        break
    }

    for i in 0..<12 {
        let id = "side-\(i + 1)"
        guard let binding = profile.buttons.first(where: { $0.id == id }) else { continue }
        let remap: Bool
        switch binding.action {
        case "macro": remap = binding.macroId != nil
        case "key": remap = !binding.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: remap = false
        }
        guard remap, let slot = hardwareSlotForSide(profile: profile, sideIndex0: i) else { continue }
        codes[slot] = .plain(sideButtonMacroHid[i])
    }
    return codes
}
