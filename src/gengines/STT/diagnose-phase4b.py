#!/usr/bin/env python3
"""
Diagnostic script for Phase 4B VAD issues
"""

import subprocess
import sys
import os
import time

print("🔍 Phase 4B Diagnostic Tool")
print("===========================\n")

# Check if Zeus_STT Dev is running
print("1. Checking if Zeus_STT Dev is running...")
ps_result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
if 'Zeus_STT Dev.app' in ps_result.stdout:
    print("✅ Zeus_STT Dev is running")
    # Extract PID
    for line in ps_result.stdout.split('\n'):
        if 'Zeus_STT Dev.app' in line and 'STTDictate' in line:
            parts = line.split()
            if len(parts) > 1:
                pid = parts[1]
                print(f"   PID: {pid}")
else:
    print("❌ Zeus_STT Dev is NOT running")
    print("   Please launch the app first!")
    sys.exit(1)

# Check Console logs
print("\n2. Checking Console logs for errors...")
print("   Looking for recent Phase 4B activity...\n")

# Try to capture recent logs using log command
try:
    # Use simpler log command syntax
    log_cmd = ['log', 'stream', '--process', 'STTDictate', '--level', 'debug']
    print("   Starting log stream (say 'Hey Jarvis' now)...")
    print("   Press Ctrl+C after testing to see summary\n")
    
    # Start log stream in background
    proc = subprocess.Popen(log_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    # Collect logs for analysis
    logs = []
    phase4b_logs = []
    
    try:
        start_time = time.time()
        while time.time() - start_time < 15:  # Collect for 15 seconds
            line = proc.stdout.readline()
            if line:
                logs.append(line.strip())
                if 'Phase 4B' in line or 'VAD' in line or 'wake word' in line:
                    phase4b_logs.append(line.strip())
                    print(f"   📝 {line.strip()}")
    except KeyboardInterrupt:
        pass
    
    proc.terminate()
    
    print(f"\n3. Analysis Summary:")
    print(f"   Total log lines: {len(logs)}")
    print(f"   Phase 4B related: {len(phase4b_logs)}")
    
    # Look for specific issues
    issues_found = []
    
    # Check for wake word detection
    wake_word_detected = any('wake word' in log.lower() and 'detected' in log.lower() for log in phase4b_logs)
    if not wake_word_detected:
        issues_found.append("No wake word detection logged")
    
    # Check for VAD processing
    vad_processing = any('Phase 4B VAD' in log for log in phase4b_logs)
    if not vad_processing:
        issues_found.append("No VAD processing for auto-stop")
    
    # Check for errors
    errors = [log for log in logs if 'error' in log.lower() or 'fail' in log.lower()]
    if errors:
        issues_found.append(f"Found {len(errors)} error messages")
    
    if issues_found:
        print("\n❌ Issues found:")
        for issue in issues_found:
            print(f"   - {issue}")
    else:
        print("\n✅ No obvious issues found")
    
    # Show recent Phase 4B logs
    if phase4b_logs:
        print("\n📋 Recent Phase 4B activity:")
        for log in phase4b_logs[-10:]:  # Last 10 relevant logs
            print(f"   {log}")
    
except Exception as e:
    print(f"⚠️  Could not analyze logs: {e}")
    print("   Try running: log stream --process STTDictate")

print("\n4. Quick Fix Suggestions:")
print("   a) If wake word not detecting:")
print("      - Say 'Hey Jarvis' clearly and wait 2 seconds")
print("      - Check microphone permissions in System Settings")
print("   b) If VAD not auto-stopping:")
print("      - Ensure you pause after speaking (500ms silence)")
print("      - Check if recording starts but doesn't stop")
print("   c) General issues:")
print("      - Restart the app: pkill -f 'Zeus_STT Dev' && open '/Applications/Zeus_STT Dev.app'")
print("      - Check Console.app for detailed logs")