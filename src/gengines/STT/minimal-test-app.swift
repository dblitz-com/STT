#!/usr/bin/swift

import Cocoa

class MinimalApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched!")
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "⚡"
            print("Status item created")
        }
        
        // Create menu
        let menu = NSMenu()
        
        let testItem = NSMenuItem(title: "Test Click", action: #selector(testClicked), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        print("Menu assigned")
    }
    
    @objc func testClicked() {
        print("Test clicked!")
        
        // Show alert
        let alert = NSAlert()
        alert.messageText = "It works!"
        alert.informativeText = "Menu click detected successfully"
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = MinimalApp()
app.delegate = delegate
app.run()