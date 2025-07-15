#!/usr/bin/env swift

import Foundation

print("🧪 Testing Zeus_STT Dev logging system")
print("="*40 + "\n")

// Force the app to do something that should definitely log
print("1. Toggling hands-free mode to force logs...")

// Use AppleScript to click menu items
let toggleScript = """
tell application "System Events"
    tell process "Zeus_STT Dev"
        click menu bar item 1 of menu bar 2
        delay 0.5
        click menu item "Toggle Hands-Free Mode" of menu 1 of menu bar item 1 of menu bar 2
    end tell
end tell
"""

let task = Process()
task.launchPath = "/usr/bin/osascript"
task.arguments = ["-e", toggleScript]

do {
    try task.run()
    task.waitUntilExit()
    
    if task.terminationStatus == 0 {
        print("✅ Toggled hands-free mode")
    } else {
        print("❌ Failed to toggle (may need accessibility permissions for this test)")
    }
} catch {
    print("❌ Error: \(error)")
}

// Wait a bit for logs to appear
Thread.sleep(forTimeInterval: 2)

// Now check for any Zeus_STT logs in the last minute
print("\n2. Checking for ANY Zeus_STT logs...")

let logTask = Process()
logTask.launchPath = "/usr/bin/log"
logTask.arguments = ["show", "--last", "1m"]

let pipe = Pipe()
logTask.standardOutput = pipe

do {
    try logTask.run()
    logTask.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        let zeusLogs = output.split(separator: "\n").filter { 
            $0.contains("STTDictate") || $0.contains("Zeus_STT") 
        }
        
        if zeusLogs.isEmpty {
            print("❌ NO Zeus_STT logs found at all!")
            print("\n🔍 This suggests:")
            print("   - NSLog might be compiled out in DEBUG builds")
            print("   - Logs might be going somewhere else")
            print("   - The app might not be running the expected code")
            
            print("\n💡 Try this:")
            print("   1. Open Console.app")
            print("   2. In the search box, type: SUBSYSTEM:com.zeus.stt")
            print("   3. Also check Action menu > Include Info/Debug Messages")
        } else {
            print("✅ Found \(zeusLogs.count) Zeus_STT log entries!")
            print("\nRecent logs:")
            for (index, log) in zeusLogs.suffix(5).enumerated() {
                print("\(index + 1). \(log)")
            }
        }
    }
} catch {
    print("❌ Failed to check logs: \(error)")
}

print("\n3. Alternative: Check if app writes to stderr...")
print("Run this in another terminal:")
print("lldb -p $(pgrep STTDictate) -o 'expr (void)NSLog(@\"TEST LOG FROM LLDB\")'")
print("\nThen check Console.app again for 'TEST LOG FROM LLDB'")