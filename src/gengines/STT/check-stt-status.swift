#!/usr/bin/swift

import Foundation
import CoreGraphics

print("🔍 STT Dictate Status Check")
print("==========================")

// Send the remapped Fn event directly to test STT response
guard let source = CGEventSource(stateID: .combinedSessionState) else {
    print("❌ Failed to create event source")
    exit(1)
}

print("📤 Sending remapped Fn event to STT Dictate...")

// Send the specific remapped flag we detected earlier
if let flagsEvent = CGEvent(source: source) {
    flagsEvent.type = .flagsChanged
    flagsEvent.flags = CGEventFlags(rawValue: 8388864) // Remapped Fn
    flagsEvent.post(tap: .cghidEventTap)
    print("✅ Sent remapped Fn event (flag: 8388864)")
}

sleep(1)

// Also try original Fn flag
if let flagsEvent2 = CGEvent(source: source) {
    flagsEvent2.type = .flagsChanged
    flagsEvent2.flags = .maskSecondaryFn
    flagsEvent2.post(tap: .cghidEventTap)
    print("✅ Sent original Fn event")
}

print("")
print("🎯 Expected behavior:")
print("- STT Dictate should detect these events")
print("- Look for 🎤 icon in menu bar")
print("- Try pressing Fn in TextEdit to test actual usage")
print("")
print("If STT Dictate is working:")
print("✅ Fn key = Toggle dictation")
print("✅ No emoji picker appears")  
print("✅ Universal text insertion")