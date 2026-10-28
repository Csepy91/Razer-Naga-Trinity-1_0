import Foundation
import NagaCore

@main
struct NagaCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(2)
        }

        switch command {
        case "info":
            let info = scanDevice()
            printJSON(info)
            exit(info.connected ? 0 : 1)
        case "apply":
            let profileId = flagValue("--profile", in: args)
            let storeDir = flagValue("--store-dir", in: args)
            if let storeDir {
                setStoreDir(path: storeDir)
            }
            let store = readStore()
            let profile: FfiNagaProfile?
            if let profileId {
                profile = store.profiles.first { $0.id == profileId }
            } else {
                profile = store.profiles.first { $0.id == store.activeProfileId }
            }
            guard let profile else {
                fputs("profile not found\n", stderr)
                exit(1)
            }
            let result = applyProfile(profile: profile)
            printJSON(result)
            exit(result.ok ? 0 : 1)
        case "rgb":
            guard args.count >= 2 else {
                printUsage()
                exit(2)
            }
            let effect = args[1]
            let color = args.count >= 3 ? args[2] : "#00ff66"
            var rgb = createInitialStore().profiles[0].rgb
            rgb.effect = ["breathing", "spectrum", "wave", "reactive", "off", "static"].contains(effect)
                ? effect : "static"
            rgb.color = color
            let result = previewRgb(rgb: rgb)
            printJSON(result)
            exit(result.ok ? 0 : 1)
        case "dpi":
            guard args.count >= 2, let x = UInt16(args[1]) else {
                printUsage()
                exit(2)
            }
            var profile = createInitialStore().profiles[0]
            let idx = max(Int(profile.dpi.activeStage) - 1, 0)
            if profile.dpi.stages.indices.contains(idx) {
                profile.dpi.stages[idx].x = x
                profile.dpi.stages[idx].y = x
            }
            let result = applyProfile(profile: profile)
            printJSON(result)
            exit(result.ok ? 0 : 1)
        case "poll":
            guard args.count >= 2, let hz = UInt16(args[1]) else {
                printUsage()
                exit(2)
            }
            var profile = createInitialStore().profiles[0]
            profile.pollingRate = PollingRate(hz: hz).rawValue
            let result = applyProfile(profile: profile)
            printJSON(result)
            exit(result.ok ? 0 : 1)
        case "off":
            let result = setRgbOff()
            printJSON(result)
            exit(result.ok ? 0 : 1)
        case "help", "-h", "--help":
            printUsage()
            exit(0)
        default:
            fputs("unknown command: \(command)\n", stderr)
            printUsage()
            exit(2)
        }
    }

    private static func printUsage() {
        let text = """
        naga-cli — Razer Naga Trinity hardware smoke-test CLI

        Usage:
          naga-cli info
          naga-cli apply [--profile ID] [--store-dir PATH]
          naga-cli rgb <effect> [#hex]
          naga-cli dpi <x>
          naga-cli poll <hz>
          naga-cli off
        """
        print(text)
    }

    private static func flagValue(_ name: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: name), args.indices.contains(idx + 1) else {
            return nil
        }
        return args[idx + 1]
    }

    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func printJSON(_ value: FfiApplyResult) {
        let dict: [String: Any] = [
            "ok": value.ok,
            "message": value.message,
            "key": value.key as Any,
            "params": value.params,
            "stage": value.stage as Any,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func printJSON(_ value: FfiDeviceInfo) {
        var dict: [String: Any] = [
            "connected": value.connected,
            "interfaces": value.interfaces,
        ]
        if let productName = value.productName { dict["productName"] = productName }
        if let manufacturer = value.manufacturer { dict["manufacturer"] = manufacturer }
        if let vendorId = value.vendorId { dict["vendorId"] = vendorId }
        if let productId = value.productId { dict["productId"] = productId }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
