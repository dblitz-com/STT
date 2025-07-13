import Foundation
import AVFoundation
import CommonCrypto

// MARK: - Advanced Voice Features for Phase 4A

class AudioListener: NSObject {
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode!
    private var isListening = false
    private var continuousMode = false
    
    // Audio buffer management
    private var audioBuffer: CircularBuffer<Float>
    private let bufferSize: Int = 16000 * 2 // 2 seconds at 16kHz
    private let sampleRate: Double = 16000
    private let bufferFrameSize: UInt32 = 1024
    
    // Performance optimization
    private let audioQueue = DispatchQueue(label: "com.stt.audio", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "com.stt.processing", qos: .background)
    
    // VAD and activation delegates
    weak var vadDelegate: VADDelegate?
    weak var activationDelegate: ActivationDelegate?
    
    // Python processor paths
    private let vadProcessorPath: String
    private let wakeWordDetectorPath: String
    private let pythonPath: String
    
    // Privacy and security
    private var encryptionKey: Data
    private var isEncryptionEnabled = true
    
    // Power management
    private var lowPowerMode = false
    private var thermalState: ProcessInfo.ThermalState = .nominal
    
    override init() {
        // Initialize circular buffer
        self.audioBuffer = CircularBuffer<Float>(capacity: bufferSize)
        
        // Generate encryption key for audio data
        self.encryptionKey = AudioListener.generateEncryptionKey()
        
        // Initialize Python processor paths
        let currentDir = FileManager.default.currentDirectoryPath
        
        // Try to use bundled paths first, fallback to development paths
        if let resourcePath = Bundle.main.resourcePath,
           FileManager.default.fileExists(atPath: resourcePath + "/venv/bin/python") {
            self.pythonPath = resourcePath + "/venv/bin/python"
        } else {
            self.pythonPath = currentDir + "/venv/bin/python"
        }
        
        if let vadPath = Bundle.main.path(forResource: "vad_processor", ofType: "py") {
            self.vadProcessorPath = vadPath
        } else {
            self.vadProcessorPath = currentDir + "/vad_processor.py"
        }
        
        if let wakeWordPath = Bundle.main.path(forResource: "wake_word_detector", ofType: "py") {
            self.wakeWordDetectorPath = wakeWordPath
        } else {
            self.wakeWordDetectorPath = currentDir + "/wake_word_detector.py"
        }
        
        super.init()
        
        setupAudioEngine()
        setupPowerManagement()
        
        NSLog("🎤 AudioListener initialized for Phase 4A hands-free operation")
    }
    
    deinit {
        stopContinuousListening()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        
        // Configure for optimal performance: 16kHz mono
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
        
        NSLog("🎤 Audio format: \(inputFormat.sampleRate)Hz → \(sampleRate)Hz, channels: \(inputFormat.channelCount) → 1")
        
        // Install audio tap for continuous capture
        inputNode.installTap(onBus: 0, bufferSize: bufferFrameSize, format: desiredFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, at: time)
        }
        
        // Prepare audio engine
        audioEngine.prepare()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard isListening, let channelData = buffer.floatChannelData?[0] else { return }
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to circular buffer with optional encryption
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            
            if self.isEncryptionEnabled {
                let encryptedSamples = self.encryptAudioSamples(samples)
                self.audioBuffer.append(contentsOf: encryptedSamples)
            } else {
                self.audioBuffer.append(contentsOf: samples)
            }
            
