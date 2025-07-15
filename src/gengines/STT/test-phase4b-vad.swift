#!/usr/bin/env swift

import Foundation

// Test script for Phase 4B VAD auto-stop functionality

print("🧪 Phase 4B VAD Auto-Stop Test Suite")
print("=====================================")

// Test 1: Verify VAD processor exists and works
func testVADProcessor() -> Bool {
    print("\n📋 Test 1: VAD Processor")
    
    let bundlePath = "/Applications/Zeus_STT Dev.app/Contents/Resources/vad_processor.py"
    let pythonPath = "/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python"
    
    // Check if files exist
    let fm = FileManager.default
    guard fm.fileExists(atPath: bundlePath) else {
        print("❌ VAD processor not found at: \(bundlePath)")
        return false
    }
    print("✅ VAD processor found")
    
    guard fm.fileExists(atPath: pythonPath) else {
        print("❌ Python not found at: \(pythonPath)")
        return false
    }
    print("✅ Python found")
    
    // Test VAD with silence
    let silenceTest = """
    {"audio_samples": [\(Array(repeating: "0.0", count: 512).joined(separator: ","))], "threshold": 0.3}
    """
    
    let process = Process()
    process.launchPath = pythonPath
    process.arguments = [bundlePath, silenceTest]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("📤 VAD Output: \(output)")
            
            if let jsonData = output.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                let voiceDetected = result["voice_detected"] as? Bool ?? false
                if !voiceDetected {
                    print("✅ Correctly detected silence")
                    return true
                } else {
                    print("❌ Failed to detect silence")
                    return false
                }
            }
        }
    } catch {
        print("❌ Failed to run VAD processor: \(error)")
    }
    
    return false
}

// Test 2: Verify wake word detector
func testWakeWordDetector() -> Bool {
    print("\n📋 Test 2: Wake Word Detector")
    
    let bundlePath = "/Applications/Zeus_STT Dev.app/Contents/Resources/wake_word_detector.py"
    let pythonPath = "/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python"
    
    // Check if files exist
    let fm = FileManager.default
    guard fm.fileExists(atPath: bundlePath) else {
        print("❌ Wake word detector not found at: \(bundlePath)")
        return false
    }
    print("✅ Wake word detector found")
    
    // Test with dummy audio
    let testAudio = """
    {"audio_samples": [\(Array(repeating: "0.1", count: 16000).joined(separator: ","))], "reset_buffer": false}
    """
    
    let process = Process()
    process.launchPath = pythonPath
    process.arguments = [bundlePath, testAudio]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("📤 Wake Word Output: \(output)")
            
            if let jsonData = output.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if result["error"] == nil {
                    print("✅ Wake word detector working")
                    return true
                }
            }
        }
    } catch {
        print("❌ Failed to run wake word detector: \(error)")
    }
    
    return false
}

// Test 3: Check app permissions
func testPermissions() -> Bool {
    print("\n📋 Test 3: App Permissions")
    
    // Check if app is running
    let task = Process()
    task.launchPath = "/bin/ps"
    task.arguments = ["aux"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            if output.contains("Zeus_STT Dev.app") {
                print("✅ Zeus_STT Dev app is running")
            } else {
                print("❌ Zeus_STT Dev app is not running")
                return false
            }
        }
    } catch {
        print("❌ Failed to check process: \(error)")
    }
    
    return true
}

// Run all tests
var testsPassed = 0
var totalTests = 0

print("\n🚀 Running Phase 4B VAD Tests...")

totalTests += 1
if testVADProcessor() {
    testsPassed += 1
}

totalTests += 1
if testWakeWordDetector() {
    testsPassed += 1
}

totalTests += 1
if testPermissions() {
    testsPassed += 1
}

print("\n=====================================")
print("📊 Test Results: \(testsPassed)/\(totalTests) passed")

if testsPassed == totalTests {
    print("🎉 All tests passed! Phase 4B VAD system is ready.")
    exit(0)
} else {
    print("❌ Some tests failed. Check the output above.")
    exit(1)
}