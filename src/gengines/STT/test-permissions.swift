#!/usr/bin/swift
import Foundation
import ApplicationServices

// Check current permissions
let trusted = AXIsProcessTrusted()

print("🔐 Accessibility permissions:", trusted ? "✅ GRANTED" : "❌ DENIED")

if trusted {
    print("✅ App can insert text using AXUIElement API")
} else {
    print("❌ Please grant Accessibility permissions and restart the app")
}