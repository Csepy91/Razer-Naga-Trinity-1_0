import Foundation

private let dpiMin: UInt16 = 100
private let dpiMax: UInt16 = 16000

/// DPI stages command (cls 0x04 cmd 0x06). Size = 2 + n×7 (kept as upstream).
public func encodeDpiStages(_ dpi: FfiDpiSettings) -> Report {
    let stages = Array(dpi.stages.prefix(5))
    let n = UInt8(stages.count)
    let dataSize = 2 + n * 7
    var report = createReportDefault(commandClass: dpiClass, commandId: 0x06, dataSize: dataSize)
    let active = UInt8(Swift.min(Swift.max(Int(dpi.activeStage), 1), max(stages.count, 1)))
    report[8] = 0x00
    report[9] = active
    report[10] = n

    for (index, stage) in stages.enumerated() {
        let base = 11 + index * 7
        let x = clampU16(stage.x, min: dpiMin, max: dpiMax)
        let y = clampU16(stage.y, min: dpiMin, max: dpiMax)
        report[base] = UInt8(index + 1)
        report[base + 1] = UInt8(x >> 8)
        report[base + 2] = UInt8(x & 0xff)
        report[base + 3] = UInt8(y >> 8)
        report[base + 4] = UInt8(y & 0xff)
        report[base + 5] = 0x00
        report[base + 6] = 0x00
    }
    return finalize(report)
}

/// DPI active stage (cls 0x04 cmd 0x05).
public func encodeDpiActive(x: UInt16, y: UInt16) -> Report {
    let cx = clampU16(x, min: dpiMin, max: dpiMax)
    let cy = clampU16(y, min: dpiMin, max: dpiMax)
    var report = createReportDefault(commandClass: dpiClass, commandId: 0x05, dataSize: 0x07)
    report[8] = 0x01
    report[9] = UInt8(cx >> 8)
    report[10] = UInt8(cx & 0xff)
    report[11] = UInt8(cy >> 8)
    report[12] = UInt8(cy & 0xff)
    report[13] = 0x00
    report[14] = 0x00
    return finalize(report)
}
