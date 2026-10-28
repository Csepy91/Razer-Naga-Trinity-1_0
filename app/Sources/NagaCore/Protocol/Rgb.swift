import Foundation

public func zoneLedId(_ zone: LedZone) -> UInt8 {
    switch zone {
    case .scroll: return 0x01
    case .logo: return 0x04
    case .side: return 0x00
    }
}

public func effectByte(_ effect: String) -> UInt8 {
    switch effect {
    case "off": return 0x00
    case "static": return 0x01
    case "breathing": return 0x02
    case "spectrum": return 0x03
    case "wave": return 0x04
    case "reactive": return 0x05
    default: return 0x01
    }
}

/// Brightness is global (LED 0x00), tx 0x3f. `brightness` is 0..=100.
public func encodeBrightness(_ brightness: UInt8) -> Report {
    var report = createReportDefault(commandClass: ledClass, commandId: 0x04, dataSize: 0x03)
    let scaled = UInt8((Double(brightness) / 100.0 * 255.0).rounded().clamped(to: 0...255))
    report[8] = 0x01
    report[9] = 0x00
    report[10] = scaled
    return finalize(report)
}

public func encodeTrinityStaticStep1() -> Report {
    var report = createReport(
        commandClass: ledClass,
        commandId: 0x02,
        dataSize: 0x06,
        transactionId: txTrinityEffect
    )
    report[8] = 0x00
    report[9] = 0x00
    report[10] = 0x08
    return finalize(report)
}

public func encodeTrinityStaticStep2(_ color: Rgb) -> Report {
    var report = createReport(
        commandClass: ledClass,
        commandId: 0x03,
        dataSize: 0x0e,
        transactionId: txTrinityEffect
    )
    report[8] = 0x00
    report[9] = 0x00
    report[10] = 0x00
    report[11] = 0x00
    report[12] = 0x02
    writeColor(&report, offset: 13, color: color)
    writeColor(&report, offset: 16, color: color)
    writeColor(&report, offset: 19, color: color)
    return finalize(report)
}

public func encodeEffectOff(_ zone: LedZone) -> Report {
    var report = createReportDefault(commandClass: ledClass, commandId: 0x02, dataSize: 0x03)
    report[8] = 0x01
    report[9] = zoneLedId(zone)
    report[10] = effectByte("off")
    return finalize(report)
}

public func encodeSpectrum(_ zone: LedZone) -> Report {
    var report = createReportDefault(commandClass: ledClass, commandId: 0x02, dataSize: 0x03)
    report[8] = 0x01
    report[9] = zoneLedId(zone)
    report[10] = effectByte("spectrum")
    return finalize(report)
}

public func encodeWave(_ zone: LedZone, direction: String) -> Report {
    var report = createReportDefault(commandClass: ledClass, commandId: 0x02, dataSize: 0x06)
    report[8] = 0x01
    report[9] = zoneLedId(zone)
    report[10] = effectByte("wave")
    report[11] = direction == "left" ? 0x02 : 0x01
    return finalize(report)
}

public func encodeReactive(_ zone: LedZone, speed: UInt8, color: Rgb) -> Report {
    var report = createReportDefault(commandClass: ledClass, commandId: 0x02, dataSize: 0x07)
    report[8] = 0x01
    report[9] = zoneLedId(zone)
    report[10] = effectByte("reactive")
    report[11] = UInt8(clampU16(UInt16(speed), min: 1, max: 4))
    writeColor(&report, offset: 12, color: color)
    return finalize(report)
}

public func encodeZoneEffect(zone: LedZone, rgb: FfiRgbSettings, zoneColor: Rgb) -> Report? {
    switch rgb.effect {
    case "off": return encodeEffectOff(zone)
    case "spectrum": return encodeSpectrum(zone)
    case "wave": return encodeWave(zone, direction: rgb.waveDirection)
    case "reactive": return encodeReactive(zone, speed: rgb.reactiveSpeed, color: zoneColor)
    case "static", "breathing": return nil
    default: return nil
    }
}

public func masterColor(_ rgb: FfiRgbSettings) -> Rgb {
    parseHexColor(rgb.color)
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