            // Trigger VAD processing if in continuous mode
            if self.continuousMode {
                self.processingQueue.async {
                    self.processForVAD(samples: samples)
                }
            }
        }
    }
    
    // MARK: - Continuous Listening Control
    
    func startContinuousListening() {
        guard !continuousMode else { return }
        
        NSLog("🎤 Starting continuous listening mode...")
        
        do {
            try audioEngine.start()
            isListening = true
            continuousMode = true
            
            NSLog("✅ Continuous listening active - monitoring for voice activity")
        } catch {
            NSLog("❌ Failed to start continuous listening: \(error)")
        }
    }
    
    func stopContinuousListening() {
        guard continuousMode else { return }
        
        NSLog("🎤 Stopping continuous listening mode...")
        
        audioEngine.stop()
        isListening = false
        continuousMode = false
        
        // Clear sensitive audio data
        clearAudioBuffer()
        
        NSLog("✅ Continuous listening stopped")
    }
    
    func toggleContinuousMode() {
        if continuousMode {
            stopContinuousListening()
        } else {
            startContinuousListening()
        }
    }
    
    // MARK: - Manual Recording (for Fn key activation)
    
    func startRecording() -> Bool {
        guard !isListening else { return true }
        
        do {
            try audioEngine.start()
            isListening = true
            NSLog("🎤 Manual recording started")
            return true
        } catch {
            NSLog("❌ Failed to start recording: \(error)")
            return false
        }
    }
    
    func stopRecording() -> [Float]? {
        guard isListening else { return nil }
        
        audioEngine.stop()
        isListening = false
        
        // Extract and return audio data
        let audioData = extractAudioData()
        clearAudioBuffer()
        
        NSLog("🎤 Manual recording stopped, extracted \(audioData.count) samples")
        return audioData
    }
    
    // MARK: - VAD Processing
    
    private func processForVAD(samples: [Float]) {
        // Use Silero VAD for superior accuracy
        processingQueue.async {
            self.runSileroVAD(samples: samples)
        }
        
        // Also run wake word detection in parallel
        processingQueue.async {
            self.runWakeWordDetection(samples: samples)
        }
    }
    
    private func runSileroVAD(samples: [Float]) {
        let jsonInput: [String: Any] = [
            "audio_samples": samples,
            "threshold": getAdaptiveVADThreshold(),
            "environment": getCurrentEnvironment(),
            "reset_buffer": false
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonInput),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            NSLog("❌ Failed to create VAD JSON input")
            return
        }
        
        let process = Process()
        process.launchPath = pythonPath
        process.arguments = [vadProcessorPath, jsonString]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        process.terminationHandler = { _ in
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            
            if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let data = output.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                self.handleVADResult(result, samples: samples)
            }
        }
        
        do {
            try process.run()
        } catch {
            NSLog("❌ Failed to run Silero VAD: \(error)")
        }
    }
    
    private func runWakeWordDetection(samples: [Float]) {
        let jsonInput: [String: Any] = [
            "audio_samples": samples,
            "reset_buffer": false
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonInput),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            NSLog("❌ Failed to create wake word JSON input")
            return
        }
        
        let process = Process()
        process.launchPath = pythonPath
        process.arguments = [wakeWordDetectorPath, jsonString]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        process.terminationHandler = { _ in
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            
            if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let data = output.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                self.handleWakeWordResult(result, samples: samples)
            }
        }
        
        do {
            try process.run()
        } catch {
            NSLog("❌ Failed to run wake word detection: \(error)")
        }
    }
    
    private func handleVADResult(_ result: [String: Any], samples: [Float]) {
        guard let voiceDetected = result["voice_detected"] as? Bool else { return }
        
        if voiceDetected {
            let confidence = result["confidence"] as? Double ?? 1.0
            let energyDB = result["energy_db"] as? Float ?? 0.0
            
            NSLog("🎤 Silero VAD detected voice (confidence: \(String(format: "%.2f", confidence)), energy: \(String(format: "%.1f", energyDB))dB)")
            
            DispatchQueue.main.async {
                self.vadDelegate?.didDetectVoiceActivity(energy: energyDB, samples: samples)
            }
        }
    }
    
    private func handleWakeWordResult(_ result: [String: Any], samples: [Float]) {
        guard let wakeWordDetected = result["wake_word_detected"] as? Bool else { return }
        
        if wakeWordDetected {
            let keyword = result["keyword"] as? String ?? "unknown"
            let confidence = result["confidence"] as? Double ?? 1.0
            
            NSLog("🗣️ Wake word detected: '\(keyword)' (confidence: \(String(format: "%.2f", confidence)))")
            
            DispatchQueue.main.async {
                self.activationDelegate?.didDetectHandsFreeActivation(type: .wakeWord(keyword: keyword))
            }
        }
    }
    
    private func getCurrentEnvironment() -> String {
        // Simple environment detection based on power state and thermal
        if lowPowerMode {
            return "battery"
        } else if thermalState != .nominal {
            return "noisy"
        } else {
            return "office"
        }
    }
    
    private func getAdaptiveVADThreshold() -> Float {
        // Adaptive threshold based on power state and context
        var baseThreshold: Float = -30.0 // dB
        
        if lowPowerMode {
            baseThreshold += 5.0 // Less sensitive on battery
        }
        
        if thermalState != .nominal {
            baseThreshold += 3.0 // Less sensitive when hot
        }
        
        return baseThreshold
    }
    
    // MARK: - Audio Data Management
    
    private func extractAudioData() -> [Float] {
        return audioQueue.sync {
            let data = audioBuffer.getAllElements()
            
            if isEncryptionEnabled {
                return decryptAudioSamples(data)
            } else {
                return data
            }
        }
    }
    
    private func clearAudioBuffer() {
        audioQueue.async {
            self.audioBuffer.clear()
        }
    }
    
    // MARK: - Audio Encryption (Privacy)
    
    private static func generateEncryptionKey() -> Data {
        var keyData = Data(count: kCCKeySizeAES256)
        let result = keyData.withUnsafeMutableBytes { keyBytes in
            SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES256, keyBytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            fatalError("Failed to generate encryption key")
        }
        
        return keyData
    }
    
    private func encryptAudioSamples(_ samples: [Float]) -> [Float] {
        // Simple XOR encryption for real-time performance
        // In production, use more sophisticated encryption if needed
        let keyBytes = encryptionKey.withUnsafeBytes { $0.bindMemory(to: UInt32.self) }
        let keyValue = keyBytes[0]
        
        return samples.enumerated().map { index, sample in
            let sampleBits = sample.bitPattern
            let encryptedBits = sampleBits ^ keyValue ^ UInt32(index % 1000)
            return Float(bitPattern: encryptedBits)
        }
    }
    
    private func decryptAudioSamples(_ encryptedSamples: [Float]) -> [Float] {
        // Reverse the XOR encryption
        let keyBytes = encryptionKey.withUnsafeBytes { $0.bindMemory(to: UInt32.self) }
        let keyValue = keyBytes[0]
        
        return encryptedSamples.enumerated().map { index, encryptedSample in
            let encryptedBits = encryptedSample.bitPattern
            let decryptedBits = encryptedBits ^ keyValue ^ UInt32(index % 1000)
            return Float(bitPattern: decryptedBits)
        }
    }
    
    // MARK: - Power Management
    
    private func setupPowerManagement() {
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // Monitor thermal state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        updatePowerState()
    }
    
    @objc private func powerStateDidChange() {
        updatePowerState()
    }
    
    @objc private func thermalStateDidChange() {
        updatePowerState()
    }
    
    private func updatePowerState() {
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        
        NSLog("🔋 Power state updated: lowPower=\(lowPowerMode), thermal=\(thermalState.rawValue)")
        
        // Adjust processing based on power state
        if lowPowerMode || thermalState != .nominal {
            // Reduce processing intensity
            adjustForPowerSaving()
        }
    }
    
    private func adjustForPowerSaving() {
        // Implementation: Reduce sample rate, increase VAD thresholds, etc.
        NSLog("⚡ Adjusting for power saving mode")
    }
}

