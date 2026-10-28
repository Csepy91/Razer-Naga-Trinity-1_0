import Foundation

private func applyRgb(transport: Transport, rgb: FfiRgbSettings) throws {
    let master = masterColor(rgb)
    try transport.send(encodeBrightness(rgb.brightness))
    transport.sleepMs(20)

    if rgb.effect == "static" || rgb.effect == "breathing" {
        try transport.send(encodeTrinityStaticStep1())
        transport.sleepMs(30)
        try transport.send(encodeTrinityStaticStep2(master))
        return
    }

    let side = rgb.zones.side
    if side.enabled {
        let color = rgb.syncZones ? master : parseHexColor(side.color)
        if let report = encodeZoneEffect(zone: .side, rgb: rgb, zoneColor: color) {
            try transport.send(report)
        }
        return
    }

    for zone in [LedZone.logo, .scroll] {
        let config = zone == .logo ? rgb.zones.logo : rgb.zones.scroll
        if !config.enabled {
            var off = rgb
            off.effect = "off"
            if let report = encodeZoneEffect(zone: zone, rgb: off, zoneColor: master) {
                try transport.send(report)
            }
            transport.sleepMs(20)
            continue
        }
        let color = rgb.syncZones ? master : parseHexColor(config.color)
        if let report = encodeZoneEffect(zone: zone, rgb: rgb, zoneColor: color) {
            try transport.send(report)
        }
        transport.sleepMs(20)
    }
}

private func applyDpi(transport: Transport, dpi: FfiDpiSettings) throws {
    try transport.send(encodeDpiStages(dpi))
    transport.sleepMs(20)

    let stages = dpi.stages
    guard !stages.isEmpty else { return }
    let idx = Swift.min(Swift.max(Int(dpi.activeStage), 1), stages.count) - 1
    let active = stages[idx]
    try transport.send(encodeDpiActive(x: active.x, y: active.y))
    // FW silently ignores the next POWER_CLASS command (polling) if it arrives
    // immediately after dpi-active. Verified on hardware: ≥20 ms settle required.
    transport.sleepMs(20)
}

private func applySideBindings(transport: Transport, strokes: [SideKeyStroke]) throws {
    for slot: UInt8 in [0x02, 0x01] {
        for (i, stroke) in strokes.prefix(12).enumerated() {
            let report = encodeSideButtonBinding(slot: slot, buttonIndex: UInt8(i + 1), stroke: stroke)
            try transport.sendButton(report)
            transport.sleepMs(40)
        }
    }
    for _ in 0..<2 {
        for slot: UInt8 in [0x02, 0x01] {
            for (i, stroke) in strokes.prefix(12).enumerated() {
                if stroke.hid == razerDefaultSideHid[i], stroke.modifiers == 0 {
                    continue
                }
                let report = encodeSideButtonBinding(slot: slot, buttonIndex: UInt8(i + 1), stroke: stroke)
                try transport.sendButton(report)
                transport.sleepMs(50)
            }
        }
    }
}

private func applyWheelTilt(transport: Transport) throws {
    for slot: UInt8 in [0x02, 0x01] {
        try transport.sendButton(encodeWheelTiltBinding(slot: slot, source: 0x34, action: 0x04))
        transport.sleepMs(20)
        try transport.sendButton(encodeWheelTiltBinding(slot: slot, source: 0x35, action: 0x05))
        transport.sleepMs(20)
    }
}

private func withDevice(_ body: (Transport) throws -> FfiApplyResult) -> FfiApplyResult {
    let transport: IOKitTransport
    do {
        transport = try IOKitTransport.open()
    } catch OpenError.notFound {
        return .notFound()
    } catch OpenError.usb(let detail) {
        return .usbError(detail)
    } catch {
        return .usbError(error.localizedDescription)
    }
    do {
        return try body(transport)
    } catch OpenError.usb(let detail) {
        return .usbError(detail)
    } catch {
        return .usbError(String(describing: error))
    }
}

/// Full apply: RGB → DPI stages → DPI active → polling → side bindings → wheel tilt.
public func runApplyProfile(_ profile: FfiNagaProfile) -> FfiApplyResult {
    withDevice { transport in
        try applyRgb(transport: transport, rgb: profile.rgb)
        try applyDpi(transport: transport, dpi: profile.dpi)
        try transport.send(encodePolling(hz: profile.pollingRate))
        let sideCodes = buildSideBindings(profile)
        try applySideBindings(transport: transport, strokes: sideCodes)
        try applyWheelTilt(transport: transport)

        let macroCount = profile.buttons.filter { b in
            guard b.id.hasPrefix("side-") else { return false }
            switch b.action {
            case "macro": return b.macroId != nil
            case "key": return !b.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default: return false
            }
        }.count

        if macroCount > 0 {
            return FfiApplyResult(
                ok: true,
                message: "RGB, DPI, Polling-Rate und Button-Bindings auf Maus geschrieben. \(macroCount) Side-Buttons auf F13–F24 für Makros gemappt.",
                key: "driverNotices.applyCompleteWithMacros",
                params: ["macroCount": String(macroCount)],
                stage: "complete"
            )
        }
        return FfiApplyResult(
            ok: true,
            message: "RGB, DPI, Polling-Rate und Button-Bindings auf Maus geschrieben.",
            key: "driverNotices.applyComplete",
            params: [:],
            stage: "complete"
        )
    }
}

public func runPreviewRgb(_ rgb: FfiRgbSettings) -> FfiApplyResult {
    withDevice { transport in
        try applyRgb(transport: transport, rgb: rgb)
        return FfiApplyResult(
            ok: true,
            message: "RGB aktualisiert.",
            key: "driverNotices.rgbUpdated",
            params: [:],
            stage: "rgb"
        )
    }
}

public func runSetRgbOff() -> FfiApplyResult {
    withDevice { transport in
        try transport.send(encodeBrightness(0))
        return .okWith(key: "driverNotices.rgbOff", message: "RGB ausgeschaltet.")
    }
}

public func applyRgbOn(transport: Transport, rgb: FfiRgbSettings) throws {
    try applyRgb(transport: transport, rgb: rgb)
}

public func applyProfileOn(transport: Transport, profile: FfiNagaProfile) throws {
    try applyRgb(transport: transport, rgb: profile.rgb)
    try applyDpi(transport: transport, dpi: profile.dpi)
    try transport.send(encodePolling(hz: profile.pollingRate))
    try applySideBindings(transport: transport, strokes: buildSideBindings(profile))
    try applyWheelTilt(transport: transport)
}
