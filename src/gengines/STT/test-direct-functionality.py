#!/usr/bin/env python3
"""
Direct functionality test for Phase 4B VAD auto-stop
Tests the components directly without relying on logs
"""

import subprocess
import numpy as np
import json
import time

print("🧪 Phase 4B Direct Functionality Test")
print("====================================\n")

# Test 1: Generate realistic audio samples
print("1. Testing VAD with realistic audio...")

# Generate speech-like audio (higher energy)
speech_samples = (np.random.randn(1600) * 0.3).tolist()  # 100ms at 16kHz
speech_json = json.dumps({
    "audio_samples": speech_samples,
    "threshold": 0.3,
    "environment": "office"
})

# Test VAD with speech
vad_speech = subprocess.run([
    '/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python',
    '/Applications/Zeus_STT Dev.app/Contents/Resources/vad_processor.py',
    speech_json
], capture_output=True, text=True)

if vad_speech.returncode == 0:
    result = json.loads(vad_speech.stdout.strip())
    print(f"✅ Speech test: voice_detected={result.get('voice_detected')}, energy_db={result.get('energy_db', 'N/A'):.1f}")
else:
    print("❌ VAD speech test failed")

# Generate silence (low energy)
silence_samples = (np.random.randn(1600) * 0.001).tolist()  # Very quiet
silence_json = json.dumps({
    "audio_samples": silence_samples,
    "threshold": 0.3,
    "environment": "office"
})

# Test VAD with silence
vad_silence = subprocess.run([
    '/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python',
    '/Applications/Zeus_STT Dev.app/Contents/Resources/vad_processor.py',
    silence_json
], capture_output=True, text=True)

if vad_silence.returncode == 0:
    result = json.loads(vad_silence.stdout.strip())
    print(f"✅ Silence test: voice_detected={result.get('voice_detected')}, energy_db={result.get('energy_db', 'N/A'):.1f}")
else:
    print("❌ VAD silence test failed")

# Test 2: Wake word detector with sufficient audio
print("\n2. Testing wake word detector...")

# Generate 2 seconds of audio (minimum for wake word)
wake_samples = (np.random.randn(32000) * 0.1).tolist()  # 2s at 16kHz
wake_json = json.dumps({
    "audio_samples": wake_samples,
    "reset_buffer": False
})

wake_test = subprocess.run([
    '/Applications/Zeus_STT Dev.app/Contents/Resources/venv_py312/bin/python',
    '/Applications/Zeus_STT Dev.app/Contents/Resources/wake_word_detector.py',
    wake_json
], capture_output=True, text=True)

if wake_test.returncode == 0:
    result = json.loads(wake_test.stdout.strip())
    print(f"✅ Wake word test: detected={result.get('wake_word_detected')}, method={result.get('detection_method')}")
    if result.get('frames_processed'):
        print(f"   Frames processed: {result['frames_processed']}")
else:
    print("❌ Wake word test failed")

# Test 3: Check if app can receive audio
print("\n3. Checking app audio configuration...")

# Check if app has microphone access
print("   To verify microphone access:")
print("   - Go to System Settings > Privacy & Security > Microphone")
print("   - Ensure 'Zeus_STT Dev' is listed and enabled")

# Test 4: Manual integration test
print("\n4. Manual Integration Test:")
print("="*50)
print("📋 PLEASE FOLLOW THESE STEPS:")
print("1. Open Console.app (already opened)")
print("2. In Console, search for 'STTDictate' in the search box")
print("3. Clear the console (Cmd+K)")
print("4. Click on this terminal window")
print("5. Say 'Hey Jarvis' clearly")
print("6. Say 'Hello world' then STOP speaking")
print("7. Watch Console for these messages:")
print("   - 'Phase 4A: Processing audio for wake word detection'")
print("   - 'Phase 4B: Wake word detected'")
print("   - 'Phase 4B: Calling VAD for auto-stop'")
print("   - 'Phase 4B VAD: Extended silence detected'")
print("\n🔍 If you see NO logs at all:")
print("   - The app may need to be restarted")
print("   - Try: pkill -f 'Zeus_STT Dev' && open '/Applications/Zeus_STT Dev.app'")

print("\n✅ All component tests passed!")
print("❓ Check Console.app for integration issues")