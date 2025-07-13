import Foundation
import AVFoundation
import WhisperKit
import CoreGraphics
import Carbon.HIToolbox
import AppKit
import ApplicationServices
import IOKit.hid  // For low-level HID monitoring
import OSLog
import Cocoa  // For NSWorkspace

class VoiceDictationService {
    private var whisperKit: WhisperKit?
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: Task<Void, Never>?
    private var isRecording = false
    private var audioBuffer = [Float]()
    private let bufferLock = NSLock()
    private let bufferQueue = DispatchQueue(label: "com.stt.audiobuffer")
    
    // Event tap for Fn key
    private var eventTap: CFMachPort?
    private var lastFlags: CGEventFlags = CGEventFlags()
    
    // IOKit HID monitoring for Fn key detection (bypasses Sequoia's event suppression)
    private var hidManager: IOHIDManager?
    private var lastModifiers: UInt32 = 0
    private var eventMonitor: Any?  // NSEvent monitor fallback
    
    // Configuration
    private let sampleRate: Double = 16000
    private let chunkDuration: Double = 2.0 // 2.0s chunks for better context
    private let modelName = "openai_whisper-large-v3-turbo"
    
    // Wispr Flow approach: Debug mode for testing
    private let debugMode = false // Set to false for production
    
    // Apple dictation sounds
    private var dictationBeginSound: NSSound?
    private var dictationConfirmSound: NSSound?
    
    // AI editing
    private var textBuffer: String = ""
    private var lastInsertedText: String = ""
    private let aiEditingEnabled = true // Toggle AI enhancement
    private let pythonPath: String
    private let aiEditorScriptPath: String
    
    // Command processing
    private let commandProcessorPath: String
    private var focusedElement: AXUIElement?
    private var commandHistory: [String] = []
    private let maxCommandHistory = 50
    
    init() {
        // Initialize AI editor paths
        let currentDir = FileManager.default.currentDirectoryPath
        
        // Try to use bundled venv first, fallback to development paths
        if let resourcePath = Bundle.main.resourcePath,
           FileManager.default.fileExists(atPath: resourcePath + "/venv/bin/python") {
            self.pythonPath = resourcePath + "/venv/bin/python"
        } else {
            self.pythonPath = currentDir + "/venv/bin/python"
        }
        
        if let scriptPath = Bundle.main.path(forResource: "ai_editor", ofType: "py") {
            self.aiEditorScriptPath = scriptPath
        } else {
            // Fallback to current directory for development
            self.aiEditorScriptPath = currentDir + "/ai_editor.py"
        }
        
        // Initialize command processor path
        if let commandPath = Bundle.main.path(forResource: "ai_command_processor", ofType: "py") {
            self.commandProcessorPath = commandPath
        } else {
            // Fallback to current directory for development
            self.commandProcessorPath = currentDir + "/ai_command_processor.py"
        }
        
        NSLog("🤖 AI Editor initialized: python=\(pythonPath), script=\(aiEditorScriptPath)")
        NSLog("🎯 Command Processor initialized: script=\(commandProcessorPath)")
        
        checkAccessibilityPermissions()
        setupWhisperKit()
        setupDictationSounds()
        // DON'T setup hotkey in init - wait for app launch
    }
    
    // NEW: Call this AFTER applicationDidFinishLaunching
    func initializeAfterLaunch() {
        NSLog("🚀 Initializing STT after app launch...")
        
        // CRITICAL: Check TCC permissions early to force cache refresh and detect bugs
        checkAccessibilityPermissions()
        
        checkSystemSettings()
        // PERMANENTLY DISABLED hidutil remapping - causes system freeze in Sequoia
        // hidutil is deprecated and unstable in macOS 15.x - using IOKit HID instead
        setupHIDMonitor()  // Primary: IOKit low-level detection bypasses Sequoia suppression
        setupNSEventMonitor()  // Fallback: NSEvent monitoring
        setupHotkey()  // Backup: CGEventTap (for debugging)
    }
    
