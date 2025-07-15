#!/usr/bin/env python3
"""
Simple test for Phase 4B VAD auto-stop functionality
"""

import subprocess
import time
import sys

print("🧪 Phase 4B VAD Auto-Stop Simple Test")
print("=====================================\n")

# Step 1: Verify app is running
print("1. Checking Zeus_STT Dev app...")
ps_result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
if 'Zeus_STT Dev.app' in ps_result.stdout:
    print("✅ App is running")
else:
    print("❌ App not running - please launch it first")
    sys.exit(1)

# Step 2: Test Python components directly
print("\n2. Testing VAD processor...")
vad_test = subprocess.run([
    '/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python',
    '/Applications/Zeus_STT Dev.app/Contents/Resources/vad_processor.py',
    '{"audio_samples": [0.1, 0.2, 0.1, -0.1, -0.2], "threshold": 0.3}'
], capture_output=True, text=True)

if vad_test.returncode == 0:
    print("✅ VAD processor works")
    print(f"   Output: {vad_test.stdout.strip()}")
else:
    print("❌ VAD processor failed")
    print(f"   Error: {vad_test.stderr}")

# Step 3: Monitor console output for Phase 4B activity
print("\n3. Monitoring app activity...")
print("📢 INSTRUCTIONS:")
print("   1. Click on any text field (this window is fine)")
print("   2. Say 'Hey Jarvis' clearly")
print("   3. Say a short message like 'Hello world'") 
print("   4. STOP speaking and wait 1-2 seconds")
print("   5. Text should auto-insert without pressing any buttons\n")

# Simple log monitoring using Console.app output
print("Monitoring for 20 seconds...\n")

# Track if we see expected behavior
phases_seen = {
    "wake_word": False,
    "recording_start": False,
    "vad_processing": False,
    "auto_stop": False
}

start_time = time.time()

# Use a simpler approach - check Console logs periodically
try:
    while time.time() - start_time < 20:
        # Get recent console output
        console_cmd = ['log', 'show', '--last', '5s', '--predicate', 'process == "STTDictate"']
        result = subprocess.run(console_cmd, capture_output=True, text=True, timeout=2)
        
        if result.returncode == 0 and result.stdout:
            lines = result.stdout.split('\n')
            for line in lines:
                if 'Phase 4B: Wake word' in line and 'detected' in line:
                    if not phases_seen["wake_word"]:
                        print("✅ Wake word detected!")
                        phases_seen["wake_word"] = True
                
                elif 'Phase 4B: Starting hands-free recording' in line:
                    if not phases_seen["recording_start"]:
                        print("✅ Recording started!")
                        phases_seen["recording_start"] = True
                
                elif 'Phase 4B VAD: Processing' in line:
                    if not phases_seen["vad_processing"]:
                        print("✅ VAD processing audio!")
                        phases_seen["vad_processing"] = True
                
                elif 'Phase 4B VAD: Extended silence detected' in line:
                    if not phases_seen["auto_stop"]:
                        print("✅ Auto-stop triggered!")
                        phases_seen["auto_stop"] = True
                        break
        
        time.sleep(0.5)
        
except KeyboardInterrupt:
    print("\nTest interrupted by user")
except Exception as e:
    print(f"\nLog monitoring error: {e}")
    print("Try running: log show --last 30s --predicate 'process == \"STTDictate\"'")

# Results
print("\n" + "="*50)
print("📊 Test Results:")
print("="*50)

all_passed = all(phases_seen.values())

for phase, seen in phases_seen.items():
    status = "✅" if seen else "❌"
    print(f"{status} {phase.replace('_', ' ').title()}")

print("\n" + "="*50)

if all_passed:
    print("✅ TEST PASSED: VAD auto-stop is working!")
else:
    print("❌ TEST FAILED: Some phases not detected")
    
    if not phases_seen["wake_word"]:
        print("\n🔍 Wake word not detected:")
        print("   - Say 'Hey Jarvis' more clearly")
        print("   - Wait 2 seconds before speaking")
        print("   - Check microphone permissions")
    elif not phases_seen["vad_processing"]:
        print("\n🔍 VAD not processing:")
        print("   - Wake word detected but VAD not called")
        print("   - Check handsFreeState transitions")
    elif not phases_seen["auto_stop"]:
        print("\n🔍 Auto-stop not triggered:")
        print("   - Make sure to pause after speaking")
        print("   - Wait at least 1 second of silence")

sys.exit(0 if all_passed else 1)