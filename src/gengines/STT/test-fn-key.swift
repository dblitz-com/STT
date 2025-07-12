#!/usr/bin/swift

import Foundation
import CoreGraphics
import Carbon.HIToolbox

print("🧪 Testing Fn key simulation...")

// Create a CGEvent source
guard let source = CGEventSource(stateID: .combinedSessionState) else {
    print("❌ Failed to create event source")
    exit(1)
}

// Method 1: Simulate Fn key as flagsChanged event
print("📤 Simulating Fn key press via flagsChanged...")
let fnFlagsEvent = CGEvent(source: source)
fnFlagsEvent?.type = .flagsChanged
fnFlagsEvent?.flags = .maskSecondaryFn
fnFlagsEvent?.post(tap: .cghidEventTap)

sleep(1)

// Method 2: Simulate Fn key as keyDown event (key code 63)
print("📤 Simulating Fn key press via keyDown...")
if let fnKeyEvent = CGEvent(keyboardEventSource: source, virtualKey: 63, keyDown: true) {
    fnKeyEvent.post(tap: .cghidEventTap)
}

sleep(1)

// Method 3: Try posting to different taps
print("📤 Simulating Fn key via session tap...")
if let fnKeyEvent2 = CGEvent(keyboardEventSource: source, virtualKey: 63, keyDown: true) {
    fnKeyEvent2.post(tap: .cgSessionEventTap)
}

print("✅ Fn key simulation complete - check if STT Dictate responded")