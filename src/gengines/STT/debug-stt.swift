#!/usr/bin/swift

import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

print("🐛 DEBUG STT - Starting...")

// Check permissions
let accessEnabled = AXIsProcessTrusted()
print("🔐 Accessibility: \(accessEnabled)")

// Create simple event tap
let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)

print("⚙️ Creating event tap...")

let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        print("🎯 EVENT DETECTED: type=\(type.rawValue)")
        
        if type == .flagsChanged {
            let flags = event.flags
            print("   Flags: \(flags.rawValue)")
            
            // Check for our remapped Fn key
            if flags.rawValue == 8388864 {
                print("   🔑 REMAPPED FN KEY DETECTED!")
                print("   🎤 TOGGLING DICTATION!")
                return nil // Consume event
            }
            
            if flags.contains(.maskSecondaryFn) {
                print("   🔑 ORIGINAL FN KEY DETECTED!")
                return nil
            }
        }
        
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            print("   Key: \(keyCode)")
            if keyCode == 63 {
                print("   🔑 FN KEYDOWN DETECTED!")
                return nil
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
    
    let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)
    print("✅ Event tap enabled: \(isEnabled)")
    print("🎯 Listening for Fn key... Press it now!")
    print("⏱️ Will run for 30 seconds...")
    
    // Add a simple menu bar icon
    let app = NSApplication.shared
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
        button.title = "🎤"
        button.toolTip = "Debug STT"
    }
    
    // Run for 30 seconds
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 30))
    
    print("🛑 Test complete")
} else {
    print("❌ Failed to create event tap")
    print("❌ Check Input Monitoring permissions!")
}