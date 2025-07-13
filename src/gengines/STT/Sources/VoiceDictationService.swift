import Foundation
import AVFoundation
import WhisperKit
import CoreGraphics
import Carbon.HIToolbox
import AppKit
import ApplicationServices
import IOKit.hid  // For low-level HID monitoring
import OSLog

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
    
    init() {
        checkAccessibilityPermissions()
        setupWhisperKit()
        // DON'T setup hotkey in init - wait for app launch
    }
    
    // NEW: Call this AFTER applicationDidFinishLaunching
    func initializeAfterLaunch() {
        NSLog("🚀 Initializing STT after app launch...")
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
    
    private func checkAccessibilityPermissions() {
        // Force permission prompt to bypass caching bug - from Wispr Flow approach
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
        
        // Check Accessibility permission (but don't rely on cached result)
        let accessEnabled = AXIsProcessTrusted()
        NSLog("🔐 Accessibility permissions check: \(accessEnabled ? "GRANTED" : "DENIED (may be cached)")")
        
        // Check if running on macOS 14+ (Sonoma/Sequoia) - Input Monitoring also required
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let needsInputMonitoring = osVersion.majorVersion >= 14
        
        if !accessEnabled {
            NSLog("❌ CRITICAL: Accessibility permissions DENIED")
            NSLog("⚠️  This prevents AXUIElement text insertion - causing AXError: apiDisabled (-25211)")
            NSLog("")
            NSLog("🔧 REQUIRED FIXES:")
            NSLog("1️⃣  Open System Settings > Privacy & Security > Accessibility")
            NSLog("2️⃣  Find 'STT Dictate' in list and toggle ON")
            NSLog("3️⃣  If not in list, click '+' and add: /Applications/STT Dictate.app")
            
            if needsInputMonitoring {
                NSLog("4️⃣  ALSO enable Input Monitoring: System Settings > Privacy & Security > Input Monitoring")
                NSLog("5️⃣  Find 'STT Dictate' and toggle ON")
            }
            
            NSLog("")
            NSLog("🚨 Without these permissions, text insertion falls back to slow CGEvent method")
            
            // Check if we've already prompted before
            let hasPromptedKey = "STTDictate.HasPromptedForAccessibility"
            let hasPrompted = UserDefaults.standard.bool(forKey: hasPromptedKey)
            
            if !hasPrompted {
                // Only prompt once ever - this opens System Settings
                NSLog("📋 First time run - opening System Settings for you...")
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                _ = AXIsProcessTrustedWithOptions(options)
                
                // Mark that we've prompted
                UserDefaults.standard.set(true, forKey: hasPromptedKey)
                UserDefaults.standard.synchronize()
            } else {
                NSLog("⚠️ Already prompted - please manually enable permissions in System Settings")
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
                await insertText(trimmedText)
            } else {
                NSLog("⚠️ Text is empty after trimming whitespace")
            }
        } else {
            NSLog("❌ No text in first transcription result")
        }
    }
    
    @MainActor
    private func insertText(_ text: String) async {
        let logger = Logger(subsystem: "com.stt.dictate", category: "accessibility")
        
        let processedText = processCommands(text)
        NSLog("🔧 NEW COMPREHENSIVE insertText() called with: '\(processedText)'")
        NSLog("⌨️ Inserting text: '\(processedText)'")
        
        guard !processedText.isEmpty else {
            logger.info("No text to insert")
            return
        }

        // Check if Accessibility is trusted
        let isTrusted = AXIsProcessTrusted()
        NSLog("🔐 AXIsProcessTrusted() = \(isTrusted)")
        if !isTrusted {
            logger.error("Accessibility API not trusted; prompt user to grant in System Settings")
            NSLog("❌ Accessibility not trusted - falling back to clipboard")
            fallbackToClipboard(processedText)
            return
        }

        // Get frontmost app PID (safer than system-wide for focused element)
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let pid = pid_t(exactly: frontApp.processIdentifier) else {
            logger.error("No frontmost application found")
            NSLog("❌ No frontmost application - falling back to clipboard")
            fallbackToClipboard(processedText)
            return
        }
        
        NSLog("🔍 Frontmost app: \(frontApp.localizedName ?? "Unknown") (PID: \(frontApp.processIdentifier))")

        let appElement = AXUIElementCreateApplication(pid)

        // Force initialization: Read app role (workaround for hierarchy init issues)
        var role: CFTypeRef?
        let initError = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &role)
        if initError != .success {
            logger.debug("App role init failed: \(initError.rawValue) – continuing anyway")
        } else if let roleStr = role as? String {
            logger.debug("App role: \(roleStr)")
            NSLog("🔍 App role: \(roleStr)")
        }

        // Retry loop for focused element (handle timing/messaging failures)
        var focusedElement: AXUIElement?
        for attempt in 1...3 {
            var focused: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
            if error == .success {
                let elem = focused as! AXUIElement
                focusedElement = elem
                logger.info("Got focused element on attempt \(attempt)")
                NSLog("✅ Got focused element on attempt \(attempt)")
                break
            } else {
                logger.warning("Focused element copy failed on attempt \(attempt): \(error.rawValue)")
                NSLog("⚠️ Attempt \(attempt) failed: error \(error.rawValue)")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s delay
                }
            }
        }

        guard let startingElement = focusedElement else {
            logger.error("Exhausted retries; no focused element")
            NSLog("❌ Exhausted retries - falling back to clipboard")
            fallbackToClipboard(processedText)
            return
        }

        // Hierarchy traversal and insertion
        var currentElement: AXUIElement? = startingElement
        while let element = currentElement {
            // Prioritize insertion at cursor via kAXSelectedTextAttribute
            var isSettable: DarwinBoolean = false
            var error = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable)
            if error == .success && isSettable.boolValue {
                error = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, processedText as CFString)
                if error == .success {
                    logger.info("Inserted text at cursor using kAXSelectedTextAttribute")
                    NSLog("✅ Direct insertion successful (kAXSelectedTextAttribute)")
                    return
                } else {
                    logger.error("Failed to set kAXSelectedTextAttribute: \(error.rawValue)")
                }
            } else if error != .success {
                logger.debug("kAXSelectedTextAttribute not available or check failed: \(error.rawValue)")
            }

            // Fallback: Append to end via kAXValueAttribute
            var isValueSettable: DarwinBoolean = false
            error = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isValueSettable)
            if error == .success && isValueSettable.boolValue {
                var value: CFTypeRef?
                error = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
                if error == .success, let currentText = value as? String {
                    let newText = currentText + processedText
                    error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFString)
                    if error == .success {
                        logger.info("Appended text using kAXValueAttribute")
                        NSLog("✅ Direct insertion successful (kAXValueAttribute)")
                        return
                    } else {
                        logger.error("Failed to set kAXValueAttribute: \(error.rawValue)")
                    }
                } else {
                    logger.debug("Failed to get current kAXValueAttribute: \(error.rawValue)")
                }
            } else if error != .success {
                logger.debug("kAXValueAttribute not available or check failed: \(error.rawValue)")
            }

            // Traverse to parent
            var parent: CFTypeRef?
            error = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent)
            if error != .success || parent == nil {
                logger.debug("No parent element available: \(error.rawValue)")
                break
            }
            currentElement = parent as! AXUIElement

            // Stop at window/app level
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            if let roleStr = role as? String, [kAXWindowRole, kAXApplicationRole].contains(roleStr) {
                logger.debug("Reached window/application level; stopping traversal")
                break
            }
        }

        logger.error("Exhausted hierarchy; no suitable element for direct insertion")
        NSLog("⚠️ NEW CODE: Hierarchy exhausted - falling back to clipboard")
        fallbackToClipboard(processedText)
    }
    
    private func fallbackToClipboard(_ text: String) {
        let logger = Logger(subsystem: "com.stt.dictate", category: "accessibility")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Show notification to user
        AppDelegate.shared?.showNotification(
            title: "STT Dictate", 
            message: "Text copied to clipboard: \"\(text)\". Press Cmd+V to paste."
        )
        
        logger.info("Fell back to clipboard; user must paste manually")
        NSLog("✅ Clipboard fallback completed - text ready to paste")
    }
    
    // DISABLED: This method caused system freezes due to CGEvent posting
    // @MainActor
    // private func insertCharacter(_ char: String) async {
    //     NSLog("🚨 DANGEROUS METHOD: This causes system freezes - DO NOT USE")
    //     // This method posted CGEvents using .cghidEventTap which blocks system event pipeline
    //     // Replaced with safe clipboard insertion above
    // }
    
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

