#!/usr/bin/env swift

import AppKit
import SwiftUI

// Simple visual test to verify text display
class VisualTestWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 500, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        title = "🧪 Glass UI Visual Test"
        
        // Create test content
        let textField = NSTextField(wrappingLabelWithString: """
🎯 GLASS UI TEXT DISPLAY TEST

This window tests if text content displays properly.

✅ If you can read this, text rendering works!
✅ The Glass UI should display similar text content
✅ Look for a semi-transparent overlay window

Next: Click the Glass UI menu bar icon (👁️) and select "Show Glass UI"
Expected: You should see text like "🎯 BUTTON TEST: Glass UI is now visible!"

If you see a window but no text, the issue is with the SwiftUI view updates.
""")
        
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.alignment = .left
        textField.frame = NSRect(x: 20, y: 20, width: 460, height: 260)
        
        contentView?.addSubview(textField)
        
        center()
        orderFront(nil)
    }
}

// Run the test
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let testWindow = VisualTestWindow()

// Keep window open for 15 seconds then close
DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
    testWindow.close()
    app.terminate(nil)
}

app.run()