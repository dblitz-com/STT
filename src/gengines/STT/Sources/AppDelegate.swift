import Cocoa
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dictationService: VoiceDictationService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 === STT DICTATE APP DID FINISH LAUNCHING ===")
        print("🚀 === STT DICTATE APP DID FINISH LAUNCHING ===")
        
        // CRITICAL FIX: Force app activation for event reception (research agent solution)
        NSApp.activate(ignoringOtherApps: true)
        NSLog("✅ App activated")
        
        // Create status bar item with fixed length and simple text
        NSLog("🔨 Creating status bar item...")
        statusItem = NSStatusBar.system.statusItem(withLength: 50) // Fixed length instead of variable
        NSLog("📍 Status item created: \(statusItem != nil ? "SUCCESS" : "FAILED")")
        
        if let statusItem = statusItem, let button = statusItem.button {
            NSLog("🔨 Setting button properties...")
            
            // Use system symbol instead of text (more reliable rendering)
            if let micImage = NSImage(systemSymbolName: "mic", accessibilityDescription: "STT") {
                button.image = micImage
                NSLog("✅ Button configured with microphone image")
            } else {
                button.title = "STT"
                NSLog("✅ Button configured with STT text (fallback)")
            }
            
            button.toolTip = "STT Dictate - Press Fn to toggle"
            
            // Force refresh
            button.needsDisplay = true
            NSLog("🔄 Button display refreshed")
            
            // Debug: Check visibility
            NSLog("📊 StatusItem visible: \(statusItem.isVisible)")
            NSLog("📊 StatusItem length: \(statusItem.length)")
        } else {
            NSLog("❌ FAILED to get status item or button!")
        }
        
        // Create menu
        NSLog("🔨 Creating menu...")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "STT Dictate v1.0", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        NSLog("🔨 Assigning menu to status item...")
        statusItem?.menu = menu
        NSLog("✅ Menu assigned")
        
        // CRITICAL FIX: Create hidden window for LSUIElement=true apps (forces GUI context)
        NSLog("🔨 Creating hidden window for background app...")
        let hiddenWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        hiddenWindow.makeKeyAndOrderFront(nil)
        hiddenWindow.isReleasedWhenClosed = false
        hiddenWindow.orderOut(nil) // Hide it immediately
        NSLog("✅ Hidden window created")
        
        // CRITICAL FIX: Initialize service AFTER app launch (research agent solution)
        NSLog("🔨 Creating VoiceDictationService...")
        dictationService = VoiceDictationService()
        
        // CRITICAL FIX: Setup hotkey AFTER run loop is active
        NSLog("🔨 Initializing dictation service...")
        dictationService?.initializeAfterLaunch()
        
        NSLog("✅ STT Dictate initialized after app launch")
        NSLog("🎯 Press Fn key to toggle dictation")
        NSLog("🎤 Menu bar icon should now be visible!")
        
        // FIXED: Remove NSApp.run() - AppKit handles run loop automatically
        // The blocking NSApp.run() call prevented menu bar icon from appearing
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        dictationService?.disableFnTap()
        print("👋 STT Dictate terminated")
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}