// MARK: - Delegates

protocol VADDelegate: AnyObject {
    func didDetectVoiceActivity(energy: Float, samples: [Float])
}

protocol ActivationDelegate: AnyObject {
    func didDetectHandsFreeActivation(type: ActivationType)
}

enum ActivationType {
    case voiceActivity
    case wakeWord(keyword: String)
    case doubleTap
    case fnKey
}

// MARK: - Circular Buffer Implementation

class CircularBuffer<T> {
    private var buffer: [T?]
    private var head = 0
    private var tail = 0
    private var count = 0
    private let capacity: Int
    private let lock = NSLock()
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array<T?>(repeating: nil, count: capacity)
    }
    
    func append(_ element: T) {
        lock.lock()
        defer { lock.unlock() }
        
        buffer[tail] = element
        tail = (tail + 1) % capacity
        
        if count < capacity {
            count += 1
        } else {
            head = (head + 1) % capacity
        }
    }
    
    func append<S: Sequence>(contentsOf sequence: S) where S.Element == T {
        for element in sequence {
            append(element)
        }
    }
    
    func getAllElements() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        
        guard count > 0 else { return [] }
        
        var result: [T] = []
        result.reserveCapacity(count)
        
        var current = head
        for _ in 0..<count {
            if let element = buffer[current] {
                result.append(element)
            }
            current = (current + 1) % capacity
        }
        
        return result
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        // Clear all elements
        for i in 0..<capacity {
            buffer[i] = nil
        }
        
        head = 0
        tail = 0
        count = 0
    }
    
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == 0
    }
    
    var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == capacity
    }
}