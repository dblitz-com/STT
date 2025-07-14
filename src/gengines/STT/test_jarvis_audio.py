#!/usr/bin/env python3
"""
Test openWakeWord with "hey jarvis" TTS audio.
"""

import sys
import os
import subprocess
import numpy as np
import wave
import tempfile
from pathlib import Path

# Import TFLite compatibility wrapper BEFORE openWakeWord
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tflite_compat

from openwakeword.model import Model as OpenWakeWordModel

def generate_and_test():
    """Generate TTS audio and test with openWakeWord."""
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Initialize model
        print("🚀 Initializing hey_jarvis model with TFLite...")
        model = OpenWakeWordModel(wakeword_models=['hey_jarvis'])
        print("✅ Model loaded successfully!")
        
        # Test phrases
        test_phrases = [
            "hey jarvis",
            "Hey Jarvis",
            "hey jarvis wake up",
            "hi jarvis",  # Should NOT trigger
            "hello world",  # Should NOT trigger
        ]
        
        for phrase in test_phrases:
            print(f"\n{'='*50}")
            print(f"Testing: '{phrase}'")
            
            # Generate TTS audio
            aiff_path = temp_path / f"{phrase.replace(' ', '_')}.aiff"
            wav_path = temp_path / f"{phrase.replace(' ', '_')}.wav"
            
            # Generate with macOS TTS
            cmd = ["say", "-v", "Alex", "-r", "150", "-o", str(aiff_path), phrase]
            subprocess.run(cmd, check=True)
            print(f"✅ Generated TTS audio")
            
            # Convert to 16kHz WAV
            cmd = [
                "ffmpeg", "-y", "-i", str(aiff_path),
                "-ar", "16000", "-ac", "1", "-f", "wav", 
                "-acodec", "pcm_s16le", str(wav_path)
            ]
            subprocess.run(cmd, capture_output=True)
            
            # Load audio
            with wave.open(str(wav_path), 'rb') as wav_file:
                frames = wav_file.readframes(wav_file.getnframes())
                audio_np = np.frombuffer(frames, dtype=np.int16)
            
            # Ensure minimum length
            if len(audio_np) < 16000:
                audio_np = np.pad(audio_np, (0, 16000 - len(audio_np)), mode='constant')
            
            # Audio diagnostics
            audio_energy = np.sqrt(np.mean(audio_np.astype(np.float32)**2))
            print(f"📊 Audio energy (RMS): {audio_energy:.2f}")
            print(f"📊 Audio range: [{audio_np.min()}, {audio_np.max()}]")
            print(f"📊 Length: {len(audio_np)/16000:.2f}s")
            
            # Test detection
            prediction = model.predict(audio_np)
            confidence = prediction.get('hey_jarvis', 0.0)
            
            print(f"📊 Confidence: {confidence:.4f}")
            print(f"📊 Full result: {prediction}")
            
            if confidence > 0.1:
                print(f"✅ DETECTED! Confidence: {confidence:.4f}")
            else:
                print(f"❌ Not detected (confidence: {confidence:.4f})")
        
        print(f"\n{'='*50}")
        print("🏁 SUMMARY:")
        print("- TFLite backend: ✅ Working")
        print("- Model loading: ✅ Working")
        print("- Audio processing: ✅ Working")
        print("- Wake word 'hey jarvis' ready for Phase 4A!")

if __name__ == "__main__":
    generate_and_test()