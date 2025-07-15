#!/usr/bin/env python3
"""
Final comprehensive test for Phase 4B VAD auto-stop
Tests all components and provides clear pass/fail status
"""

import subprocess
import time
import sys
import os

print("="*60)
print("🧪 PHASE 4B VAD AUTO-STOP - FINAL TEST")
print("="*60)

# Test results tracking
tests_passed = 0
tests_failed = 0

def test_component(name, command, expected_in_output=None, should_fail=False):
    """Run a test and track results"""
    global tests_passed, tests_failed
    
    print(f"\n📋 Testing: {name}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    
    success = False
    if should_fail:
        success = result.returncode != 0
    elif expected_in_output:
        success = expected_in_output in result.stdout or expected_in_output in result.stderr
    else:
        success = result.returncode == 0
    
    if success:
        print(f"✅ PASS: {name}")
        tests_passed += 1
    else:
        print(f"❌ FAIL: {name}")
        if result.stdout:
            print(f"   stdout: {result.stdout[:200]}")
        if result.stderr:
            print(f"   stderr: {result.stderr[:200]}")
        tests_failed += 1
    
    return success

# Test 1: Python environment
test_component(
    "Python 3.12 venv exists",
    "ls -la /Applications/Zeus_STT\\ Dev.app/Contents/Resources/venv_py312/bin/python",
    expected_in_output="python"
)

# Test 2: VAD processor
test_component(
    "VAD processor works",
    '/Applications/Zeus_STT\\ Dev.app/Contents/Resources/venv_py312/bin/python /Applications/Zeus_STT\\ Dev.app/Contents/Resources/vad_processor.py \'{"audio_samples": [0.1, -0.1], "threshold": 0.5}\'',
    expected_in_output="voice_detected"
)

# Test 3: Wake word detector
test_component(
    "Wake word detector works",
    '/Applications/Zeus_STT\\ Dev.app/Contents/Resources/venv_py312/bin/python /Applications/Zeus_STT\\ Dev.app/Contents/Resources/wake_word_detector.py \'{"audio_samples": [0.1, -0.1], "reset_buffer": false}\'',
    expected_in_output="wake_word_detected"
)

# Test 4: App binary exists
test_component(
    "App binary exists",
    "ls -la /Applications/Zeus_STT\\ Dev.app/Contents/MacOS/STTDictate",
    expected_in_output="STTDictate"
)

# Test 5: Launch app
print("\n🚀 Launching Zeus_STT Dev app...")
subprocess.Popen(["/Applications/Zeus_STT Dev.app/Contents/MacOS/STTDictate"], 
                 stdout=subprocess.DEVNULL, 
                 stderr=subprocess.DEVNULL)
time.sleep(3)

# Test 6: App is running
test_component(
    "App is running",
    "ps aux | grep 'Zeus_STT Dev' | grep -v grep",
    expected_in_output="STTDictate"
)

# Manual test instructions
print("\n" + "="*60)
print("📋 MANUAL TEST REQUIRED")
print("="*60)
print("\n👂 Please perform this test:")
print("1. Click on this terminal window (or any text field)")
print("2. Say 'Hey Jarvis' clearly")
print("3. Wait 2 seconds")
print("4. Say 'Hello world testing VAD'")
print("5. STOP speaking and wait 2 seconds")
print("\n❓ Did the text automatically insert without pressing any buttons? (y/n): ", end="", flush=True)

try:
    response = input().strip().lower()
    if response == 'y':
        print("✅ PASS: VAD auto-stop working!")
        tests_passed += 1
    else:
        print("❌ FAIL: VAD auto-stop not working")
        tests_failed += 1
except KeyboardInterrupt:
    print("\n⚠️  Test interrupted")
    tests_failed += 1

# Summary
print("\n" + "="*60)
print("📊 TEST SUMMARY")
print("="*60)
print(f"✅ Passed: {tests_passed}")
print(f"❌ Failed: {tests_failed}")
print(f"📊 Total:  {tests_passed + tests_failed}")

if tests_failed == 0:
    print("\n🎉 ALL TESTS PASSED! Phase 4B is working correctly!")
    sys.exit(0)
else:
    print("\n❌ Some tests failed. Phase 4B needs debugging.")
    print("\nDebugging suggestions:")
    print("1. Check Console.app for any STTDictate logs")
    print("2. Verify microphone permissions in System Settings")
    print("3. Make sure no other Zeus_STT instances are running")
    print("4. Try: pkill -f Zeus_STT && open '/Applications/Zeus_STT Dev.app'")
    sys.exit(1)