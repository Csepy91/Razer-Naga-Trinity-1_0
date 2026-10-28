import Foundation

public let razerReportLen = 90
public typealias Report = [UInt8]

public let txDefault: UInt8 = 0x3f
public let txTrinityEffect: UInt8 = 0x1f
public let ledClass: UInt8 = 0x0f
public let dpiClass: UInt8 = 0x04
public let powerClass: UInt8 = 0x00
public let buttonClass: UInt8 = 0x02

public struct Rgb: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public func createReport(
    commandClass: UInt8,
    commandId: UInt8,
    dataSize: UInt8,
    transactionId: UInt8
) -> Report {
    var report = [UInt8](repeating: 0, count: razerReportLen)
    report[0] = 0x00
    report[1] = transactionId
    report[5] = dataSize
    report[6] = commandClass
    report[7] = commandId
    return report
}

public func createReportDefault(commandClass: UInt8, commandId: UInt8, dataSize: UInt8) -> Report {
    createReport(
        commandClass: commandClass,
        commandId: commandId,
        dataSize: dataSize,
        transactionId: txDefault
    )
}

public func setCrc(_ report: inout Report) {
    var crc: UInt8 = 0
    for byte in report[2..<88] {
        crc ^= byte
    }
    report[88] = crc
}

public func finalize(_ report: Report) -> Report {
    var copy = report
    setCrc(&copy)
    return copy
}

/// Invalid hex → `#00ff66` (upstream fallback).
public func parseHexColor(_ color: String) -> Rgb {
    var normalized = color.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.hasPrefix("#") {
        normalized.removeFirst()
    }
    let safe: String
    if normalized.count == 6, normalized.allSatisfy({ $0.isHexDigit }) {
        safe = normalized
    } else {
        safe = "00ff66"
    }
    let r = UInt8(safe.prefix(2), radix: 16) ?? 0
    let g = UInt8(safe.dropFirst(2).prefix(2), radix: 16) ?? 0
    let b = UInt8(safe.dropFirst(4).prefix(2), radix: 16) ?? 0
    return Rgb(r: r, g: g, b: b)
}

public func writeColor(_ report: inout Report, offset: Int, color: Rgb) {
    report[offset] = color.r
    report[offset + 1] = color.g
    report[offset + 2] = color.b
}

public func clampU16(_ value: UInt16, min: UInt16, max: UInt16) -> UInt16 {
    Swift.min(Swift.max(value, min), max)
}
