import Foundation
import NagaUSB

public enum OpenError: Error, Equatable {
    case notFound
    case usb(String)
}

public protocol Transport: AnyObject {
    func send(_ report: Report) throws
    /// Button-binding writes always use wIndex=0x00 (bypass cache).
    func sendButton(_ report: Report) throws
    func sleepMs(_ ms: UInt64)
}

public enum RecordedFrame: Equatable {
    case send(Report)
    case sendButton(Report)
    case sleep(UInt64)
}

public final class RecordingTransport: Transport {
    public private(set) var frames: [RecordedFrame] = []

    public init() {}

    public func send(_ report: Report) throws {
        var buf = report
        setCrc(&buf)
        frames.append(.send(buf))
    }

    public func sendButton(_ report: Report) throws {
        var buf = report
        setCrc(&buf)
        frames.append(.sendButton(buf))
    }

    public func sleepMs(_ ms: UInt64) {
        frames.append(.sleep(ms))
    }
}

/// Cached interface that accepted a general (non-button) SET_REPORT.
private let cachedInterfaceLock = NSLock()
// Guarded by `cachedInterfaceLock`.
private nonisolated(unsafe) var cachedInterface: UInt16?

public final class IOKitTransport: Transport {
    private var device: OpaquePointer?

    public static func open() throws -> IOKitTransport {
        var out: OpaquePointer?
        var err = [CChar](repeating: 0, count: 256)
        let code = naga_usb_open(razerVendorId, nagaTrinityProductId, &out, &err, err.count)
        switch code {
        case 0:
            let t = IOKitTransport()
            t.device = out
            return t
        case 1:
            throw OpenError.notFound
        default:
            throw OpenError.usb(cStringMessage(err))
        }
    }

    deinit {
        if let device {
            naga_usb_close(device)
        }
    }

    private func controlSetReport(_ report: Report, iface: UInt16) throws {
        guard let device else { throw OpenError.usb("device closed") }
        var err = [CChar](repeating: 0, count: 256)
        let code = report.withUnsafeBufferPointer { buf in
            naga_usb_set_report(device, iface, buf.baseAddress, buf.count, &err, err.count)
        }
        if code != 0 {
            throw OpenError.usb(cStringMessage(err))
        }
    }

    private static func cStringMessage(_ err: [CChar]) -> String {
        let end = err.firstIndex(of: 0) ?? err.endIndex
        return String(decoding: err[..<end].map(UInt8.init), as: UTF8.self)
    }

    private func cStringMessage(_ err: [CChar]) -> String {
        Self.cStringMessage(err)
    }

    private func sendWithIfaceProbe(_ report: inout Report) throws {
        setCrc(&report)

        cachedInterfaceLock.lock()
        let cached = cachedInterface
        cachedInterfaceLock.unlock()

        if let iface = cached {
            try controlSetReport(report, iface: iface)
            return
        }

        // Try 0x02 first — FW ACKs on 0x00 but ignores the command.
        do {
            try controlSetReport(report, iface: 0x02)
            cachedInterfaceLock.lock()
            cachedInterface = 0x02
            cachedInterfaceLock.unlock()
        } catch {
            do {
                try controlSetReport(report, iface: 0x00)
                cachedInterfaceLock.lock()
                cachedInterface = 0x00
                cachedInterfaceLock.unlock()
            } catch {
                throw error
            }
        }
    }

    public func send(_ report: Report) throws {
        var buf = report
        try sendWithIfaceProbe(&buf)
    }

    public func sendButton(_ report: Report) throws {
        var buf = report
        setCrc(&buf)
        try controlSetReport(buf, iface: 0x00)
    }

    public func sleepMs(_ ms: UInt64) {
        Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
    }
}

public func listDevices() -> FfiDeviceInfo {
    var info = NagaUsbDeviceInfo()
    naga_usb_list(razerVendorId, nagaTrinityProductId, &info)
    if info.connected == 0 {
        return FfiDeviceInfo(
            connected: false,
            productName: nil,
            manufacturer: nil,
            vendorId: nil,
            productId: nil,
            interfaces: 0
        )
    }
    return FfiDeviceInfo(
        connected: true,
        productName: "Razer Naga Trinity",
        manufacturer: "Razer",
        vendorId: info.vendor_id,
        productId: info.product_id,
        interfaces: info.interfaces
    )
}
