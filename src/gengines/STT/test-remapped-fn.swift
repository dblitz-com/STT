#!/usr/bin/swift

import Foundation
import CoreGraphics

print("🧪 Testing remapped Fn key with STT Dictate...")

// Simulate the remapped Fn key event
guard let source = CGEventSource(stateID: .combinedSessionState) else {
    print("❌ Failed to create event source")
    exit(1)
}

print("📤 Simulating remapped Fn key press...")

// Create flagsChanged event with the detected flag value
if let flagsEvent = CGEvent(source: source) {
    flagsEvent.type = .flagsChanged
    flagsEvent.flags = CGEventFlags(rawValue: 8388864) // The flag we detected
    flagsEvent.post(tap: .cghidEventTap)
    print("   Posted remapped flagsChanged event")
}

print("✅ Test sent - STT Dictate should respond if running")