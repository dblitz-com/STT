#!/usr/bin/swift
import Foundation
import ApplicationServices

// Check Accessibility permissions
let accessibilityTrusted = AXIsProcessTrusted()
print("✓ Accessibility permissions:", accessibilityTrusted ? "GRANTED" : "DENIED")

if !accessibilityTrusted {
    print("❌ STT Dictate needs Accessibility permissions to insert text")
    print("   Go to: System Settings > Privacy & Security > Accessibility")
    print("   Add and enable: STT Dictate")
}

// Note: Input Monitoring can't be checked programmatically
print("⚠️  Input Monitoring permissions must be checked manually")
print("   Go to: System Settings > Privacy & Security > Input Monitoring") 
print("   Ensure: STT Dictate is listed and enabled")