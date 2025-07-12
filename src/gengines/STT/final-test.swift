#!/usr/bin/swift

import Foundation
import CoreGraphics

print("🧪 FINAL TEST - Research Agent Fixes Applied")
print("==========================================")
print("")
print("Testing if STT Dictate can now receive events...")

// Test if our running STT app can detect events
let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        print("🎯 EVENT DETECTED: type=\(type.rawValue)")
        
        if type == .flagsChanged {
            let flags = event.flags
            print("   Flags: \(flags.rawValue)")
            
            // Check for remapped Fn key
            if flags.rawValue == 8388864 {
                print("   🔑 *** REMAPPED FN KEY! STT should respond! ***")
            } else if flags.contains(.maskSecondaryFn) {
                print("   🔑 *** ORIGINAL FN KEY! ***")
            }
        }
        
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            print("   Key: \(keyCode)")
        }
        
        return Unmanaged.passRetained(event)
    },
    userInfo: nil
)

if let eventTap = eventTap {
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
    print("✅ Test event tap active")
    print("🎯 Press Fn key now! (Will test for 15 seconds)")
    print("   Both this test AND STT Dictate should detect it")
    print("")
    
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 15))
    
    CGEvent.tapEnable(tap: eventTap, enable: false)
    print("🛑 Test complete")
    print("")
    print("Expected results:")
    print("✅ If you saw 'REMAPPED FN KEY' above - STT should work!")
    print("✅ Check menu bar for 🎤 icon")
    print("✅ Try pressing Fn in TextEdit - should toggle dictation")
} else {
    print("❌ Test event tap failed - permissions issue")
}