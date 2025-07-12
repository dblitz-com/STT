import Foundation
import AVFoundation
import WhisperKit
import CoreGraphics
import Carbon.HIToolbox
import AppKit
import ApplicationServices

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
    
    // Configuration
    private let sampleRate: Double = 16000
    private let chunkDuration: Double = 0.5 // 500ms chunks
    private let modelName = "openai_whisper-large-v3-turbo"
    
    // Wispr Flow approach: Debug mode for testing
    private let debugMode = false // Set to false for production
    
    init() {
        checkAccessibilityPermissions()
        setupWhisperKit()
        // DON'T setup hotkey in init - wait for app launch
    }
    
    // NEW: Call this AFTER applicationDidFinishLaunching
    func initializeAfterLaunch() {
        NSLog("🚀 Initializing STT after app launch...")
        checkSystemSettings()
        // Temporarily disable hidutil remapping - might be interfering
        // applyHidutilRemapping()
        setupHotkey()
    }
    
    private func applyHidutilRemapping() {
        print("🔧 Applying hidutil Fn key remapping...")
        
        let task = Process()
        task.launchPath = "/usr/bin/hidutil"
        task.arguments = ["property", "--set", "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x700000065,\"HIDKeyboardModifierMappingDst\":0x7000000FF}]}"]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                print("✅ hidutil remapping applied successfully")
            } else {
                print("⚠️ hidutil remapping may have failed")
            }
        } catch {
            print("❌ Failed to run hidutil: \(error)")
        }
    }
    
    deinit {
        disableFnTap()
    }
    
    private func setupWhisperKit() {
        Task {
            do {
                print("📥 Loading WhisperKit model...")
                // Try to load from local WhisperKit directory first
                let modelPath = "WhisperKit/Models/whisperkit-coreml/\(modelName)"
                if FileManager.default.fileExists(atPath: modelPath) {
                    print("📁 Loading model from: \(modelPath)")
                    whisperKit = try await WhisperKit(modelFolder: modelPath)
                } else {
                    // Fall back to default model loading
                    print("📁 Loading default model")
                    whisperKit = try await WhisperKit()
                }
                print("✅ WhisperKit loaded successfully")
                print("🎯 Ready! Press Cmd+Space to start/stop dictation")
            } catch {
                print("❌ Failed to load WhisperKit: \(error)")
            }
        }
    }
    
    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        NSLog("🔐 Accessibility permissions check: \(accessEnabled ? "GRANTED" : "DENIED")")
        
        if !accessEnabled {
            NSLog("⚠️  Accessibility permissions required for Fn key override.")
            NSLog("Please enable Accessibility for 'STT Dictate' in System Settings.")
            NSLog("Go to: System Settings > Privacy & Security > Accessibility")
            
            // Show notification
            DispatchQueue.main.async {
                AppDelegate.shared?.showNotification(
                    title: "Permission Required",
                    message: "Please grant Accessibility permission to STT Dictate in System Settings"
                )
            }
        } else {
            NSLog("✅ Accessibility permissions granted")
        }
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
        
        // Wispr Flow approach: Use listen-only in debug mode for testing
        let tapOptions: CGEventTapOptions = debugMode ? .listenOnly : .defaultTap
        NSLog("📋 Event tap options: \(tapOptions == .defaultTap ? "DEFAULT (intercept)" : "LISTEN ONLY")")
        
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
                
                // Handle flagsChanged events (modifier keys like Fn)
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
                        // Only consume event if not in debug mode
                        if !service.debugMode {
                            NSLog("🚫 Consuming Fn event to prevent emoji picker")
                            return nil  // Consume event to prevent emoji picker
                        }
                    }
                    
                    // Update state on release or other changes
                    service.lastFlags = currentFlags
                }
                
                // Handle keyDown events (backup for Fn key as regular key)
                if type == .keyDown || type == .keyUp {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    NSLog("   KeyCode: \(keyCode)")
                    
                    // Check for original Fn key (63) OR hidutil remapped key
                    // hidutil mapped Fn to key code 30064771327, but we need the actual virtual key code
                    if (keyCode == 63 || keyCode == 255) && type == .keyDown { // 255 is common for remapped keys
                        NSLog("🔑 Fn key pressed (keyDown) - toggling dictation")
                        service.toggleRecording()
                        // Only consume event if not in debug mode
                        if !service.debugMode {
                            NSLog("🚫 Consuming Fn key event")
                            return nil  // Consume event to prevent emoji picker
                        }
                    }
                }
                
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
                AppDelegate.shared?.showNotification(
                    title: "Input Monitoring Required",
                    message: "Please grant Input Monitoring permission to STT Dictate in System Settings"
                )
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
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Request microphone permission first
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if granted {
                    NSLog("🎤 Microphone permission granted, starting recording...")
                    self.actuallyStartRecording()
                } else {
                    NSLog("❌ Microphone permission denied")
                    AppDelegate.shared?.showNotification(
                        title: "Microphone Permission Denied",
                        message: "Please grant microphone access in System Settings"
                    )
                }
            }
        }
    }
    
    private func actuallyStartRecording() {
        NSLog("🎤 Actually starting recording...")
        isRecording = true
        
        // Update visual feedback
        AppDelegate.shared?.updateRecordingState(isRecording: true)
        bufferQueue.sync {
            audioBuffer.removeAll()
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            startTranscriptionTask()
        } catch {
            print("Failed to start audio engine: \(error)")
            stopRecording()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        NSLog("🛑 Stopping recording...")
        isRecording = false
        
        // Update visual feedback
        AppDelegate.shared?.updateRecordingState(isRecording: false)
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }
        
        bufferQueue.sync {
            audioBuffer.append(contentsOf: channelDataValueArray)
        }
    }
    
    private func startTranscriptionTask() {
        recognitionTask = Task {
            while isRecording {
                await processChunk()
                try? await Task.sleep(nanoseconds: UInt64(chunkDuration * 1_000_000_000))
            }
        }
    }
    
    private func processChunk() async {
        let chunk = bufferQueue.sync {
            let data = audioBuffer
            audioBuffer.removeAll()
            return data
        }
        
        guard !chunk.isEmpty, let whisperKit = whisperKit else { return }
        
        do {
            // Transcribe the audio chunk
            let transcription = try await whisperKit.transcribe(
                audioArray: chunk,
                decodeOptions: DecodingOptions(
                    task: .transcribe,
                    language: "en",
                    usePrefillPrompt: false,
                    skipSpecialTokens: true,
                    withoutTimestamps: true
                )
            )
            
            if let text = transcription.first?.text, !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                await insertText(text)
            }
        } catch {
            print("Transcription error: \(error)")
        }
    }
    
    @MainActor
    private func insertText(_ text: String) async {
        // Process commands
        let processedText = processCommands(text)
        
        // Insert text character by character
        for char in processedText {
            if let event = createKeyEvent(for: String(char)) {
                event.post(tap: .cghidEventTap)
                // Small delay to ensure proper key registration
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
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
    
    private func createKeyEvent(for string: String) -> CGEvent? {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return nil }
        
        // Handle special characters
        if string == "\n" {
            return CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: true)
        }
        
        // For regular characters, use Unicode string
        let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let utf16 = Array(string.utf16)
        event?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        
        return event
    }
}

