#!/usr/bin/env swift

import AppKit
import SwiftUI
import Foundation

// Simple test to verify Glass UI displays text content
print("🧪 Starting Glass UI text display test...")

// Run the test
let app = NSApplication.shared
app.setActivationPolicy(.regular)

// Create a simple window to display test results
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
    styleMask: [.titled, .closable],
    backing: .buffered,
    defer: false
)
window.title = "Glass UI Test"
window.center()
window.makeKeyAndOrderFront(nil)

// Add some test content
let label = NSTextField(labelWithString: "Glass UI Test Running...\nCheck for Glass UI window on screen.")
label.frame = NSRect(x: 20, y: 20, width: 360, height: 160)
label.alignment = .center
window.contentView?.addSubview(label)

// Run the app
app.run()