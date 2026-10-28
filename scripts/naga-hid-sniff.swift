import Foundation
import IOKit.hid

/// Prints every Naga Trinity HID input value for ~20s (press side buttons 1–3).
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let match: [String: Any] = [
    kIOHIDVendorIDKey: 0x1532,
    kIOHIDProductIDKey: 0x0067,
]
IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
IOHIDManagerRegisterInputValueCallback(manager, { _, _, sender, value in
    let element = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let ival = IOHIDValueGetIntegerValue(value)
    guard ival != 0 else { return }
    var product = "device"
    if let dev = sender {
        if let name = IOHIDDeviceGetProperty(dev as! IOHIDDevice, kIOHIDProductKey as CFString) as? String {
            product = name
        }
    }
    print(String(format: "page=0x%02x usage=0x%02x (%3d) ival=%d  [%@]", page, usage, usage, ival, product))
    fflush(stdout)
}, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
let r = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard r == kIOReturnSuccess else {
    fputs("IOHIDManagerOpen failed: \(r)\n", stderr)
    exit(1)
}
let n = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.count ?? 0
print("Listening on \(n) Naga HID device(s) for 40s — press side buttons 1,2,3 then 4…")
fflush(stdout)
DispatchQueue.main.asyncAfter(deadline: .now() + 40) {
    print("Done.")
    CFRunLoopStop(CFRunLoopGetMain())
}
CFRunLoopRun()
