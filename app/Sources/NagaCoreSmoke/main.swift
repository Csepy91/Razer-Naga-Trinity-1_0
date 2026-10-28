import Foundation
import NagaCore

@main
struct NagaCoreSmoke {
    static func main() {
        var failures = 0
        func check(_ name: String, _ ok: () -> Bool) {
            if ok() {
                print("ok  — \(name)")
            } else {
                print("FAIL — \(name)")
                failures += 1
            }
        }

        do {
            let r = createReport(commandClass: 0x0f, commandId: 0x04, dataSize: 0x03, transactionId: 0x3f)
            check("create report layout") {
                r[0] == 0 && r[1] == 0x3f && r[5] == 0x03 && r[6] == 0x0f && r[7] == 0x04 && r.count == 90
            }
        }

        do {
            let r = encodeBrightness(80)
            check("brightness 80%") {
                r[1] == 0x3f && Array(r[8..<11]) == [0x01, 0x00, 0xcc] && r[88] != 0
            }
        }

        check("polling rates") {
            encodePolling(.hz125)[8] == 0x08
                && encodePolling(.hz500)[8] == 0x02
                && encodePolling(.hz1000)[8] == 0x01
        }

        do {
            let r = encodeDpiActive(x: 1800, y: 1800)
            check("dpi active 1800") {
                Array(r[8..<15]) == [0x01, 0x07, 0x08, 0x07, 0x08, 0x00, 0x00]
            }
        }

        do {
            let r = encodeSideButtonBinding(slot: 0x02, buttonIndex: 1, stroke: .plain(0x68))
            check("side button binding") {
                Array(r[8..<15]) == [0x02, 0x40, 0x00, 0x02, 0x02, 0x00, 0x68]
            }
        }

        check("parse Ctrl+C") {
            parseKeyBinding("Ctrl+C") == SideKeyStroke(modifiers: 0x01, hid: 0x06)
        }

        do {
            var profile = createInitialStore().profiles[0]
            profile.sidePlate = "two"
            profile.buttons = profile.buttons.filter { !$0.id.hasPrefix("side-") }
            for (i, value) in ["A", "B"].enumerated() {
                profile.buttons.append(
                    FfiButtonBinding(
                        id: "side-\(i + 1)",
                        label: "Side \(i + 1)",
                        hardwareIndex: UInt8(i + 1),
                        action: "key",
                        value: value,
                        macroId: nil
                    )
                )
            }
            let codes = buildSideBindings(profile)
            check("fps plate slots 12/9") {
                codes[11] == .plain(0x68) && codes[8] == .plain(0x69)
            }
        }

        do {
            let profile = createInitialStore().profiles[0]
            let t = RecordingTransport()
            try applyProfileOn(transport: t, profile: profile)
            let dpiActiveIdx = t.frames.firstIndex {
                if case .send(let r) = $0 { return r[6] == 0x04 && r[7] == 0x05 }
                return false
            }
            check("settle after dpi before polling") {
                guard let dpiActiveIdx else { return false }
                guard t.frames[dpiActiveIdx + 1] == .sleep(20) else { return false }
                guard case .send(let poll) = t.frames[dpiActiveIdx + 2] else { return false }
                return poll[6] == 0x00 && poll[7] == 0x05
            }

            let buttonFrames = t.frames.filter {
                if case .sendButton = $0 { return true }
                return false
            }.count
            check("twelve plate button frame count") { buttonFrames == 28 }
        } catch {
            print("FAIL — apply sequence: \(error)")
            failures += 1
        }

        do {
            let store = createInitialStore()
            check("initial raid profile") {
                store.version == 2
                    && store.profiles.count == 1
                    && store.profiles[0].name == "Raid / Produktiv"
                    && store.profiles[0].macros[0].name == "Potion + Confirm"
                    && store.profiles[0].buttons.count == 21
            }
        }

        do {
            let raw: [[String: Any]] = [[
                "id": "abc",
                "name": "Old",
                "sidePlate": "seven",
                "pollingRate": 500,
            ]]
            let store = migrate(raw)
            check("migrate legacy array") {
                store.profiles[0].id == "abc"
                    && store.profiles[0].sidePlate == "seven"
                    && store.profiles[0].pollingRate == 500
                    && store.profiles[0].buttons.count == 16
            }
        }

        if failures == 0 {
            print("All smoke checks passed.")
            exit(0)
        } else {
            print("\(failures) smoke check(s) failed.")
            exit(1)
        }
    }
}