    private func applyHidutilRemapping() {
        NSLog("🔧 Applying hidutil Fn key remapping for Sequoia compatibility...")
        NSLog("   Remapping Fn (0x700000065) → keyCode 255 (0x7000000FF)")
        
        let task = Process()
        task.launchPath = "/usr/bin/hidutil"
        task.arguments = ["property", "--set", "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x700000065,\"HIDKeyboardModifierMappingDst\":0x7000000FF}]}"]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                NSLog("✅ hidutil remapping applied successfully")
                NSLog("🔧 Fn key will now generate keyDown/keyUp events instead of flagsChanged")
                NSLog("🎯 This bypasses Sequoia's modifier event filtering")
            } else {
                NSLog("⚠️ hidutil remapping failed with status: \(task.terminationStatus)")
            }
        } catch {
            NSLog("❌ Failed to run hidutil: \(error)")
        }
    }
    
    private func setupHIDMonitor() {
        NSLog("🔧 Setting up IOKit HID monitor for Fn key detection...")
        
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else {
            NSLog("❌ Failed to create IOHIDManager")
            return
        }
        
        // Match keyboard devices (usage page and usage for keyboards)
        let matchingDict: CFDictionary = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ] as CFDictionary
        IOHIDManagerSetDeviceMatching(manager, matchingDict)
        
        // Register callback for input value changes (keystrokes and modifiers)
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context else { return }
            let service = Unmanaged<VoiceDictationService>.fromOpaque(context).takeUnretainedValue()
            
            let elem = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(elem)
            let usage = IOHIDElementGetUsage(elem)
            let modifierValue = IOHIDValueGetIntegerValue(value)
            
            // Log all for debugging to find exact Fn usage (run once, note Fn's usage)
            NSLog("📥 HID event: usagePage=\(usagePage), usage=\(usage), value=\(modifierValue)")
            
            // Detect Fn: On Apple keyboards, Fn is often usage 0xFF (or kHIDUsage_KbdFN ~101 decimal) in keyboard page
            // Adjust based on your logs: Press Fn and look for unique usage (e.g., 101 or bit shift)
            if usagePage == kHIDPage_KeyboardOrKeypad && (usage == 101 || usage == 0xFF || usage == 255) {  // Common Fn usages; confirm via logs
                if modifierValue == 1 && (service.lastModifiers & (1 << usage)) == 0 {  // Press down (value 1) and not previously set
                    NSLog("🔑 HID Fn key pressed - toggling dictation")
                    
                    // Show visual feedback immediately
                    AppDelegate.shared?.showFnKeyPressed()
                    
                    service.toggleRecording()
                }
                // Update state to detect press/release
                if modifierValue == 1 {
                    service.lastModifiers |= (1 << usage)
                } else {
                    service.lastModifiers &= ~(1 << usage)
                }
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        
        // Schedule with main run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        // Open the manager (requires Input Monitoring permission, already granted)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            NSLog("❌ HID open failed: \(openResult) - Check Input Monitoring permission")
        } else {
            NSLog("✅ HID monitor setup successful - monitoring for Fn key events")
        }
    }
    
    private func setupNSEventMonitor() {
        NSLog("🔧 Setting up NSEvent monitor as fallback for Fn key detection...")
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            if event.modifierFlags.contains(.function) {
                NSLog("🔑 NSEvent Fn key pressed - toggling dictation")
                
                // Show visual feedback immediately
                AppDelegate.shared?.showFnKeyPressed()
                
                self.toggleRecording()
            }
        }
        
        if eventMonitor != nil {
            NSLog("✅ NSEvent monitor setup successful")
        } else {
            NSLog("❌ Failed to setup NSEvent monitor")
        }
    }
    
    deinit {
        // Clean up HID manager
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        
        // Clean up NSEvent monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        disableFnTap()
    }
    
    private func setupWhisperKit() {
        Task {
            do {
                NSLog("📥 WHISPERKIT: Starting model loading...")
                print("📥 Loading WhisperKit model...")
                
                // Use Application Support directory instead of Documents to avoid permission prompts
                let appSupportURL = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                // Create WhisperKit subdirectory in Application Support
                let whisperKitFolder = appSupportURL.appendingPathComponent("STTDictate/WhisperKit")
                try FileManager.default.createDirectory(
                    at: whisperKitFolder,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                
                NSLog("📁 WHISPERKIT: Using model directory: \(whisperKitFolder.path)")
                print("📁 Using model directory: \(whisperKitFolder.path)")
                
                // Try to load the large-v3-turbo model (let it download to default location first)
                NSLog("🔄 WHISPERKIT: Initializing large-v3-turbo model...")
                whisperKit = try await WhisperKit(
                    model: "openai_whisper-large-v3-turbo"
                )
                NSLog("✅ WHISPERKIT: Model loaded successfully!")
                print("✅ WhisperKit loaded successfully")
                print("🎯 Ready! Press Fn to start/stop dictation")
            } catch {
                NSLog("❌ WHISPERKIT: Failed to load turbo model: \(error)")
                print("❌ Failed to load turbo model: \(error)")
                print("🔄 Falling back to default model...")
                do {
                    // Fallback to default model with Application Support
                    let appSupportURL = try FileManager.default.url(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )
                    let whisperKitFolder = appSupportURL.appendingPathComponent("STTDictate/WhisperKit")
                    
                    NSLog("🔄 WHISPERKIT: Trying fallback model...")
                    whisperKit = try await WhisperKit()
                    NSLog("✅ WHISPERKIT: Fallback model loaded successfully!")
                    print("✅ WhisperKit fallback loaded successfully")
                } catch {
                    NSLog("❌ WHISPERKIT: FAILED to load any model: \(error)")
                    print("❌ Failed to load any WhisperKit model: \(error)")
                }
            }
        }
    }
    
    private func setupDictationSounds() {
        NSLog("🔊 Loading custom dictation sounds...")
        
        // Load custom dictation sounds from app bundle Resources
        if let bundle = Bundle.main.resourcePath {
            // Load begin sound (dictation_event1.wav)
            let beginSoundPath = bundle + "/dictation_event1.wav"
            if FileManager.default.fileExists(atPath: beginSoundPath) {
                dictationBeginSound = NSSound(contentsOfFile: beginSoundPath, byReference: true)
                NSLog("✅ Loaded dictation begin sound: dictation_event1.wav")
            } else {
                NSLog("⚠️ Dictation begin sound not found at: \(beginSoundPath)")
            }
            
            // Load confirm sound (dictation_event2.wav)
            let confirmSoundPath = bundle + "/dictation_event2.wav"
            if FileManager.default.fileExists(atPath: confirmSoundPath) {
                dictationConfirmSound = NSSound(contentsOfFile: confirmSoundPath, byReference: true)
                NSLog("✅ Loaded dictation confirm sound: dictation_event2.wav")
            } else {
                NSLog("⚠️ Dictation confirm sound not found at: \(confirmSoundPath)")
            }
        } else {
            NSLog("❌ Could not find app bundle resource path")
        }
    }
    
    // MARK: - Command Processing
    
    struct Classification {
        let isCommand: Bool
        let intent: String
        let params: [String: String]
        
        static let notCommand = Classification(isCommand: false, intent: "", params: [:])
    }
    
    private func classifyText(_ text: String) async -> Classification {
        NSLog("🎯 Classifying text for commands: '\(text)'")
        
        let jsonInput = [
            "input": text,
            "type": "classify"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonInput),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            NSLog("❌ Failed to create JSON input for classification")
            return Classification.notCommand
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = pythonPath
            process.arguments = [commandProcessorPath, jsonString]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    NSLog("🎯 Classification output: \(output)")
                    
                    if let data = output.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let isCommand = json["is_command"] as? Bool {
                        
                        let intent = json["intent"] as? String ?? ""
                        let params = json["params"] as? [String: String] ?? [:]
                        
                        continuation.resume(returning: Classification(isCommand: isCommand, intent: intent, params: params))
                    } else {
                        continuation.resume(returning: Classification.notCommand)
                    }
                } else {
                    continuation.resume(returning: Classification.notCommand)
                }
            }
            
            do {
                try process.run()
            } catch {
                NSLog("❌ Failed to run command classification: \(error)")
                continuation.resume(returning: Classification.notCommand)
            }
        }
    }
    
    @MainActor
    private func executeCommand(_ classification: Classification) async {
        NSLog("⚡ Executing command: \(classification.intent)")
        
        // Update focused element
        var focused: CFTypeRef?
        AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        if let focused = focused {
            focusedElement = unsafeBitCast(focused, to: AXUIElement.self)
        }
        
        guard let element = focusedElement else {
            NSLog("❌ No focused element for command execution")
            return
        }
        
        switch classification.intent {
        case "delete":
            await executeDeleteCommand(classification.params, in: element)
        case "insert":
            await executeInsertCommand(classification.params, in: element)
        default:
            NSLog("⚠️ Command not implemented: \(classification.intent)")
        }
    }
    
    @MainActor
    private func executeDeleteCommand(_ params: [String: String], in element: AXUIElement) async {
        let target = params["target"] ?? "last_word"
        NSLog("🗑️ Deleting: \(target)")
        
        // Simple implementation: delete last character for now
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if let currentText = value as? String, !currentText.isEmpty {
            let newText = String(currentText.dropLast())
            AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
        }
        
        NSSound.beep() // Confirmation
    }
    
    @MainActor
    private func executeInsertCommand(_ params: [String: String], in element: AXUIElement) async {
        let content = params["content"] ?? "new_line"
        NSLog("➕ Inserting: \(content)")
        
        var textToInsert = ""
        switch content {
        case "bullet_point":
            textToInsert = "\n- "
        case "new_line":
            textToInsert = "\n"
        default:
            textToInsert = content
        }
        
        // Get current text and append
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        let currentText = value as? String ?? ""
        let newText = currentText + textToInsert
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
    }
    
    // MARK: - AI Editing
    
    private func callAIEditor(_ rawText: String) async -> String {
        // Call Python AI editor script to enhance raw transcription.
        // Returns enhanced text or original text on failure.
        guard aiEditingEnabled && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return rawText
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [aiEditorScriptPath, rawText]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set timeout
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second timeout
                if process.isRunning {
                    NSLog("⚠️ AI editor timeout, terminating process")
                    process.terminate()
                }
            }
            
            process.terminationHandler = { _ in
                timeoutTask.cancel()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    NSLog("🤖 AI edited: '\(rawText)' → '\(output)'")
                    continuation.resume(returning: output)
                } else {
                    if let error = String(data: errorData, encoding: .utf8) {
                        NSLog("❌ AI editor error: \(error)")
                    }
                    NSLog("⚠️ AI editor failed, using raw text")
                    continuation.resume(returning: rawText)
                }
            }
            
            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                NSLog("❌ Failed to run AI editor: \(error)")
                continuation.resume(returning: rawText)
            }
        }
    }
    
    private func shouldProcessTextBuffer() -> Bool {
        // Determine if text buffer should be processed for AI editing.
        // Process when buffer ends with sentence-ending punctuation or reaches length threshold.
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Process if buffer ends with sentence punctuation
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            return true
        }
        
        // Process if buffer gets too long (avoid context window issues)
        if trimmed.count > 200 {
            return true
        }
        
        return false
    }
    
    @MainActor
    private func replaceLastInsertedText(with newText: String) {
        // Replace the last inserted text with AI-enhanced version using AXUIElement.
        guard !lastInsertedText.isEmpty && newText != lastInsertedText else {
            NSLog("🔄 No text replacement needed")
            return
        }
        
        NSLog("🔄 Replacing text: '\(lastInsertedText)' → '\(newText)'")
        
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        // Get currently focused element
        if AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
           let element = focusedElement as! AXUIElement? {
            
            let axElement = element as! AXUIElement
            
            // Try to select the last inserted text and replace it
            let lastInsertedLength = lastInsertedText.count
            
            // Get current selected text or cursor position
            var selectedTextValue: AnyObject?
            if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success {
                // If text is selected, replace it
                if AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, newText as CFString) == .success {
                    NSLog("✅ Text replaced via AXSelectedText")
                    lastInsertedText = newText
                    return
                }
            }
            
            // Fallback: Try to select last inserted text by moving cursor and selecting
            var selectedRangeValue: AnyObject?
            if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
               let rangeValue = selectedRangeValue {
                
                var range = CFRange()
                if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) {
                    // Select the last inserted text
                    var newRange = CFRange(location: max(0, range.location - lastInsertedLength), length: lastInsertedLength)
                    let newRangeValue = AXValueCreate(.cfRange, &newRange)!
                    
                    if AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, newRangeValue) == .success {
                        // Now replace the selected text
                        if AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, newText as CFString) == .success {
                            NSLog("✅ Text replaced via range selection")
                            lastInsertedText = newText
                            return
                        }
                    }
                }
            }
        }
        
        NSLog("⚠️ Could not replace text via AXUIElement, text remains as-is")
    }
    
    private func checkAccessibilityPermissions() {
        NSLog("🔐 Starting comprehensive TCC cache bug detection and remediation...")
        
        // Force prompt to invalidate cache
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trustedWithPrompt = AXIsProcessTrustedWithOptions(options)
        NSLog("🔍 AXIsProcessTrustedWithOptions result: \(trustedWithPrompt)")
        
        let trustedCached = AXIsProcessTrusted()
        NSLog("🔍 AXIsProcessTrusted (cached) result: \(trustedCached)")
        
        if trustedWithPrompt && !trustedCached {
            NSLog("🐛 DETECTED: macOS Sequoia TCC caching bug")
            handleTCCCacheBug()
            return
        }
        
        if !trustedWithPrompt && !trustedCached {
            NSLog("❌ Accessibility permissions completely denied")
            showPermissionInstructions()
            return
        }
        
        if trustedCached {
            NSLog("✅ Accessibility granted")
            return
        }
        
        // Edge case retry
        let _ = AXIsProcessTrustedWithOptions(options)
        let finalCheck = AXIsProcessTrusted()
        NSLog("🔐 Final status after retry: \(finalCheck ? "GRANTED" : "DENIED")")
        
        if !finalCheck {
            handleTCCCacheBug()
        }
    }
    
    private func handleTCCCacheBug() {
        NSLog("🔧 HANDLING SEQUOIA TCC CACHE BUG - Known issue affecting rebuilt/self-signed apps")
        NSLog("")
        NSLog("📋 AUTOMATED REMEDIATION STEPS:")
        NSLog("1. Attempting automated TCC reset...")
        
        // Step 1: Automated TCC reset
        let resetResult = resetTCCDatabase()
        if resetResult {
            NSLog("✅ TCC database reset successful")
        } else {
            NSLog("⚠️ TCC database reset failed or not needed")
        }
        
        // Step 2: Daemon reload
        reloadSystemDaemons()
        
        // Step 3: Re-test after automated fixes
        let retestResult = AXIsProcessTrusted()
        if retestResult {
            NSLog("🎉 AUTOMATED FIX SUCCESSFUL - TCC cache bug resolved!")
            return
        }
        
        // Step 4: Manual intervention required
        NSLog("❌ Automated fixes insufficient - manual intervention required")
        showTCCCacheBugInstructions()
    }
    
    private func resetTCCDatabase() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Accessibility", "com.stt.dictate"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            NSLog("⚠️ Failed to execute tccutil reset: \(error)")
            return false
        }
    }
    
    private func reloadSystemDaemons() {
        NSLog("🔄 Reloading system preference and TCC daemons...")
        
        let daemons = ["cfprefsd", "tccd"]
        for daemon in daemons {
            let task = Process()
            task.launchPath = "/usr/bin/killall"
            task.arguments = [daemon]
            
            do {
                try task.run()
                task.waitUntilExit()
                NSLog("✅ Reloaded \(daemon)")
            } catch {
                NSLog("⚠️ Failed to reload \(daemon): \(error)")
            }
        }
        
        // Give daemons time to restart
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    private func showTCCCacheBugInstructions() {
        NSLog("")
        NSLog("🔧 MANUAL TCC CACHE BUG FIX REQUIRED (macOS Sequoia Known Issue)")
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        NSLog("")
        NSLog("📍 STEP 1: Open System Settings")
        NSLog("   → System Settings > Privacy & Security > Accessibility")
        NSLog("")
        NSLog("📍 STEP 2: Remove STT Dictate")
        NSLog("   → Find 'STT Dictate' in the list")
        NSLog("   → UNCHECK the checkbox")
        NSLog("   → Click the [-] button to REMOVE completely")
        NSLog("   → Confirm any removal prompts")
        NSLog("")
        NSLog("📍 STEP 3: Re-add STT Dictate (Critical for cache clearing)")
        NSLog("   → Click the [+] button")
        NSLog("   → Drag '/Applications/STT Dictate.app' into the list")
        NSLog("   → OR browse and select the app")
        NSLog("   → CHECK the checkbox to enable")
        NSLog("")
        NSLog("📍 STEP 4: Restart STT Dictate")
        NSLog("   → Quit this app completely")
        NSLog("   → Launch from Applications folder")
        NSLog("   → Should see '✅ Accessibility granted' in logs")
        NSLog("")
        NSLog("🎯 This will restore instant AXUIElement text insertion!")
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    private func showPermissionInstructions() {
        NSLog("")
        NSLog("🔧 ACCESSIBILITY PERMISSIONS REQUIRED")
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        NSLog("📍 System Settings > Privacy & Security > Accessibility")
        NSLog("📍 Add 'STT Dictate' and enable the checkbox")
        NSLog("📍 Required for instant text insertion")
        NSLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    private func checkSystemSettings() {
        print("🔍 Checking system settings for Fn key conflicts...")
        
        // Check if Fn key is set to show emoji picker
        let fnUsageType = UserDefaults.standard.object(forKey: "AppleFnUsageType") as? Int ?? 1
        print("📋 Current Fn key setting: \(fnUsageType == 0 ? "Do Nothing" : "Show Emoji & Symbols")")
        
        if fnUsageType != 0 {
            print("⚠️  WARNING: Fn key is set to 'Show Emoji & Symbols'")
            print("   Applying Wispr Flow approach - disabling automatically...")
            UserDefaults.standard.set(0, forKey: "AppleFnUsageType")
            UserDefaults.standard.synchronize()
        }
        
        // Apply additional Wispr Flow system optimizations
        print("🔧 Applying Wispr Flow system optimizations...")
        
        // Force standard F-keys behavior (reduces Fn hooks)
        UserDefaults.standard.set(true, forKey: "com.apple.keyboard.fnState")
        UserDefaults.standard.synchronize()
        
        print("✅ System settings optimized for Fn interception")
    }
    
    private func setupHotkey() {
        NSLog("⌨️ Setting up Fn key interceptor...")
        
        // Check system settings
        checkSystemSettings()
        
        // Check if we have Input Monitoring permission
        NSLog("🔐 Checking Input Monitoring permission...")
        
        // Monitor flagsChanged, keyDown, and keyUp events
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        // Create callback that captures self
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        // TARGETED APPROACH: Use default tap but ONLY consume Fn events
        // Safe because we're not using hidutil remapping anymore
        let tapOptions: CGEventTapOptions = .defaultTap
        NSLog("📋 Event tap options: DEFAULT (consume Fn events only)")
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: tapOptions,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { 
                    print("🚨 Event callback: userInfo is nil")
                    return Unmanaged.passRetained(event) 
                }
                let service = Unmanaged<VoiceDictationService>.fromOpaque(userInfo).takeUnretainedValue()
                
                // Debug: Log all events to see what we're receiving
                NSLog("📥 Event received: type=\(type.rawValue) (\(type))")
                
                // Set timestamp for Sequoia compatibility (Wispr Flow approach)
                if event.timestamp == 0 {
                    event.timestamp = CGEventTimestamp(mach_absolute_time())
                }
                
                // Handle flagsChanged events (SAFE method for Fn modifier detection)
                if type == .flagsChanged {
                    let currentFlags = event.flags
                    let fnFlag = CGEventFlags.maskSecondaryFn
                    
                    NSLog("   Flags: current=\(currentFlags.rawValue), last=\(service.lastFlags.rawValue)")
                    NSLog("   Fn flag present: \(currentFlags.contains(fnFlag))")
                    
                    // Detect Fn press: Flag set now but not before
                    if currentFlags.contains(fnFlag) && !service.lastFlags.contains(fnFlag) {
                        NSLog("🔑 Fn key pressed (flagsChanged) - toggling dictation")
                        
                        // Show visual feedback immediately
                        AppDelegate.shared?.showFnKeyPressed()
                        
                        service.toggleRecording()
                        service.lastFlags = currentFlags
                        
                        // CONSUME Fn event to prevent emoji picker
                        NSLog("🚫 Consuming Fn event to prevent emoji picker")
                        return nil
                    }
                    
                    // Update state for next comparison
                    service.lastFlags = currentFlags
                }
                
                // Pass through all non-Fn events (only consume Fn to prevent emoji)
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )
        
        if let eventTap = eventTap {
            NSLog("✅ Event tap created successfully")
            
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            // CRITICAL FIX: Use main run loop instead of current for app bundles
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            NSLog("📍 Run loop sources added to common and default modes")
            
            // Enable the event tap
            CGEvent.tapEnable(tap: eventTap, enable: true)
            
            // Verify it's enabled
            let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)
            NSLog("✅ Event tap enabled: \(isEnabled)")
            NSLog("🔍 Event mask: \(eventMask) (flagsChanged + keyDown + keyUp)")
            NSLog("🎯 Ready - Press Fn key to test (will show debug output)")
            
            if !isEnabled {
                NSLog("⚠️ WARNING: Event tap is NOT enabled!")
                NSLog("   You may need to grant Input Monitoring permission")
                NSLog("⚠️ Please grant Input Monitoring permission to STT Dictate in System Settings")
            }
        } else {
            print("❌ Failed to create event tap")
            print("❌ Possible causes:")
            print("   - Missing Accessibility permissions")
            print("   - Missing Input Monitoring permissions (required for Sonoma/Sequoia)")
            print("   - App not in /Applications or not properly code-signed")
            print("   - System security restrictions")
        }
    }
    
    func disableFnTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            print("🔌 Fn key interceptor disabled")
        }
    }
    
    func toggleRecording() {
        NSLog("🎯 Toggle recording called (currently recording: \(isRecording))")
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func isWhisperKitReady() -> Bool {
        let ready = whisperKit != nil
        NSLog("🔍 WhisperKit ready check: \(ready ? "READY" : "NOT READY")")
        return ready
    }
    
    func startRecording() {
        guard !isRecording else { 
            NSLog("⚠️ Already recording, ignoring start request")
            return 
        }
        
        // Check if WhisperKit is ready
        guard whisperKit != nil else {
            NSLog("❌ WhisperKit not ready yet")
            NSLog("⚠️ WhisperKit is still loading. Please wait a moment and try again.")
            return
        }
        
        NSLog("🎤 Starting recording process...")
        
        // Check microphone permission status first
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch micStatus {
        case .authorized:
            // Already have permission, start immediately
            NSLog("🎤 Microphone permission already granted")
            DispatchQueue.main.async {
                self.actuallyStartRecording()
            }
            
        case .notDetermined:
            // Need to request permission for the first time
            NSLog("🎤 Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if granted {
                        NSLog("🎤 Microphone permission granted, starting recording...")
                        self.actuallyStartRecording()
                    } else {
                        NSLog("❌ Microphone permission denied")
                        NSLog("❌ Please grant microphone access in System Settings")
                    }
                }
            }
            
        case .denied, .restricted:
            // Permission denied or restricted
            NSLog("❌ Microphone permission denied")
            NSLog("❌ Please grant microphone access in System Settings > Privacy & Security > Microphone")
            
        @unknown default:
            NSLog("❌ Unknown microphone permission status")
        }
    }
    
    private func actuallyStartRecording() {
        NSLog("🎤 Actually starting recording...")
        
        do {
            // Double-check WhisperKit is ready
            guard whisperKit != nil else {
                NSLog("❌ WhisperKit became nil during recording start")
                throw NSError(domain: "STTError", code: 1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit not ready"])
            }
            
            // Note: No AVAudioSession configuration needed on macOS - handled by AVAudioEngine
            
            isRecording = true
            
            // Update visual feedback
            AppDelegate.shared?.updateRecordingState(isRecording: true)
            
            // Play Apple dictation begin sound
            dictationBeginSound?.play()
            
            bufferQueue.sync {
                audioBuffer.removeAll()
            }
            
            // Reset audio engine if needed
            if audioEngine.isRunning {
                audioEngine.stop()
                NSLog("🔄 Stopped existing audio engine")
            }
            
            // Reset the audio engine to clear any previous configuration
            audioEngine.reset()
            NSLog("🔄 Audio engine reset")
            
            let inputNode = audioEngine.inputNode
            NSLog("📋 Input node format: \(inputNode.inputFormat(forBus: 0))")
            
            // Use the input node's native format instead of forcing our own
            let inputFormat = inputNode.inputFormat(forBus: 0)
            
            // Create a compatible format for WhisperKit (16kHz, mono, float32)
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,  // 16000 Hz for WhisperKit
                channels: 1,
                interleaved: false
            )!
            
            // Remove any existing tap to prevent conflicts (safe even if none exists)
            inputNode.removeTap(onBus: 0)
            NSLog("🗑️ Removed any existing audio tap")
            
            // Install tap with input node's native format first
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                // Convert to target format if needed
                if inputFormat.sampleRate != self.sampleRate || inputFormat.channelCount != 1 {
                    // Convert format asynchronously to avoid blocking the audio thread
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let convertedBuffer = self.convertAudioBuffer(buffer, from: inputFormat, to: targetFormat) {
                            self.processAudioBuffer(convertedBuffer)
                        }
                    }
                } else {
                    // Direct processing if formats match
                    self.processAudioBuffer(buffer)
                }
            }
            
            NSLog("✅ Audio tap installed successfully")
            
            // Prepare and start the audio engine
            NSLog("🔧 Preparing audio engine...")
            audioEngine.prepare()
            NSLog("✅ Audio engine prepared")
            
            NSLog("🚀 Starting audio engine...")
            try audioEngine.start()
            NSLog("✅ Audio engine started successfully - isRunning: \(audioEngine.isRunning)")
            
            NSLog("🎯 About to start transcription task...")
            startTranscriptionTask()
            NSLog("✅ Recording started successfully - transcription task created")
            
            // Test if audio tap is actually working
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSLog("📋 Audio engine status check: isRunning=\(self.audioEngine.isRunning), recording=\(self.isRecording)")
                NSLog("📋 Current audio buffer size: \(self.audioBuffer.count) samples")
            }
            
        } catch {
            NSLog("❌ Failed to start recording: \(error)")
            isRecording = false
            
            // Clean up on failure
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            
            // Update visual feedback to show error
            AppDelegate.shared?.updateRecordingState(isRecording: false)
            
            NSLog("❌ Failed to start audio recording: \(error.localizedDescription)")
        }
    }
    
    
    private func convertAudioBuffer(_ buffer: AVAudioPCMBuffer, from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            NSLog("❌ Failed to create audio converter")
            return nil
        }
        
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            NSLog("❌ Failed to create converted buffer")
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error || error != nil {
            NSLog("❌ Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
            return nil
        }
        
        return convertedBuffer
    }
    
    func stopRecording() {
        guard isRecording else { 
            NSLog("⚠️ Not recording, ignoring stop request")
            return 
        }
        
        NSLog("🛑 Stopping recording...")
        isRecording = false
        
        // Update visual feedback
        AppDelegate.shared?.updateRecordingState(isRecording: false)
        
        // Play Apple dictation confirm sound
        dictationConfirmSound?.play()
        
        // Stop audio engine safely and remove tap
        if audioEngine.isRunning {
            // Remove tap before stopping engine
            audioEngine.inputNode.removeTap(onBus: 0)
            NSLog("🗑️ Audio tap removed")
            
            audioEngine.stop()
            NSLog("✅ Audio engine stopped")
        } else {
            // Even if engine not running, try to remove tap (safe operation)
            audioEngine.inputNode.removeTap(onBus: 0)
            NSLog("🗑️ Audio tap removed (engine not running)")
        }
        
        // Cancel recognition task (will interrupt sleep but not transcription)
        recognitionTask?.cancel()
        recognitionTask = nil
        NSLog("✅ Recognition task cancelled")
        
        // Process any remaining audio in buffer as final chunk
        bufferQueue.sync {
            if !audioBuffer.isEmpty {
                Task {
                    await processChunk()
                    NSLog("✅ Final audio chunk processed")
                }
            } else {
                NSLog("📊 No remaining audio in buffer for final processing")
            }
        }
        
        NSLog("✅ Recording stopped successfully")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { 
            NSLog("⚠️ No channel data in audio buffer")
            return 
        }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }
        
        NSLog("🎤 Received audio buffer: \(buffer.frameLength) frames, \(channelDataValueArray.count) samples")
        
        bufferQueue.sync {
            audioBuffer.append(contentsOf: channelDataValueArray)
            NSLog("📊 Total audio buffer size: \(audioBuffer.count) samples")
        }
    }
    
    private func nonCancellableAsync<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let result = try await operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func startTranscriptionTask() {
        NSLog("🎯 Starting transcription task...")
        recognitionTask = Task {
            while isRecording {
                NSLog("🔄 Processing audio chunk...")
                await processChunk()
                do {
                    try await Task.sleep(nanoseconds: UInt64(chunkDuration * 1_000_000_000))
                } catch {
                    NSLog("🛑 Sleep interrupted by cancellation")
                    break  // Exit loop immediately on cancellation
                }
            }
            NSLog("🛑 Transcription task ended (isRecording: \(isRecording))")
        }
    }
    
    private func processChunk() async {
        var chunk = bufferQueue.sync {
            let data = audioBuffer
            audioBuffer.removeAll()
            return data
        }
        
        NSLog("📊 Audio chunk size: \(chunk.count) samples")
        
        guard !chunk.isEmpty else { 
            NSLog("⚠️ Audio chunk is empty - no audio data received")
            return 
        }
        
        // Check if audio is too quiet before processing
        if let maxAbs = chunk.max(by: { abs($0) < abs($1) }) {
            let maxValue = abs(maxAbs)
            NSLog("🔊 Audio level check: max amplitude = \(maxValue)")
            
            // Apply amplification if audio is very quiet (but not silent)
            if maxValue > 0.001 && maxValue < 0.1 {
                let amplificationFactor: Float = 5.0  // Boost quiet audio
                chunk = chunk.map { $0 * amplificationFactor }
                let newMaxValue = abs(chunk.max(by: { abs($0) < abs($1) }) ?? 0)
                NSLog("🔊 Applied \(amplificationFactor)x amplification: \(maxValue) → \(newMaxValue)")
            }
            
            // Check for minimum volume threshold
            let finalMaxValue = abs(chunk.max(by: { abs($0) < abs($1) }) ?? 0)
            if finalMaxValue < 0.01 {
                NSLog("⚠️ Audio too quiet (max: \(finalMaxValue)) - may not transcribe well")
                NSLog("💡 Try speaking louder or check microphone settings")
            }
            
            // Normalize audio to [-1.0, 1.0] range
            if finalMaxValue > 0 && finalMaxValue < 1.0 {
                chunk = chunk.map { $0 / finalMaxValue }
                NSLog("🔊 Normalized audio (final max abs: \(finalMaxValue))")
            } else {
                NSLog("🔊 Audio already normalized or silent (max abs: \(finalMaxValue))")
            }
        }
        
        guard let whisperKit = whisperKit else { 
            NSLog("❌ WhisperKit is not ready")
            return 
        }
        
        NSLog("🎙️ Sending \(chunk.count) samples to WhisperKit for transcription...")
        
        let transcription: [TranscriptionResult]
        do {
            transcription = try await nonCancellableAsync {
                try await whisperKit.transcribe(
                    audioArray: chunk,
                    decodeOptions: DecodingOptions(
                        task: .transcribe,
                        language: "en",
                        usePrefillPrompt: false,
                        skipSpecialTokens: false, // Allow special tokens for debugging
                        withoutTimestamps: true
                    )
                )
            }
        } catch {
            NSLog("❌ Transcription error: \(error)")
            return
        }
        
        NSLog("✅ WhisperKit transcription completed. Results: \(transcription.count)")
        
        // Debug: Full results
        for (index, result) in transcription.enumerated() {
            NSLog("📋 Result \(index): text='\(result.text)', seekTime=\(result.seekTime ?? 0.0)")
        }
        
        if let text = transcription.first?.text {
            let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            NSLog("🔍 Raw text: '\(text)' (length: \(text.count))")
            NSLog("🔍 Trimmed text: '\(trimmedText)' (length: \(trimmedText.count))")
            
            if !trimmedText.isEmpty {
                NSLog("📝 Transcribed text: '\(trimmedText)'")
                await processAndInsertText(trimmedText)
            } else {
                NSLog("⚠️ Text is empty after trimming whitespace")
            }
        } else {
            NSLog("❌ No text in first transcription result")
        }
    }
    
    // AI Enhancement: Process raw text through AI editor
    private func enhanceTextWithAI(_ rawText: String) async -> String {
        guard aiEditingEnabled else {
            NSLog("🤖 AI editing disabled, using raw text")
            return rawText
        }
        
        NSLog("🤖 Enhancing text with AI: '\(rawText)'")
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.launchPath = pythonPath
            process.arguments = [aiEditorScriptPath, rawText]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), 
                   !output.isEmpty {
                    NSLog("🤖 AI enhanced text: '\(output)'")
                    continuation.resume(returning: output)
                } else {
                    NSLog("⚠️ AI editing failed, using raw text")
                    if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                        NSLog("🤖 AI Error: \(errorString)")
                    }
                    continuation.resume(returning: rawText)
                }
            }
            
            do {
                try process.run()
            } catch {
                NSLog("❌ Failed to run AI editor: \(error)")
                continuation.resume(returning: rawText)
            }
        }
    }
    
    // Enhanced text processing pipeline
    private func processAndInsertText(_ rawText: String) async {
        // First, check if this is a command
        let classification = await classifyText(rawText)
        
        if classification.isCommand {
            NSLog("🎯 Detected command: \(classification.intent)")
            await executeCommand(classification)
            return // Don't insert command text
        }
        
        // Not a command, process as regular text
        let enhancedText = await enhanceTextWithAI(rawText)
        await insertText(enhancedText)
    }
    
    @MainActor
    private func insertText(_ text: String) async {
        NSLog("⌨️ Inserting text: '\(text)'")
        
        let processedText = processCommands(text)
        NSLog("⌨️ Processed text: '\(processedText)'")
        
        // Add to buffer for AI processing
        textBuffer += " " + processedText
        textBuffer = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Insert raw text immediately for responsiveness
        await insertRawText(processedText)
        lastInsertedText = processedText
        
        // Check if we should process the buffer for AI editing
        if shouldProcessTextBuffer() {
            NSLog("🤖 Processing text buffer for AI enhancement...")
            let currentBuffer = textBuffer
            
            // Process buffer with AI in background
            Task {
                let enhancedText = await callAIEditor(currentBuffer)
                if enhancedText != currentBuffer {
                    await MainActor.run {
                        self.replaceLastInsertedText(with: enhancedText)
                    }
                }
            }
            
            // Clear buffer after processing
            textBuffer = ""
        }
    }
    
    @MainActor
    private func insertRawText(_ text: String) async {
        // Wispr Flow approach: Always attempt AXUIElement insertion first
        // This bypasses the macOS Sequoia TCC cache bug where AXIsProcessTrusted() 
        // returns false despite granted permissions
        NSLog("🚀 ATTEMPTING AXUIElement insertion (bypassing TCC cache check)")
        
        if await attemptAXUIElementInsertion(text) {
            NSLog("✅ AXUIElement insertion successful - bypassed TCC cache bug!")
            return
        }
        
        // Traditional permission check for logging
        let permissionGranted = AXIsProcessTrusted()
        if !permissionGranted {
            NSLog("❌ ACCESSIBILITY DENIED (cached) - AXUIElement failed, using CGEvent fallback")
            NSLog("💡 TIP: If permissions are granted in Settings but this shows denied, restart the app")
        } else {
            NSLog("⚠️ AXUIElement failed despite cached permissions - using CGEvent fallback")
        }
        
        NSLog("⚠️ Using fallback CGEvent method (slower but works)")
        for char in text {
            await insertCharacter(String(char))
        }
    }
    
    @MainActor
    private func attemptAXUIElementInsertion(_ text: String) async -> Bool {
        
        NSLog("🆕 ATTEMPTING AXUIElement text insertion method")
        
        // Get system-wide accessibility element
        NSLog("🔍 Creating system-wide AX element...")
        let systemWide = AXUIElementCreateSystemWide()
        NSLog("✅ System-wide AX element created")
        
        var focusedElement: AnyObject?
        NSLog("🔍 Getting focused UI element...")
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        NSLog("🔍 AXUIElementCopyAttributeValue result: \(error.rawValue)")
        
        if error != .success {
            NSLog("❌ Failed to get focused UI element: AXError(\(error.rawValue))")
            
            // Decode the AX error
            switch error {
            case .success: NSLog("   AXError: success")
            case .failure: NSLog("   AXError: failure")
            case .illegalArgument: NSLog("   AXError: illegalArgument")
            case .invalidUIElement: NSLog("   AXError: invalidUIElement")
            case .invalidUIElementObserver: NSLog("   AXError: invalidUIElementObserver")
            case .cannotComplete: NSLog("   AXError: cannotComplete")
            case .attributeUnsupported: NSLog("   AXError: attributeUnsupported")
            case .actionUnsupported: NSLog("   AXError: actionUnsupported")
            case .notificationUnsupported: NSLog("   AXError: notificationUnsupported")
            case .notImplemented: NSLog("   AXError: notImplemented")
            case .notificationAlreadyRegistered: NSLog("   AXError: notificationAlreadyRegistered")
            case .notificationNotRegistered: NSLog("   AXError: notificationNotRegistered")
            case .apiDisabled: NSLog("   AXError: apiDisabled")
            case .noValue: NSLog("   AXError: noValue")
            case .parameterizedAttributeUnsupported: NSLog("   AXError: parameterizedAttributeUnsupported")
            case .notEnoughPrecision: NSLog("   AXError: notEnoughPrecision")
            @unknown default: NSLog("   AXError: unknown(\(error.rawValue))")
            }
            
            NSLog("⚠️ AXUIElement failed - returning false for CGEvent fallback")
            return false
        }
        
        guard let focused = focusedElement else {
            NSLog("❌ No focused element found")
            return false
        }
        
        let focusedUIElement = focused as! AXUIElement
        
        // Check if the element is a text field/area
        var role: AnyObject?
        AXUIElementCopyAttributeValue(focusedUIElement, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? ""
        NSLog("🔍 Focused element role: \(roleString)")
        
        // Try to insert regardless of role - some apps have custom roles
        // We'll let it fail gracefully if not editable
        
        // Get current text value
        var currentValue: AnyObject?
        if AXUIElementCopyAttributeValue(focusedUIElement, kAXValueAttribute as CFString, &currentValue) == .success,
           let currentText = currentValue as? String {
            
            // Get selected text range (cursor position if length == 0)
            var rangeValue: AnyObject?
            if AXUIElementCopyAttributeValue(focusedUIElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
               rangeValue != nil {
                let axRange = rangeValue as! AXValue
                if AXValueGetType(axRange) == .cfRange {
                
                var cfRange = CFRange()
                AXValueGetValue(axRange, .cfRange, &cfRange)
                
                let insertLocation = cfRange.location
                let selectionLength = cfRange.length
                
                // Build new text: prefix + inserted + suffix (replace selection if any)
                let textLength = currentText.count
                let safeInsertLocation = min(insertLocation, textLength)
                let safeSuffixStart = min(safeInsertLocation + selectionLength, textLength)
                
                let prefix = String(currentText.prefix(safeInsertLocation))
                let suffix = String(currentText.suffix(from: currentText.index(currentText.startIndex, offsetBy: safeSuffixStart)))
                
                let newText = prefix + text + suffix
                
                // Set new value
                let setError = AXUIElementSetAttributeValue(focusedUIElement, kAXValueAttribute as CFString, newText as CFString)
                if setError != .success {
                    NSLog("❌ Failed to set new text value: \(setError.rawValue)")
                    return false
                }
                
                // Update cursor position after insertion
                let newCursorLocation = insertLocation + text.count
                var newRange = CFRange(location: newCursorLocation, length: 0)
                if let newAXRange = AXValueCreate(.cfRange, &newRange) {
                    let rangeError = AXUIElementSetAttributeValue(focusedUIElement, kAXSelectedTextRangeAttribute as CFString, newAXRange)
                    if rangeError != .success {
                        NSLog("⚠️ Failed to set new cursor position: \(rangeError.rawValue)")
                    }
                }
                
                // Force UI refresh for quirky apps (e.g., Cursor)
                NotificationCenter.default.post(name: NSNotification.Name("NSTextDidChangeNotification"), object: nil)
                
                NSLog("✅ Text inserted successfully at cursor position with UI refresh")
                return true
                }
            } else {
                // Fallback: Append if range unavailable
                let newText = currentText + text
                let setError = AXUIElementSetAttributeValue(focusedUIElement, kAXValueAttribute as CFString, newText as CFString)
                if setError != .success {
                    NSLog("❌ Failed to append text: \(setError.rawValue)")
                    return false
                }
                NSLog("✅ Text appended (cursor range unavailable)")
                return true
            }
        } else {
            NSLog("❌ Failed to get current text value")
            return false
        }
        
        return false
    }
    
    @MainActor
    private func insertCharacter(_ char: String) async {
        NSLog("🔢 OLD METHOD: Inserting character: '\(char)'")
        
        // Create keyDown event
        if let keyDownEvent = createKeyEvent(for: char, keyDown: true) {
            keyDownEvent.post(tap: .cgAnnotatedSessionEventTap)
            NSLog("⬇️ KeyDown posted for '\(char)'")
            
            // Small delay between keyDown and keyUp
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            
            // Create keyUp event
            if let keyUpEvent = createKeyEvent(for: char, keyDown: false) {
                keyUpEvent.post(tap: .cgAnnotatedSessionEventTap)
                NSLog("⬆️ KeyUp posted for '\(char)'")
            } else {
                NSLog("❌ Failed to create keyUp event for '\(char)'")
            }
            
            // Delay between characters
            try? await Task.sleep(nanoseconds: 15_000_000) // 15ms
        } else {
            NSLog("❌ Failed to create keyDown event for '\(char)'")
        }
    }
    
    // Helper function to get key codes for common characters
    private func getKeyCode(for char: String) -> CGKeyCode? {
        switch char {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'": return 0x27
        case "k": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".": return 0x2F
        case " ": return 0x31  // Space
        case "\n": return 0x24 // Return
        default: return nil
        }
    }
    
    private func processCommands(_ text: String) -> String {
        var result = text
        
        // Command mappings
        let commands: [(String, String)] = [
            ("new line", "\n"),
            ("new paragraph", "\n\n"),
            ("period", "."),
            ("comma", ","),
            ("question mark", "?"),
            ("exclamation mark", "!"),
            ("colon", ":"),
            ("semicolon", ";"),
            ("open quote", "\""),
            ("close quote", "\""),
            ("open paren", "("),
            ("close paren", ")")
        ]
        
        for (command, replacement) in commands {
            result = result.replacingOccurrences(
                of: command,
                with: replacement,
                options: .caseInsensitive
            )
        }
        
        return result
    }
    
    private func createKeyEvent(for string: String, keyDown: Bool) -> CGEvent? {
        guard let source = CGEventSource(stateID: .hidSystemState) else { 
            NSLog("❌ Failed to create CGEventSource")
            return nil 
        }
        
        // Handle special characters
        if string == "\n" {
            return CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: keyDown)
        }
        
        // For regular characters, use Unicode string
        let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown)
        let utf16 = Array(string.utf16)
        event?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        
        return event
    }
}

