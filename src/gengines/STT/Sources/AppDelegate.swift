import Cocoa
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dictationService: VoiceDictationService?
    
    // Visual feedback for recording state
    func updateRecordingState(isRecording: Bool) {
        DispatchQueue.main.async {
            guard let button = self.statusItem?.button else { return }
            
            if isRecording {
                // Recording: Red lightning bolt
                if let recordingImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Recording") {
                    recordingImage.isTemplate = false
                    let tintedImage = self.tintImage(recordingImage, with: NSColor.red)
                    button.image = tintedImage
                } else {
                    button.title = "🔴"
                }
                button.toolTip = "STT Dictate - Recording... (Press Fn to stop)"
                NSLog("🔴 RECORDING STATE: ON")
                self.showNotification(title: "STT Dictate", message: "🔴 Recording started - Press Fn to stop")
            } else {
                // Idle: Yellow lightning bolt
                if let idleImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Ready") {
                    idleImage.isTemplate = false
                    let tintedImage = self.tintImage(idleImage, with: NSColor.orange)
                    button.image = tintedImage
                } else {
                    button.title = "⚡"
                }
                button.toolTip = "STT Dictate - Press Fn to toggle"
                NSLog("⚡ RECORDING STATE: OFF")
                self.showNotification(title: "STT Dictate", message: "⚡ Recording stopped")
            }
            
            button.needsDisplay = true
        }
    }
    
    // Show system notification
    func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // Show immediate Fn key feedback
    func showFnKeyPressed() {
        DispatchQueue.main.async {
            // Flash the icon
            guard let button = self.statusItem?.button else { return }
            
            // Show bright green flash for Fn key press
            if let flashImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Fn Pressed") {
                flashImage.isTemplate = false
                let greenImage = self.tintImage(flashImage, with: NSColor.green)
                button.image = greenImage
                button.needsDisplay = true
                
                // Reset after brief flash
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Reset to normal state based on recording status
                    self.updateRecordingState(isRecording: false) // Will be corrected by actual state
                }
            }
            
            // Show notification
            self.showNotification(title: "⚡ Fn Key Detected!", message: "STT Dictate received Fn key press")
            
            NSLog("💚 Fn KEY VISUAL FEEDBACK TRIGGERED")
        }
    }
    
    private func tintImage(_ image: NSImage, with color: NSColor) -> NSImage {
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        color.set()
        image.draw(at: NSPoint.zero, from: NSRect.zero, operation: .sourceAtop, fraction: 1.0)
        tintedImage.unlockFocus()
        return tintedImage
    }
    
    // Shared instance for visual feedback
    static var shared: AppDelegate?
    
    private func isAnotherInstanceRunning() -> Bool {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.stt.dictate"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        
        // If more than one instance with our bundle ID
        if runningApps.count > 1 {
            return true
        }
        
        // Also check by process name as backup
        let processName = ProcessInfo.processInfo.processName
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps aux | grep -v grep | grep '\(processName)' | wc -l"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
            let count = Int(output) ?? 0
            
            // More than 1 means another instance is running
            return count > 1
        } catch {
            NSLog("Error checking for other instances: \(error)")
            return false
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 === STT DICTATE APP DID FINISH LAUNCHING ===")
        print("🚀 === STT DICTATE APP DID FINISH LAUNCHING ===")
        
        // Check if another instance is already running
        if isAnotherInstanceRunning() {
            NSLog("⚠️ Another instance of STT Dictate is already running!")
            
            let alert = NSAlert()
            alert.messageText = "STT Dictate Already Running"
            alert.informativeText = "Another instance of STT Dictate is already running. This instance will quit."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
            NSApp.terminate(nil)
            return
        }
        
        // Set shared instance for visual feedback
        AppDelegate.shared = self
        
        // CRITICAL FIX: Force app activation for event reception (research agent solution)
        NSApp.activate(ignoringOtherApps: true)
        NSLog("✅ App activated")
        
        // Create status bar item with fixed length and simple text
        NSLog("🔨 Creating status bar item...")
        statusItem = NSStatusBar.system.statusItem(withLength: 50) // Fixed length instead of variable
        NSLog("📍 Status item created: \(statusItem != nil ? "SUCCESS" : "FAILED")")
        
        if let statusItem = statusItem, let button = statusItem.button {
            NSLog("🔨 Setting button properties...")
            
            // Use emoji directly for better compatibility
            button.title = "⚡"
            NSLog("✅ Button configured with lightning emoji")
            
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
        
        let toggleItem = NSMenuItem(title: "Toggle Dictation (Fn)", action: #selector(toggleDictation), keyEquivalent: "")
        toggleItem.target = self  // Critical: Set target explicitly
        menu.addItem(toggleItem)
        
        let testItem = NSMenuItem(title: "Test Microphone", action: #selector(testMicrophone), keyEquivalent: "")
        testItem.target = self  // Critical: Set target explicitly
        menu.addItem(testItem)
        
        let simpleTest = NSMenuItem(title: "Test Menu (Flash Icon)", action: #selector(simpleTest), keyEquivalent: "")
        simpleTest.target = self  // Critical: Set target explicitly
        menu.addItem(simpleTest)
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        // Assign menu directly to status item for auto-show on click
        statusItem?.menu = menu
        NSLog("✅ Menu assigned to status item")
        
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
    
    // MARK: - Menu Actions
    
    @objc func toggleDictation() {
        NSLog("🎯 Menu: Toggle Dictation clicked")
        
        // Immediate visual feedback - flash the icon
        if let button = statusItem?.button {
            let originalTitle = button.title
            button.title = "🔴"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                button.title = originalTitle.isEmpty ? "⚡" : originalTitle
            }
        }
        
        // Show alert instead of notification
        let alert = NSAlert()
        alert.messageText = "Toggling Dictation"
        alert.informativeText = "Manually toggling recording state"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        dictationService?.toggleRecording()
    }
    
    @objc func testMicrophone() {
        NSLog("🎤 Menu: Test Microphone clicked")
        
        // Flash icon for feedback
        if let button = statusItem?.button {
            button.title = "🎤"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                button.title = "⚡"
            }
        }
        
        // Show alert with mic status
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Microphone Status"
                alert.informativeText = granted ? "✅ Microphone permission granted!" : "❌ Microphone permission denied\n\nPlease grant permission in System Settings"
                alert.alertStyle = granted ? .informational : .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                NSLog(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
            }
        }
    }
    
    @objc func simpleTest() {
        NSLog("🧪 Simple test clicked!")
        
        // Just change the icon to verify menu is working
        if let button = statusItem?.button {
            // Clear image first, then use title
            button.image = nil
            button.title = "✅"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                button.title = "❌"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    button.title = "⚡"
                }
            }
        }
    }
    
    
    func updateRecordingState(_ isRecording: Bool) {
        DispatchQueue.main.async {
            NSLog("🎤 Recording state changed: \(isRecording)")
            
            if let button = self.statusItem?.button {
                if isRecording {
                    // Red lightning bolt when recording
                    if let recordImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Recording") {
                        button.image = recordImage
                        button.toolTip = "STT Dictate - Recording... (Press Fn to stop)"
                    }
                } else {
                    // Normal lightning bolt when not recording
                    if let normalImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "STT") {
                        button.image = normalImage
                        button.toolTip = "STT Dictate - Press Fn to toggle"
                    }
                }
            }
        }
    }
    
}