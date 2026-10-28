import Foundation

public func pollingByte(_ rate: PollingRate) -> UInt8 {
    switch rate {
    case .hz125: return 0x08
    case .hz500: return 0x02
    case .hz1000: return 0x01
    }
}

public func encodePolling(_ rate: PollingRate) -> Report {
    var report = createReportDefault(commandClass: powerClass, commandId: 0x05, dataSize: 0x01)
    report[8] = pollingByte(rate)
    return finalize(report)
}

public func encodePolling(hz: UInt16) -> Report {
    encodePolling(PollingRate(hz: hz))
}
