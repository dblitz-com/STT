#!/usr/bin/swift

import Cocoa
import AppKit

class TestMenuBarDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("=== MENU BAR TEST STARTING ===")
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("Status item created: \(statusItem != nil)")
        
        if let button = statusItem?.button {
            button.title = "TEST"
            NSLog("Button title set to TEST")
        } else {
            NSLog("FAILED to get button!")
        }
        
        NSLog("=== MENU BAR TEST COMPLETE ===")
        NSLog("Look for 'TEST' in menu bar")
    }
}

let app = NSApplication.shared
let delegate = TestMenuBarDelegate()
app.delegate = delegate
app.run()