#!/usr/bin/swift

import Foundation
import CoreGraphics
import Carbon.HIToolbox

print("🧪 Testing Wispr Flow approach - Fn key simulation...")

// Simulate various Fn key events to test our app
guard let source = CGEventSource(stateID: .combinedSessionState) else {
    print("❌ Failed to create event source")
    exit(1)
}

print("📤 Simulating Fn key events...")

// Method 1: flagsChanged with maskSecondaryFn
print("1️⃣ Testing flagsChanged with maskSecondaryFn...")
if let flagsEvent = CGEvent(source: source) {
    flagsEvent.type = .flagsChanged
    flagsEvent.flags = .maskSecondaryFn
    flagsEvent.post(tap: .cghidEventTap)
    print("   Posted flagsChanged event")
}

sleep(1)

// Method 2: keyDown with Fn key code 63
print("2️⃣ Testing keyDown with key code 63...")
if let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: 63, keyDown: true) {
    keyEvent.post(tap: .cghidEventTap)
    print("   Posted keyDown event (code 63)")
}

sleep(1)

// Method 3: Try posting to different taps
print("3️⃣ Testing different event taps...")
if let keyEvent2 = CGEvent(keyboardEventSource: source, virtualKey: 63, keyDown: true) {
    keyEvent2.post(tap: .cgSessionEventTap)
    print("   Posted to cgSessionEventTap")
}

print("✅ Test complete - check STT Dictate output for event detection")
print("If no events detected, the issue is at the CGEventTap level")