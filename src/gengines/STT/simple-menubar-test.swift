#!/usr/bin/swift

import Cocoa

class MenuBarApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched!")
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "TEST"
            button.action = #selector(menuClicked)
            button.target = self
            print("Menu bar item created!")
        }
    }
    
    @objc func menuClicked() {
        print("Menu clicked!")
        if let button = statusItem?.button {
            button.title = button.title == "TEST" ? "CLICKED" : "TEST"
        }
    }
}

let app = NSApplication.shared
let delegate = MenuBarApp()
app.delegate = delegate
app.run()