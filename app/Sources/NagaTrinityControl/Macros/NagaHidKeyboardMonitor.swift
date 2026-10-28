import Foundation
import IOKit.hid
import NagaCore
import os

/// Listens to the Naga Trinity keyboard HID interface (no exclusive seize).
/// Arms `DeviceKeyMonitor` to swallow the follow-up CGEvent and fires the action.
@MainActor
final class NagaHidKeyboardMonitor {
    struct StartResult: Equatable {
        var ok: Bool
        var seized: Bool
        var deviceCount: Int
        var message: String
    }

    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "NagaHidKeyboard")
    private var manager: IOHIDManager?

    private nonisolated(unsafe) var actionsByUsage: [UInt32: DeviceKeyMonitor.HotAction] = [:]
    private nonisolated(unsafe) var keyCodesByUsage: [UInt32: [Int64]] = [:]
    private nonisolated(unsafe) var lastFireUptime: UInt64 = 0
    private nonisolated(unsafe) var armed: Bool = false
    private nonisolated(unsafe) weak var eventTap: DeviceKeyMonitor?

    private static let defaultSideUsages: [UInt32] = [
        0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2d, 0x2e,
    ]
    private static let defaultSideKeyCodes: [Int64] = [
        18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24,
    ]
    /// Linear F13–F24 HID (legacy EEPROM) + macOS keycodes.
    private static let f13to24Usages: [UInt32] = [
        0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73,
    ]
    private static let f13to20KeyCodes: [Int64?] = [
        0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A,
        nil, nil, nil, nil,
    ]
    /// Seven-plate slots 1–3 are forced to keypad 1–3 (overwrite stuck F13–F15).
    private static let sevenSafeUsages: [UInt32] = [0x59, 0x5a, 0x5b] // Keypad 1–3
    private static let sevenSafeKeyCodes: [Int64] = [83, 84, 85]

    func stop() {
        armed = false
        eventTap = nil
        if let manager {
            IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            )
        }
        manager = nil
        actionsByUsage = [:]
        keyCodesByUsage = [:]
    }

    @discardableResult
    func start(
        profile: FfiNagaProfile,
        sideActions: [Int: DeviceKeyMonitor.HotAction],
        eventTap: DeviceKeyMonitor
    ) -> StartResult {
        stop()
        guard !sideActions.isEmpty else {
            return StartResult(ok: true, seized: false, deviceCount: 0, message: "no side actions")
        }
        if profile.sidePlate == "two" {
            return StartResult(ok: true, seized: false, deviceCount: 0, message: "fps uses mouse tap")
        }

        self.eventTap = eventTap
        let built = Self.buildMaps(profile: profile, sideActions: sideActions)
        actionsByUsage = built.actions
        keyCodesByUsage = built.keyCodes

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey: 0x1532,
            kIOHIDProductIDKey: 0x0067,
        ]
        IOHIDManagerSetDeviceMatching(mgr, match as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerRegisterInputValueCallback(mgr, { context, _, _, value in
            guard let context else { return }
            let monitor = Unmanaged<NagaHidKeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handleHidValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())

        let openResult = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        guard openResult == kIOReturnSuccess else {
            logger.error("IOHIDManagerOpen failed: \(openResult)")
            stop()
            return StartResult(ok: false, seized: false, deviceCount: 0, message: "hid open failed")
        }

        let count = (IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>)?.count ?? 0
        guard count > 0 else {
            stop()
            return StartResult(ok: false, seized: false, deviceCount: 0, message: "no naga hid devices")
        }

        armed = true
        logger.info("Naga HID listen deviceCount=\(count) usages=\(self.actionsByUsage.count)")
        return StartResult(
            ok: true,
            seized: true,
            deviceCount: count,
            message: "naga hid arm-to-swallow (\(count))"
        )
    }

    private static func buildMaps(
        profile: FfiNagaProfile,
        sideActions: [Int: DeviceKeyMonitor.HotAction]
    ) -> (actions: [UInt32: DeviceKeyMonitor.HotAction], keyCodes: [UInt32: [Int64]]) {
        var actions: [UInt32: DeviceKeyMonitor.HotAction] = [:]
        var keyCodes: [UInt32: [Int64]] = [:]

        for (index, action) in sideActions {
            guard index >= 0, index < 12 else { continue }

            func add(_ usage: UInt32, _ codes: [Int64]) {
                actions[usage] = action
                keyCodes[usage] = codes
            }

            // Factory digit for this side index.
            add(defaultSideUsages[index], [defaultSideKeyCodes[index]])

            if profile.sidePlate == "seven" {
                // Sides 1–3: keypad 1–3 (EEPROM) + leftover F13–F15 / main digits.
                if index < 3 {
                    add(sevenSafeUsages[index], [sevenSafeKeyCodes[index]])
                    let legacyF: [(UInt32, Int64)] = [
                        (0x68, 0x69), (0x69, 0x6B), (0x6a, 0x71),
                    ]
                    let (u, k) = legacyF[index]
                    add(u, [k, sevenSafeKeyCodes[index], defaultSideKeyCodes[index]])
                }
            } else {
                var fCodes: [Int64] = []
                if let kc = f13to20KeyCodes[index] { fCodes.append(kc) }
                add(
                    f13to24Usages[index],
                    fCodes.isEmpty ? [defaultSideKeyCodes[index]] : fCodes
                )
            }
        }
        return (actions, keyCodes)
    }

    private nonisolated func handleHidValue(_ value: IOHIDValue) {
        guard armed else { return }
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let pressed = IOHIDValueGetIntegerValue(value) != 0

        guard pressed else { return }
        // Info-level so Console.app shows what dead buttons 1–3 actually send.
        logger.info(
            "hid raw page=0x\(String(page, radix: 16), privacy: .public) usage=0x\(String(usage, radix: 16), privacy: .public)"
        )

        guard page == 0x07 else { return }
        guard let action = actionsByUsage[usage] else { return }

        if let codes = keyCodesByUsage[usage] {
            eventTap?.armSwallow(keyCodes: codes)
        }

        let now = DispatchTime.now().uptimeNanoseconds
        if now &- lastFireUptime < 40_000_000 { return }
        lastFireUptime = now

        logger.info("hid fire usage=0x\(String(usage, radix: 16), privacy: .public)")
        Task { @MainActor in
            switch action {
            case .macro(let macro):
                MacroExecutor.execute(macro)
            case .key(let value):
                MacroExecutor.injectKeystroke(value)
            }
        }
    }
}
