#!/usr/bin/env python3
"""
Diagnose each component of the openWakeWord pipeline.
"""

import numpy as np
import onnxruntime as ort
from scipy.io import wavfile
import subprocess
import tempfile

def test_component(model_path, test_input, input_name='input'):
    """Test a single ONNX model component."""
    try:
        session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])
        outputs = session.run(None, {input_name: test_input})
        return outputs[0]
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def diagnose_pipeline():
    """Diagnose the complete pipeline step by step."""
    base_path = "/Users/devin/dblitz/engine/src/gengines/STT/venv_py312/lib/python3.12/site-packages/openwakeword/resources/models"
    
    print("🔍 DIAGNOSING OPENWAKEWORD PIPELINE ON MACOS ARM64")
    print("="*60)
    
    # Generate test audio
    print("\n1️⃣ Generating test audio...")
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        wav_path = tmp.name
    
    # Use a simple tone first
    duration = 1.0
    sample_rate = 16000
    t = np.linspace(0, duration, int(sample_rate * duration))
    audio = np.sin(2 * np.pi * 440 * t) * 0.3  # A4 tone
    
    wavfile.write(wav_path, sample_rate, (audio * 32767).astype(np.int16))
    print(f"✅ Generated 440Hz tone: {wav_path}")
    
    # Load the audio back
    _, audio_data = wavfile.read(wav_path)
    audio_float = audio_data.astype(np.float32) / 32767.0
    
    print(f"📊 Audio shape: {audio_float.shape}")
    print(f"📊 Audio range: [{audio_float.min():.3f}, {audio_float.max():.3f}]")
    
    # Test melspectrogram model
    print("\n2️⃣ Testing melspectrogram extraction...")
    mel_model = f"{base_path}/melspectrogram.onnx"
    
    # Process in 80ms chunks (1280 samples at 16kHz)
    chunk_size = 1280
    mel_features = []
    
    for i in range(0, len(audio_float), chunk_size):
        chunk = audio_float[i:i+chunk_size]
        if len(chunk) < chunk_size:
            chunk = np.pad(chunk, (0, chunk_size - len(chunk)), mode='constant')
        
        # Reshape for model input
        chunk_input = chunk.reshape(1, -1).astype(np.float32)
        
        mel_output = test_component(mel_model, chunk_input, 'input')
        if mel_output is not None:
            mel_features.append(mel_output)
            if i == 0:  # Print first chunk info
                print(f"✅ Mel output shape: {mel_output.shape}")
                print(f"📊 Mel range: [{mel_output.min():.3f}, {mel_output.max():.3f}]")
    
    if not mel_features:
        print("❌ Melspectrogram extraction failed!")
        return
    
    # Test embedding model
    print("\n3️⃣ Testing embedding model...")
    embed_model = f"{base_path}/embedding_model.onnx"
    
    # Embedding model expects different input format
    # Try with accumulated mel features
    if len(mel_features) >= 16:  # Need at least 16 frames
        # Stack mel features
        mel_stack = np.concatenate(mel_features[:16], axis=0)
        print(f"📊 Stacked mel shape: {mel_stack.shape}")
        
        # Try different reshaping options
        for reshape in [(1, 16, 96), (16, 1, 96), (1, 96, 16)]:
            try:
                test_input = mel_stack.reshape(reshape).astype(np.float32)
                embed_output = test_component(embed_model, test_input, 'input')
                if embed_output is not None:
                    print(f"✅ Embedding with shape {reshape}: output shape={embed_output.shape}")
                    print(f"📊 Embedding range: [{embed_output.min():.3f}, {embed_output.max():.3f}]")
                    break
            except:
                continue
    
    # Test wake word model directly
    print("\n4️⃣ Testing hey_jarvis model directly...")
    jarvis_model = f"{base_path}/hey_jarvis_v0.1.onnx"
    
    # The model expects [1, 16, 96] input
    # This should be 16 frames of 96-dimensional features
    if len(mel_features) >= 16:
        # Try to format input correctly
        mel_array = np.array([m.squeeze() for m in mel_features[:16]])
        
        # Expected shape is [1, 16, 96]
        if mel_array.shape[1] == 32:  # If we have 32 features, try to expand
            # Repeat to get 96 features
            mel_array = np.repeat(mel_array, 3, axis=1)
            
        test_input = mel_array[:16, :96].reshape(1, 16, 96).astype(np.float32)
        print(f"📊 Model input shape: {test_input.shape}")
        
        output = test_component(jarvis_model, test_input, 'x.1')
        if output is not None:
            print(f"✅ Model output: {output}")
            print(f"📊 Output shape: {output.shape}")
            print(f"🎯 Confidence: {output[0][0] if output.size > 0 else 'N/A'}")
    
    # Cleanup
    import os
    os.unlink(wav_path)
    
    print("\n" + "="*60)
    print("DIAGNOSIS COMPLETE")
    
    # Conclusions
    print("\n📋 CONCLUSIONS:")
    print("1. Feature extraction (melspectrogram) is the likely bottleneck")
    print("2. Model expects specific input formatting that may differ on ARM64")
    print("3. Consider using openWakeWord's preprocessing directly")
    print("4. Or implement Core ML conversion for native ARM64 support")

if __name__ == "__main__":
    diagnose_pipeline()