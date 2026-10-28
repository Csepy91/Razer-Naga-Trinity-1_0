import ApplicationServices
import CoreFoundation
import CoreGraphics
import Foundation
import NagaCore
import os

/// Side-button input:
/// - FPS: Mouse 4/5 via CGEventTap
/// - 7/12: IOHID arm-to-swallow + F-key / digit CGEventTap (digits only from
///   learned Naga keyboardType so the Mac keyboard is not hijacked)
@MainActor
final class DeviceKeyMonitor {
    struct ListenResult: Equatable {
        var ok: Bool
        var seized: Bool
        var message: String
    }

    enum HotAction {
        case macro(FfiMacro)
        case key(String)
    }

    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "DeviceKeyMonitor")
    private let hidKeyboard = NagaHidKeyboardMonitor()
    private var taps: [CFMachPort] = []
    private var runLoopSources: [CFRunLoopSource] = []

    private nonisolated(unsafe) var actionsByKeyCode: [Int64: HotAction] = [:]
    private nonisolated(unsafe) var digitActionsByKeyCode: [Int64: HotAction] = [:]
    private nonisolated(unsafe) var actionsByMouseButton: [Int64: HotAction] = [:]
    private nonisolated(unsafe) var tapPorts: [CFMachPort] = []
    private nonisolated(unsafe) var lastFireUptime: UInt64 = 0
    private nonisolated(unsafe) var swallowUntil: [Int64: UInt64] = [:]
    private nonisolated(unsafe) var nagaKeyboardTypes: Set<Int64> = []

    private static let fpsMouseButtons: [Int64] = [4, 3]
    private static let digitKeyCodes: [Int64] = [
        18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24,
    ]
    /// Keypad 1–3 macOS keycodes — seven-plate slots 1–3 after apply.
    private static let sevenSafeKeyCodes: [Int64] = [83, 84, 85]
    private static let f13to15KeyCodes: [Int64] = [0x69, 0x6B, 0x71]

    func stop() {
        hidKeyboard.stop()
        for tap in taps {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        for source in runLoopSources {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        taps = []
        tapPorts = []
        runLoopSources = []
        actionsByKeyCode = [:]
        digitActionsByKeyCode = [:]
        actionsByMouseButton = [:]
        swallowUntil = [:]
        nagaKeyboardTypes = []
    }

    nonisolated func armSwallow(keyCodes: [Int64]) {
        let deadline = DispatchTime.now().uptimeNanoseconds &+ 100_000_000
        for code in keyCodes {
            swallowUntil[code] = deadline
        }
    }

    @discardableResult
    func start(profile: FfiNagaProfile) -> ListenResult {
        stop()
        let isFpsPlate = profile.sidePlate == "two"
        let sideActions = Self.buildSideActions(profile: profile)
        guard !sideActions.isEmpty else {
            return ListenResult(ok: true, seized: false, message: "no side bindings")
        }

        let keyActions = Self.buildKeyCodeActions(profile: profile, sideActions: sideActions)
        let digitActions = isFpsPlate ? [:] : Self.buildDigitActions(sideActions: sideActions)
        let mouseActions = isFpsPlate ? Self.buildMouseButtonActions(sideActions: sideActions) : [:]
        actionsByKeyCode = keyActions
        digitActionsByKeyCode = digitActions
        actionsByMouseButton = mouseActions

        let hid = hidKeyboard.start(profile: profile, sideActions: sideActions, eventTap: self)

        var tapOk = false
        let needsKeyTap = !keyActions.isEmpty || !digitActions.isEmpty || hid.ok
        let needsMouseTap = !mouseActions.isEmpty
        if needsKeyTap || needsMouseTap {
            if Accessibility.isTrusted() {
                tapOk = installEventTaps(watchKeys: needsKeyTap, watchMouse: needsMouseTap)
            } else {
                logger.warning("CGEventTap skipped — Accessibility not trusted")
            }
        }

        let ok = isFpsPlate ? tapOk : (hid.ok || tapOk)
        guard ok else {
            return ListenResult(
                ok: false,
                seized: false,
                message: !Accessibility.isTrusted() ? "accessibility required" : hid.message
            )
        }

        logger.info(
            "side monitor hid=\(hid.ok) tap=\(tapOk) fkeys=\(keyActions.count) digits=\(digitActions.count)"
        )
        return ListenResult(
            ok: true,
            seized: hid.ok || isFpsPlate,
            message: [hid.ok ? hid.message : nil, tapOk ? "event tap active" : nil]
                .compactMap { $0 }
                .joined(separator: "; ")
        )
    }

    private func installEventTaps(watchKeys: Bool, watchMouse: Bool) -> Bool {
        var mask =
            CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)
        if watchKeys {
            mask |= CGEventMask(1 << CGEventType.keyDown.rawValue)
            mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
        }
        if watchMouse {
            mask |= CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            mask |= CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        var installed = 0
        for location in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap] {
            guard let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                    guard let refcon else { return Unmanaged.passUnretained(event) }
                    let monitor = Unmanaged<DeviceKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    return monitor.handleEvent(type: type, event: event)
                },
                userInfo: context
            ) else { continue }
            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                continue
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            taps.append(tap)
            tapPorts.append(tap)
            runLoopSources.append(source)
            installed += 1
        }
        return installed > 0
    }

    private nonisolated func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            for tap in tapPorts {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == 0x4E_41_47_41 {
            return Unmanaged.passUnretained(event)
        }

        if type == .otherMouseDown || type == .otherMouseUp {
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            guard let action = actionsByMouseButton[button] else {
                return Unmanaged.passUnretained(event)
            }
            if type == .otherMouseDown {
                fireDebounced(action, label: "mouseBtn=\(button)")
            }
            return nil
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let kbType = event.getIntegerValueField(.keyboardEventKeyboardType)
        let now = DispatchTime.now().uptimeNanoseconds

        if let deadline = swallowUntil[keyCode], now < deadline {
            nagaKeyboardTypes.insert(kbType)
            if type == .keyUp { swallowUntil[keyCode] = nil }
            return nil
        }

        // F16–F18 / leftover F13–F15 / other explicit F-key actions.
        if let action = actionsByKeyCode[keyCode] {
            if type == .keyDown {
                nagaKeyboardTypes.insert(kbType)
                fireDebounced(action, label: "fkey=\(keyCode)")
            }
            return nil
        }

        // Factory digits — only when this keyboardType was seen from the Naga.
        if let action = digitActionsByKeyCode[keyCode], nagaKeyboardTypes.contains(kbType) {
            if type == .keyDown {
                fireDebounced(action, label: "digit=\(keyCode)")
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private nonisolated func fireDebounced(_ action: HotAction, label: String) {
        let now = DispatchTime.now().uptimeNanoseconds
        if now &- lastFireUptime < 40_000_000 { return }
        lastFireUptime = now
        logger.info("side-tap \(label, privacy: .public)")
        Task { @MainActor in
            self.fire(action)
        }
    }

    private func fire(_ action: HotAction) {
        switch action {
        case .macro(let macro):
            MacroExecutor.execute(macro)
        case .key(let value):
            MacroExecutor.injectKeystroke(value)
        }
    }

    static func buildSideActions(profile: FfiNagaProfile) -> [Int: HotAction] {
        var map: [Int: HotAction] = [:]
        for index in 0..<12 {
            guard let binding = profile.buttons.first(where: { $0.id == "side-\(index + 1)" }),
                  let action = action(for: binding, in: profile)
            else { continue }
            map[index] = action
        }
        return map
    }

    private static func buildMouseButtonActions(sideActions: [Int: HotAction]) -> [Int64: HotAction] {
        var map: [Int64: HotAction] = [:]
        for (index, button) in fpsMouseButtons.enumerated() {
            if let action = sideActions[index] {
                map[button] = action
            }
        }
        return map
    }

    private static func buildKeyCodeActions(
        profile: FfiNagaProfile,
        sideActions: [Int: HotAction]
    ) -> [Int64: HotAction] {
        var map: [Int64: HotAction] = [:]
        if profile.sidePlate == "seven" {
            for i in 0..<3 {
                if let action = sideActions[i] {
                    map[sevenSafeKeyCodes[i]] = action // keypad 1–3 from EEPROM
                    map[f13to15KeyCodes[i]] = action // leftover F13–F15
                }
            }
            return map
        }
        // Twelve / FPS backup: linear F13–F20 where available.
        let fKeys: [Int64?] = [
            0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A,
            nil, nil, nil, nil,
        ]
        for (index, action) in sideActions {
            guard index < fKeys.count, let fKey = fKeys[index] else { continue }
            map[fKey] = action
        }
        return map
    }

    private static func buildDigitActions(sideActions: [Int: HotAction]) -> [Int64: HotAction] {
        var map: [Int64: HotAction] = [:]
        for (index, action) in sideActions {
            guard index < digitKeyCodes.count else { continue }
            map[digitKeyCodes[index]] = action
        }
        return map
    }

    private static func action(
        for binding: FfiButtonBinding,
        in profile: FfiNagaProfile
    ) -> HotAction? {
        switch binding.action {
        case "macro":
            guard let macroId = binding.macroId,
                  let macro = profile.macros.first(where: { $0.id == macroId })
            else { return nil }
            return .macro(macro)
        case "key":
            let value = binding.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return .key(value)
        default:
            return nil
        }
    }

    static func buildActionsCount(profile: FfiNagaProfile) -> Int {
        buildSideActions(profile: profile).count
    }
}
