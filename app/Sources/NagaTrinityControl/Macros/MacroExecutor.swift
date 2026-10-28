import CoreGraphics
import Foundation
import NagaCore
import os

enum MacroExecutor {
    private static let logger = Logger(subsystem: "local.naga-trinity-control", category: "MacroExecutor")

    private static let specialKeyCodes: [String: CGKeyCode] = [
        "Enter": 36,
        "Return": 36,
        "Tab": 48,
        "Space": 49,
        "Backspace": 51,
        "Esc": 53,
        "Escape": 53,
        "ArrowLeft": 123,
        "ArrowRight": 124,
        "ArrowDown": 125,
        "ArrowUp": 126,
    ]

    /// Inject a side-button key binding (`A`, `É`, `Ctrl+C`, `F5`, …).
    static func injectKeystroke(_ value: String) {
        Task.detached(priority: .userInitiated) {
            injectKeystrokeSync(value)
        }
    }

    static func execute(_ macro: FfiMacro) {
        Task.detached(priority: .userInitiated) {
            await run(macro)
        }
    }

    private static func run(_ macro: FfiMacro) async {
        let cycles: Int
        if macro.repeatMode == "count" {
            cycles = max(1, Int(macro.repeatCount))
        } else {
            cycles = 1
        }

        logger.info("macro start: \(macro.name, privacy: .public) cycles=\(cycles)")
        for _ in 0..<cycles {
            for step in macro.steps {
                switch step.stepType {
                case "text":
                    guard !step.value.isEmpty else { continue }
                    postUnicode(step.value)
                case "key":
                    injectKeystrokeSync(step.value)
                case "delay":
                    if step.delayMs > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(step.delayMs) * 1_000_000)
                    }
                    continue
                case "mouse":
                    break
                default:
                    break
                }
                if step.delayMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.delayMs) * 1_000_000)
                }
            }
        }
        logger.info("macro done: \(macro.name, privacy: .public)")
    }

    private static func injectKeystrokeSync(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        let (flags, key) = peelModifiers(value)

        if let code = specialKeyCodes[key] ?? specialKeyCodes[key.capitalized] {
            postKey(code, flags: flags)
            return
        }

        // Named modifier alone (e.g. binding value "Shift") — no chord left.
        if flags.rawValue != 0, key.isEmpty {
            return
        }

        // Chords need virtual key codes + modifier flags.
        if flags.rawValue != 0 {
            if let code = virtualKeyCode(for: key) {
                postKey(code, flags: flags)
            }
            return
        }

        // Plain characters: always unicode so HU/DE layouts don't remap US keycodes
        // (e.g. kc for "A" must not become some other glyph).
        postUnicode(key)
    }

    /// Peel `Ctrl+` / `Shift+` / … prefixes. Returns remaining key token.
    private static func peelModifiers(_ value: String) -> (CGEventFlags, String) {
        var flags: CGEventFlags = []
        var rest = value
        while true {
            guard let idx = rest.firstIndex(of: "+") else { break }
            let head = String(rest[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tail = String(rest[rest.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !head.isEmpty, !tail.isEmpty, let bit = modifierFlag(head) else { break }
            flags.insert(bit)
            rest = tail
        }
        return (flags, rest)
    }

    private static func modifierFlag(_ name: String) -> CGEventFlags? {
        switch name.lowercased() {
        case "ctrl", "control", "strg", "steuerung": return .maskControl
        case "shift", "umschalt": return .maskShift
        case "alt", "option": return .maskAlternate
        case "cmd", "command", "meta", "win", "super", "gui": return .maskCommand
        default: return nil
        }
    }

    private static func virtualKeyCode(for key: String) -> CGKeyCode? {
        if let code = specialKeyCodes[key] ?? specialKeyCodes[key.capitalized] {
            return code
        }
        guard key.count == 1, let scalar = key.unicodeScalars.first else { return nil }
        let c = Character(scalar)
        switch c {
        case "a"..."z":
            // macOS virtual key codes for ANSI letters (CGEvent / Carbon).
            let letters: [Character: CGKeyCode] = [
                "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
                "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
                "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
                "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
            ]
            return letters[c]
        case "A"..."Z":
            return virtualKeyCode(for: String(c).lowercased())
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25
        case "0": return 29
        default:
            return nil
        }
    }

    /// Marker so our event taps ignore keys we inject ourselves.
    private static let injectionUserData: Int64 = 0x4E_41_47_41 // 'NAGA'

    private static func postKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: injectionUserData)
        up.setIntegerValueField(.eventSourceUserData, value: injectionUserData)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private static func postUnicode(_ string: String) {
        let chars = Array(string.utf16)
        guard !chars.isEmpty else { return }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        else { return }
        chars.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: base)
            up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: base)
        }
        down.setIntegerValueField(.eventSourceUserData, value: injectionUserData)
        up.setIntegerValueField(.eventSourceUserData, value: injectionUserData)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
