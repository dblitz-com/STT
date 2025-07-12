#!/usr/bin/swift

import Foundation
import CoreGraphics
import ApplicationServices

print("🔍 Quick CGEventTap Test...")

// Check accessibility permissions
let accessEnabled = AXIsProcessTrusted()
print("🔐 Accessibility: \(accessEnabled ? "GRANTED" : "DENIED")")

if !accessEnabled {
    print("❌ No accessibility permissions - this will fail")
    exit(1)
}

// Try creating a simple event tap
let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,  // Just listen, don't consume
    eventsOfInterest: CGEventMask(eventMask),
    callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        print("🎯 EVENT: type=\(type.rawValue)")
        if type == .flagsChanged {
            let flags = event.flags
            print("   Flags: \(flags.rawValue)")
            if flags.contains(.maskSecondaryFn) {
                print("   🔑 FN KEY DETECTED!")
            }
        }
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            print("   Key: \(keyCode)")
            if keyCode == 63 {
                print("   🔑 FN KEY (63) DETECTED!")
            }
        }
        return Unmanaged.passRetained(event)
    },
    userInfo: nil
)

if let eventTap = eventTap {
    print("✅ Event tap created successfully")
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
    let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)
    print("✅ Event tap enabled: \(isEnabled)")
    
    print("🎯 Listening for 10 seconds... Press any keys including Fn")
    
    // Run for 10 seconds
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 10))
    
    CGEvent.tapEnable(tap: eventTap, enable: false)
    print("🛑 Test complete")
} else {
    print("❌ Failed to create event tap")
    print("This means the system is blocking low-level event access")
}