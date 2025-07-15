#!/usr/bin/env swift

import Foundation
import AVFoundation

// Test script for Phase 4B VAD Auto-Stop functionality

print("🧪 Phase 4B VAD Auto-Stop Test")
print("==============================\n")

// Test configuration
let testDuration: TimeInterval = 30.0 // Maximum test duration
let logCheckInterval: TimeInterval = 1.0

// Expected log patterns for successful auto-stop
let expectedPatterns = [
    "Phase 4B: Wake word 'hey_jarvis' detected",
    "Phase 4B: State transition: idle → wakeWordDetected",
    "Phase 4B: Starting hands-free recording",
    "Phase 4B: State transition: wakeWordDetected → recording",
    "Phase 4B: Calling VAD for auto-stop detection",
    "Phase 4B VAD: Processing",
    "Phase 4B VAD: Speech detected",
    "Phase 4B VAD: Silence chunk",
    "Phase 4B VAD: Extended silence detected - auto-stopping recording",
    "Phase 4B: State transition: recording → processing"
]

var foundPatterns: Set<String> = []
var testPassed = false

// Start monitoring logs
print("📋 Starting test sequence...\n")

// Create a process to monitor logs
let logProcess = Process()
logProcess.launchPath = "/usr/bin/log"
logProcess.arguments = ["stream", "--process", "STTDictate", "--level", "debug"]

let pipe = Pipe()
logProcess.standardOutput = pipe

// Start log monitoring
do {
    try logProcess.run()
    print("✅ Log monitoring started")
    print("🎤 Please say 'Hey Jarvis' followed by a short message")
    print("⏱️  Then wait for auto-stop (should happen within 1 second of silence)\n")
} catch {
    print("❌ Failed to start log monitoring: \(error)")
    exit(1)
}

// Monitor logs for expected patterns
let startTime = Date()
var lastActivityTime = Date()

DispatchQueue.global().async {
    let fileHandle = pipe.fileHandleForReading
    
    while logProcess.isRunning {
        let data = fileHandle.availableData
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            let lines = output.split(separator: "\n")
            
            for line in lines {
                let lineStr = String(line)
                
                // Check for expected patterns
                for pattern in expectedPatterns {
                    if lineStr.contains(pattern) && !foundPatterns.contains(pattern) {
                        foundPatterns.insert(pattern)
                        lastActivityTime = Date()
                        print("✅ Found: \(pattern)")
                        
                        // Check if we've found all critical patterns
                        let criticalPatterns = [
                            "Phase 4B: Wake word 'hey_jarvis' detected",
                            "Phase 4B: Starting hands-free recording",
                            "Phase 4B VAD: Extended silence detected - auto-stopping recording",
                            "Phase 4B: State transition: recording → processing"
                        ]
                        
                        let foundCritical = criticalPatterns.filter { foundPatterns.contains($0) }
                        if foundCritical.count == criticalPatterns.count {
                            testPassed = true
                            print("\n🎉 All critical patterns found! Auto-stop is working!")
                            logProcess.terminate()
                            return
                        }
                    }
                }
                
                // Also print relevant logs for debugging
                if lineStr.contains("Phase 4B") || lineStr.contains("VAD") || 
                   lineStr.contains("wake word") || lineStr.contains("handsFreeState") {
                    print("📝 \(lineStr)")
                }
            }
        }
    }
}

// Wait for test completion or timeout
while logProcess.isRunning && Date().timeIntervalSince(startTime) < testDuration {
    Thread.sleep(forTimeInterval: logCheckInterval)
    
    // Check for inactivity timeout
    if Date().timeIntervalSince(lastActivityTime) > 10.0 && !foundPatterns.isEmpty {
        print("\n⏱️  No activity for 10 seconds, ending test...")
        break
    }
}

logProcess.terminate()

// Print test results
print("\n" + String(repeating: "=", count: 50))
print("📊 Test Results:")
print(String(repeating: "=", count: 50))

print("\n📋 Found patterns (\(foundPatterns.count)/\(expectedPatterns.count)):")
for pattern in expectedPatterns {
    let status = foundPatterns.contains(pattern) ? "✅" : "❌"
    print("\(status) \(pattern)")
}

print("\n" + String(repeating: "=", count: 50))

if testPassed {
    print("✅ TEST PASSED: VAD auto-stop is working correctly!")
    print("   - Wake word detection triggered recording")
    print("   - VAD detected speech and silence")
    print("   - Recording auto-stopped after extended silence")
    exit(0)
} else {
    print("❌ TEST FAILED: VAD auto-stop not working properly")
    
    // Provide debugging hints
    print("\n🔍 Debugging hints:")
    
    if !foundPatterns.contains("Phase 4B: Wake word 'hey_jarvis' detected") {
        print("   - Wake word not detected. Try saying 'Hey Jarvis' more clearly")
        print("   - Check microphone permissions")
    }
    
    if foundPatterns.contains("Phase 4B: Starting hands-free recording") &&
       !foundPatterns.contains("Phase 4B VAD: Extended silence detected - auto-stopping recording") {
        print("   - Recording started but didn't auto-stop")
        print("   - VAD may not be detecting silence properly")
        print("   - Try speaking then pausing for 1-2 seconds")
    }
    
    if foundPatterns.isEmpty {
        print("   - No Phase 4B activity detected")
        print("   - Check if Zeus_STT Dev app is running")
        print("   - Verify hands-free mode is enabled")
    }
    
    exit(1)
}