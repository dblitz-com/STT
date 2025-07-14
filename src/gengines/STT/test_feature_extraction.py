#!/usr/bin/env python3
"""
Test the full openWakeWord pipeline including feature extraction.
"""

import numpy as np
import onnxruntime as ort
from openwakeword.model import Model as OpenWakeWordModel

def test_melspectrogram_model():
    """Test if the melspectrogram feature extraction is working."""
    print("🔍 Testing melspectrogram feature extraction...")
    
    model_path = "/Users/devin/dblitz/engine/src/gengines/STT/venv_py312/lib/python3.12/site-packages/openwakeword/resources/models/melspectrogram.onnx"
    
    try:
        # Load melspectrogram model
        session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])
        
        print("✅ Melspectrogram model loaded")
        
        # Check inputs/outputs
        for inp in session.get_inputs():
            print(f"📊 Input: {inp.name}, shape={inp.shape}, dtype={inp.type}")
            
        for out in session.get_outputs():
            print(f"📊 Output: {out.name}, shape={out.shape}, dtype={out.type}")
            
        # Create test input
        # Usually mel-spectrogram models expect raw audio
        test_audio = np.random.randn(1, 1280).astype(np.float32)  # 80ms at 16kHz
        
        # Run inference
        outputs = session.run(None, {'x.1': test_audio})
        print(f"\n📊 Melspectrogram output shape: {outputs[0].shape}")
        print(f"📊 Output range: [{outputs[0].min():.4f}, {outputs[0].max():.4f}]")
        
        return outputs[0]
        
    except Exception as e:
        print(f"❌ Melspectrogram failed: {e}")
        return None

def debug_full_pipeline():
    """Debug the complete openWakeWord pipeline."""
    print("\n🚀 Debugging full openWakeWord pipeline...")
    
    # Enable debug logging
    import logging
    logging.basicConfig(level=logging.DEBUG)
    
    try:
        # Initialize model with verbose output
        print("📦 Initializing openWakeWord model...")
        model = OpenWakeWordModel(
            wakeword_models=['hey_jarvis'],
            inference_framework='onnx'
        )
        
        # Check model internals
        if hasattr(model, 'models'):
            print(f"📊 Loaded models: {list(model.models.keys())}")
            
        if hasattr(model, 'prediction_buffer'):
            print(f"📊 Prediction buffer: {model.prediction_buffer}")
            
        # Generate test audio with known properties
        duration = 2.0  # seconds
        sample_rate = 16000
        n_samples = int(duration * sample_rate)
        
        # Create a simple tone that should produce non-zero mel-spectrogram
        t = np.linspace(0, duration, n_samples)
        frequency = 440  # A4 note
        audio = np.sin(2 * np.pi * frequency * t) * 5000
        audio_int16 = audio.astype(np.int16)
        
        print(f"\n🎵 Test audio: {frequency}Hz tone, {duration}s")
        print(f"📊 Audio shape: {audio_int16.shape}")
        print(f"📊 Audio range: [{audio_int16.min()}, {audio_int16.max()}]")
        
        # Process with model
        result = model.predict(audio_int16)
        print(f"\n📊 Prediction result: {result}")
        
        # Try to access internal buffers if available
        if hasattr(model, 'melspectrogram_buffer'):
            print(f"📊 Mel buffer shape: {model.melspectrogram_buffer.shape if hasattr(model.melspectrogram_buffer, 'shape') else 'N/A'}")
            
    except Exception as e:
        print(f"❌ Pipeline error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    # Test melspectrogram first
    mel_output = test_melspectrogram_model()
    
    # Then test full pipeline
    debug_full_pipeline()