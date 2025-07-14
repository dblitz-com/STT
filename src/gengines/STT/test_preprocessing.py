#!/usr/bin/env python3
"""
Test with openWakeWord's internal preprocessing to ensure compatibility.
"""

import numpy as np
from openwakeword.model import Model
import logging

# Enable debug logging
logging.basicConfig(level=logging.DEBUG)

def test_with_preprocessing():
    """Test using openWakeWord's exact preprocessing pipeline."""
    print("🚀 Testing with openWakeWord preprocessing...")
    
    # Initialize model
    model = Model(wakeword_models=['hey_jarvis'], inference_framework='onnx')
    print("✅ Model initialized")
    
    # Test 1: Very short audio (might be filtered)
    short_audio = np.zeros(800, dtype=np.int16)  # 0.05 seconds
    result = model.predict(short_audio)
    print(f"\nTest 1 - Very short audio (0.05s): {result}")
    
    # Test 2: Exactly 1 second of audio
    one_sec = np.zeros(16000, dtype=np.int16)
    # Add a click in the middle
    one_sec[8000:8100] = 10000
    result = model.predict(one_sec)
    print(f"Test 2 - 1 second with click: {result}")
    
    # Test 3: Multiple predictions to build up buffer
    print("\nTest 3 - Building up prediction buffer:")
    # Generate 10 seconds of audio in 1-second chunks
    for i in range(10):
        # Create varying energy levels
        chunk = np.random.randn(16000) * (i * 500)
        chunk = chunk.astype(np.int16)
        result = model.predict(chunk)
        print(f"  Chunk {i}: energy={np.std(chunk):.1f}, result={result}")
        
        # Check if prediction buffer is accumulating
        if hasattr(model, 'prediction_buffer'):
            buffer_info = {k: len(v) if hasattr(v, '__len__') else v 
                          for k, v in model.prediction_buffer.items()}
            print(f"    Buffer state: {buffer_info}")
    
    # Test 4: Real speech pattern
    print("\nTest 4 - Speech-like pattern:")
    # Simulate speech with amplitude modulation
    t = np.linspace(0, 2, 32000)
    # Speech envelope (slow modulation)
    envelope = np.sin(2 * np.pi * 2 * t) * 0.5 + 0.5
    # Carrier frequencies (formants)
    speech = (
        np.sin(2 * np.pi * 300 * t) +  # F1
        np.sin(2 * np.pi * 1000 * t) * 0.7 +  # F2  
        np.sin(2 * np.pi * 2500 * t) * 0.5    # F3
    ) * envelope * 3000
    speech_int16 = speech.astype(np.int16)
    
    result = model.predict(speech_int16)
    print(f"Speech pattern result: {result}")
    
    # Test 5: Check model state
    print("\nModel state inspection:")
    if hasattr(model, 'models'):
        for name, mdl in model.models.items():
            print(f"  Model '{name}': {type(mdl)}")
    
    if hasattr(model, 'get_prediction_frames'):
        try:
            frames = model.get_prediction_frames()
            print(f"  Prediction frames available: {len(frames) if frames else 0}")
        except:
            pass

if __name__ == "__main__":
    test_with_preprocessing()