#!/usr/bin/swift
import Foundation
import ApplicationServices

print("🔐 Forcing accessibility permission prompt...")

// Force the permission prompt
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

print("📊 Accessibility status after prompt:", trusted ? "✅ GRANTED" : "❌ DENIED")

if !trusted {
    print("")
    print("⚠️  MANUAL ACTION REQUIRED:")
    print("   1. System Settings should have opened")
    print("   2. Go to Privacy & Security > Accessibility")
    print("   3. Find 'STT Dictate' and enable it")
    print("   4. Also check Privacy & Security > Input Monitoring")
    print("   5. Restart the app after granting permissions")
}