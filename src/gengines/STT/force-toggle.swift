#!/usr/bin/swift

import Foundation
import CoreGraphics

print("🔧 Forcing STT toggle via simulated event...")

guard let source = CGEventSource(stateID: .combinedSessionState) else {
    print("❌ Failed to create event source")
    exit(1)
}

// Send the exact flag value we detected from remapped Fn key
if let flagsEvent = CGEvent(source: source) {
    flagsEvent.type = .flagsChanged
    flagsEvent.flags = CGEventFlags(rawValue: 8388864) // Remapped Fn flag
    flagsEvent.post(tap: .cghidEventTap)
    print("✅ Sent remapped Fn event to STT Dictate")
    print("Check Console.app for STT response")
}

print("Done!")