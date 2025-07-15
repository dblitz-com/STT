#!/usr/bin/env python3
"""
Test end-to-end integration of AI features in Zeus_STT
"""

import subprocess
import time
import json

print("🔌 Testing Zeus_STT AI Integration")
print("==================================\n")

# Kill any existing Zeus_STT
subprocess.run(["pkill", "-f", "Zeus_STT Dev"], capture_output=True)
time.sleep(1)

# Launch Zeus_STT in background
print("🚀 Launching Zeus_STT Dev...")
app_process = subprocess.Popen([
    "/Applications/Zeus_STT Dev.app/Contents/MacOS/STTDictate"
], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

time.sleep(3)

# Check if app started
ps_result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
if 'Zeus_STT Dev' in ps_result.stdout:
    print("✅ App is running")
    
    # Get PID for log monitoring
    for line in ps_result.stdout.split('\n'):
        if 'Zeus_STT Dev' in line and 'STTDictate' in line:
            parts = line.split()
            if len(parts) > 1:
                pid = parts[1]
                print(f"   PID: {pid}")
                break
else:
    print("❌ App failed to start")
    exit(1)

print("\n📋 Manual Integration Test:")
print("="*50)
print("1. Click on this terminal window")
print("2. Press Fn key (or use menu bar)")
print("3. Say: 'Um, so like, I want to schedule a meeting tomorrow'")
print("4. Press Fn again to stop")
print("5. Check if enhanced text appears (without 'um', 'like')")
print()
print("OR test voice commands:")
print("1. Type some text in any app")
print("2. Press Fn and say: 'delete last sentence'")
print("3. Check if last sentence gets deleted")

print("\n⏰ Monitoring app for 30 seconds...")
print("(Say something and see if AI processing logs appear)")

# Monitor stderr for AI processing logs
try:
    for i in range(30):
        if app_process.poll() is not None:
            print("❌ App crashed!")
            stdout, stderr = app_process.communicate()
            print("STDOUT:", stdout.decode()[:500])
            print("STDERR:", stderr.decode()[:500])
            break
        
        time.sleep(1)
        print(f"Waiting... {30-i}s remaining", end='\r')
    
    print("\n\n✅ Test complete!")
    print("\nTo verify AI features are working:")
    print("1. Check if fillers (um, uh, like) get removed")
    print("2. Try voice commands like 'delete last sentence'")
    print("3. Switch between Mail and Messages to test tone matching")
    
except KeyboardInterrupt:
    print("\n\n⚠️ Test interrupted")

finally:
    # Clean up
    app_process.terminate()
    time.sleep(1)
    subprocess.run(["pkill", "-f", "Zeus_STT Dev"], capture_output=True)