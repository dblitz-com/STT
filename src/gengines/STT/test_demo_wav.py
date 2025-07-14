#!/usr/bin/env python3
"""
Test openWakeWord with official demo WAV files.
"""

import wave
import numpy as np
from openwakeword.model import Model as OpenWakeWordModel

def test_with_demo_wav():
    """Test with official demo audio from repo."""
    print("🚀 Testing with official demo WAV file...")
    
    # Load the demo WAV
    wav_path = "test_audio/jarvis_sample.wav"
    print(f"📁 Loading: {wav_path}")
    
    try:
        with wave.open(wav_path, 'rb') as wav_file:
            # Get audio parameters
            channels = wav_file.getnchannels()
            sample_width = wav_file.getsampwidth()
            framerate = wav_file.getframerate()
            n_frames = wav_file.getnframes()
            
            print(f"📊 Audio info:")
            print(f"   - Channels: {channels}")
            print(f"   - Sample width: {sample_width} bytes")
            print(f"   - Sample rate: {framerate} Hz")
            print(f"   - Duration: {n_frames/framerate:.2f} seconds")
            
            # Read audio data
            frames = wav_file.readframes(n_frames)
            
            # Convert to numpy array based on sample width
            if sample_width == 2:
                audio_np = np.frombuffer(frames, dtype=np.int16)
            elif sample_width == 4:
                audio_np = np.frombuffer(frames, dtype=np.int32)
                # Convert to int16
                audio_np = (audio_np / 65536).astype(np.int16)
            else:
                raise ValueError(f"Unsupported sample width: {sample_width}")
            
            # Handle stereo to mono if needed
            if channels == 2:
                audio_np = audio_np.reshape(-1, 2).mean(axis=1).astype(np.int16)
                print("   - Converted stereo to mono")
            
            # Calculate energy
            energy = np.sqrt(np.mean(audio_np.astype(np.float32)**2))
            print(f"   - RMS Energy: {energy:.2f}")
            print(f"   - Sample range: [{audio_np.min()}, {audio_np.max()}]")
        
        # Test with both ONNX and TFLite
        for framework in ['onnx', 'tflite']:
            print(f"\n{'='*50}")
            print(f"Testing with {framework.upper()} backend...")
            
            try:
                model = OpenWakeWordModel(
                    wakeword_models=['hey_jarvis'],
                    inference_framework=framework
                )
                print(f"✅ Model loaded with {framework}")
                
                # Process the audio
                result = model.predict(audio_np)
                confidence = result.get('hey_jarvis', 0.0)
                
                print(f"📊 Result: {result}")
                print(f"🎯 Confidence: {confidence:.4f}")
                
                if confidence > 0.1:
                    print(f"✅ DETECTION SUCCESS! Wake word detected!")
                else:
                    print(f"❌ No detection (threshold: 0.1)")
                    
            except Exception as e:
                print(f"❌ {framework} failed: {e}")
                
    except Exception as e:
        print(f"❌ Error loading WAV: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_with_demo_wav()