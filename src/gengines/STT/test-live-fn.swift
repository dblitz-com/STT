#!/usr/bin/swift

import Foundation
import CoreGraphics

print("🧪 Testing LIVE Fn key detection...")
print("Press the Fn key now and watch for output...")

// Create event tap to monitor what happens when you press Fn
let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        
        if type == .flagsChanged {
            let flags = event.flags
            // Check for the remapped Fn flag we detected earlier
            if flags.rawValue == 8388864 {
                print("🔑 REMAPPED FN KEY DETECTED! STT should toggle now")
            } else if flags.contains(.maskSecondaryFn) {
                print("🔑 ORIGINAL FN KEY DETECTED!")
            } else if flags.rawValue != 256 { // Ignore key release
                print("📥 Other flag: \(flags.rawValue)")
            }
        }
        
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 63 {
                print("🔑 FN KEYDOWN DETECTED!")
            }
        }
        
        return Unmanaged.passRetained(event)
    },
    userInfo: nil
)

if let eventTap = eventTap {
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
    print("✅ Monitoring started - Press Fn key to test!")
    print("⏱️  Will monitor for 15 seconds...")
    
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 15))
    
    CGEvent.tapEnable(tap: eventTap, enable: false)
    print("🛑 Monitoring stopped")
} else {
    print("❌ Failed to create monitor")
}