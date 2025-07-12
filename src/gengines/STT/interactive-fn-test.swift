#!/usr/bin/swift

import Foundation
import CoreGraphics

print("🧪 INTERACTIVE Fn Key Test")
print("========================")
print("")
print("This will monitor for 60 seconds.")
print("Press the Fn key multiple times and watch for output!")
print("")
print("If you see 'REMAPPED FN KEY DETECTED' then STT should work.")
print("Press Ctrl+C to stop early.")
print("")

let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        
        if type == .flagsChanged {
            let flags = event.flags
            print("📥 Flag event: \(flags.rawValue)")
            
            if flags.rawValue == 8388864 {
                print("🔑 *** REMAPPED FN KEY PRESS DETECTED! ***")
            } else if flags.contains(.maskSecondaryFn) {
                print("🔑 *** ORIGINAL FN KEY DETECTED! ***")
            }
        }
        
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            print("⌨️  Key press: \(keyCode)")
            
            if keyCode == 63 {
                print("🔑 *** FN KEYDOWN (63) DETECTED! ***")
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
    
    print("✅ Monitoring active - Press Fn key now!")
    
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 60))
    
    CGEvent.tapEnable(tap: eventTap, enable: false)
    print("🛑 Test complete")
} else {
    print("❌ Failed to create event tap")
}