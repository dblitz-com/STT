#!/usr/bin/env swift

import Foundation

print("🔍 Checking Zeus_STT Dev app startup and logging...")
print("="*50 + "\n")

// Check if app is running
let task = Process()
task.launchPath = "/bin/ps"
task.arguments = ["aux"]

let pipe = Pipe()
task.standardOutput = pipe

try! task.run()
task.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8) ?? ""

var appPID: String?
for line in output.split(separator: "\n") {
    if line.contains("Zeus_STT Dev.app") && line.contains("STTDictate") {
        let parts = line.split(separator: " ").filter { !$0.isEmpty }
        if parts.count > 1 {
            appPID = String(parts[1])
            print("✅ App is running with PID: \(appPID)")
            break
        }
    }
}

if appPID == nil {
    print("❌ App not running!")
    exit(1)
}

// Check if app is actually producing output
print("\n📋 Checking app output streams...")

// Try to sample the app to see what it's doing
if let pid = appPID {
    let sampleTask = Process()
    sampleTask.launchPath = "/usr/bin/sample"
    sampleTask.arguments = [pid, "1"]
    
    let samplePipe = Pipe()
    sampleTask.standardOutput = samplePipe
    sampleTask.standardError = samplePipe
    
    do {
        try sampleTask.run()
        sampleTask.waitUntilExit()
        
        let sampleData = samplePipe.fileHandleForReading.readDataToEndOfFile()
        if let sampleOutput = String(data: sampleData, encoding: .utf8) {
            if sampleOutput.contains("AVAudioEngine") || sampleOutput.contains("WhisperKit") {
                print("✅ App appears to be running audio/whisper code")
            }
            
            // Look for logging-related info
            if sampleOutput.contains("NSLog") || sampleOutput.contains("os_log") {
                print("✅ Logging functions found in stack")
            }
        }
    } catch {
        print("⚠️  Could not sample app: \(error)")
    }
}

// Test if we can see stderr output
print("\n📋 Testing log visibility...")
print("Run this command in another terminal:")
print("sudo dtruss -p \(appPID!) 2>&1 | grep -E 'write|NSLog'")
print("\nOr try:")
print("log stream --process \(appPID!) --level debug")

print("\n🔍 Potential issues:")
print("1. Logs might be going to stderr instead of system log")
print("2. App might be compiled without debug symbols")
print("3. Console.app might need 'Include Debug Messages' enabled")
print("   (View menu > Include Debug Messages)")

print("\n💡 Quick test: Force a log by toggling hands-free mode")
print("   Click the menu bar icon > Toggle Hands-Free Mode")
print("   This should log: '🔄 Toggling hands-free mode...'")