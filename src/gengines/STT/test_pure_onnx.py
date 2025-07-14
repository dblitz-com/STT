#!/usr/bin/env python3
"""
Test openWakeWord with pure ONNX backend (no TFLite wrapper).
"""

import sys
import os
import numpy as np
from pathlib import Path

# Ensure we're NOT importing tflite_compat
if 'tflite_compat' in sys.modules:
    del sys.modules['tflite_compat']

from openwakeword.model import Model as OpenWakeWordModel

def test_pure_onnx():
    """Test with forced ONNX backend."""
    print("🚀 Testing openWakeWord with pure ONNX backend...")
    
    try:
        # Force ONNX inference framework
        model = OpenWakeWordModel(
            wakeword_models=['hey_jarvis'],
            inference_framework='onnx'  # Explicitly use ONNX
        )
        print(f"✅ Model loaded with ONNX backend")
        print(f"📊 Inference framework: {getattr(model, 'inference_framework', 'unknown')}")
        
        # Test 1: Silence baseline
        silence = np.zeros(16000, dtype=np.int16)
        result = model.predict(silence)
        print(f"\nTest 1 - Silence: {result}")
        
        # Test 2: Generate more realistic speech-like audio
        # Create a pattern that mimics speech energy variations
        t = np.linspace(0, 1, 16000)
        # Speech-like amplitude envelope
        envelope = np.sin(2 * np.pi * 3 * t) * 0.5 + 0.5
        # Add formant-like frequencies
        speech = (
            np.sin(2 * np.pi * 200 * t) * 0.3 +  # Low formant
            np.sin(2 * np.pi * 800 * t) * 0.5 +  # Mid formant
            np.sin(2 * np.pi * 2400 * t) * 0.2   # High formant
        ) * envelope
        # Scale to int16 range
        speech_int16 = (speech * 5000).astype(np.int16)
        
        result = model.predict(speech_int16)
        print(f"Test 2 - Speech-like audio: {result}")
        
        # Test 3: White noise with speech energy
        noise = np.random.randn(16000) * 3000
        noise_int16 = noise.astype(np.int16)
        result = model.predict(noise_int16)
        print(f"Test 3 - White noise: {result}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_pure_onnx()