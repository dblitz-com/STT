#!/usr/bin/env python3
"""
Test openWakeWord with actual "alexa" audio samples.
Uses macOS built-in text-to-speech to generate realistic audio.
"""

import sys
import os
import subprocess
import numpy as np
import wave
import tempfile
from pathlib import Path

# Add current directory to path for wake_word_detector import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import TFLite compatibility wrapper BEFORE openWakeWord
try:
    import tflite_compat
except:
    pass

try:
    from openwakeword.model import Model as OpenWakeWordModel
    OPENWAKEWORD_AVAILABLE = True
    print("✅ openWakeWord available")
except Exception as e:
    OPENWAKEWORD_AVAILABLE = False
    print(f"❌ openWakeWord not available: {e}")
    sys.exit(1)

def generate_speech_audio(text: str, output_path: str, voice: str = "Alex") -> bool:
    """Generate audio using macOS built-in text-to-speech."""
    try:
        # Simple approach: generate AIFF first, then convert
        cmd = [
            "say", 
            "-v", voice,
            "-r", "150",  # Speaking rate (words per minute)
            "-o", output_path,
            text
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"❌ Text-to-speech failed: {result.stderr}")
            return False
        
        print(f"✅ Generated audio: {output_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error generating speech: {e}")
        return False

def convert_audio_to_int16(input_path: str, output_path: str) -> bool:
    """Convert audio to 16-bit PCM format expected by openWakeWord."""
    try:
        # Use ffmpeg to convert to the exact format needed
        cmd = [
            "ffmpeg", "-y",  # -y to overwrite output
            "-i", input_path,
            "-ar", "16000",  # 16kHz sample rate
            "-ac", "1",      # Mono
            "-f", "wav",     # WAV format
            "-acodec", "pcm_s16le",  # 16-bit PCM
            output_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"❌ Audio conversion failed: {result.stderr}")
            return False
        
        print(f"✅ Converted to 16-bit PCM: {output_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error converting audio: {e}")
        return False

def load_wav_as_int16(file_path: str) -> np.ndarray:
    """Load WAV file and return as int16 numpy array."""
    try:
        with wave.open(file_path, 'rb') as wav_file:
            # Verify format
            sample_rate = wav_file.getframerate()
            channels = wav_file.getnchannels()
            sample_width = wav_file.getsampwidth()
            
            print(f"📊 Audio info: {sample_rate}Hz, {channels}ch, {sample_width*8}-bit")
            
            if sample_rate != 16000:
                print(f"⚠️  Sample rate {sample_rate} != 16000, may cause issues")
            
            # Read audio data
            frames = wav_file.readframes(wav_file.getnframes())
            audio_np = np.frombuffer(frames, dtype=np.int16)
            
            # Convert to mono if stereo
            if channels == 2:
                audio_np = audio_np.reshape(-1, 2).mean(axis=1).astype(np.int16)
                print("🔄 Converted stereo to mono")
            
            print(f"📏 Audio length: {len(audio_np)} samples ({len(audio_np)/16000:.2f}s)")
            return audio_np
            
    except Exception as e:
        print(f"❌ Error loading WAV: {e}")
        return np.array([], dtype=np.int16)

def test_openWakeWord_with_audio(audio_data: np.ndarray, description: str) -> dict:
    """Test openWakeWord with given audio data."""
    try:
        # Initialize model
        model = OpenWakeWordModel(wakeword_models=['alexa'])
        print(f"\n🧪 Testing: {description}")
        
        # Ensure minimum length (pad with silence if needed)
        min_samples = 16000  # 1 second
        if len(audio_data) < min_samples:
            audio_data = np.pad(audio_data, (0, min_samples - len(audio_data)), mode='constant')
            print(f"🔄 Padded audio to {len(audio_data)} samples")
        
        # Run prediction
        prediction = model.predict(audio_data)
        
        # Analyze results
        max_confidence = max(prediction.values()) if prediction else 0.0
        print(f"📊 Results: {prediction}")
        print(f"🎯 Max confidence: {max_confidence:.4f}")
        
        if max_confidence > 0.1:
            print(f"✅ DETECTION! Confidence: {max_confidence:.4f}")
        else:
            print(f"❌ No detection (confidence: {max_confidence:.4f})")
        
        return prediction
        
    except Exception as e:
        print(f"❌ Error testing audio: {e}")
        return {}

def diagnose_openwakeword():
    """Diagnose openWakeWord model loading and configuration."""
    print("\n🔍 DIAGNOSING OPENWAKEWORD SETUP:")
    print("="*40)
    
    try:
        # Check what models are available
        print("📦 Initializing openWakeWord model...")
        model = OpenWakeWordModel(wakeword_models=['alexa'])
        
        # Check model details
        print(f"✅ Model loaded successfully")
        
        # Try to access model attributes
        if hasattr(model, 'models'):
            print(f"📊 Available models: {list(model.models.keys()) if model.models else 'None'}")
        
        if hasattr(model, 'inference_framework'):
            print(f"🧠 Inference framework: {model.inference_framework}")
        
        # Test with minimal audio
        print("🧪 Testing with silence...")
        silence = np.zeros(16000, dtype=np.int16)  # 1 second of silence
        result = model.predict(silence)
        print(f"🔇 Silence prediction: {result}")
        
        return model
        
    except Exception as e:
        print(f"❌ Model diagnosis failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Test openWakeWord with various audio samples."""
    print("🚀 Testing openWakeWord with actual 'alexa' audio samples")
    
    if not OPENWAKEWORD_AVAILABLE:
        print("❌ openWakeWord not available, cannot run tests")
        return
    
    # First diagnose the model
    model = diagnose_openwakeword()
    if model is None:
        print("❌ Cannot proceed without working model")
        return
    
    # Create temporary directory for audio files
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Test cases: different pronunciations and contexts
        test_cases = [
            ("alexa", "Alex"),      # Standard male voice
            ("alexa", "Samantha"),  # Female voice
            ("Alexa", "Alex"),      # Capitalized
            ("hey alexa", "Alex"),  # With wake phrase
            ("alexa wake up", "Alex"),  # With command
        ]
        
        results = []
        
        for text, voice in test_cases:
            print(f"\n{'='*50}")
            print(f"🎭 Testing: '{text}' with voice '{voice}'")
            
            # Generate paths
            raw_audio = temp_path / f"raw_{text.replace(' ', '_')}_{voice}.aiff"
            wav_audio = temp_path / f"converted_{text.replace(' ', '_')}_{voice}.wav"
            
            # Generate speech
            if not generate_speech_audio(text, str(raw_audio), voice):
                continue
            
            # Convert to proper format
            if not convert_audio_to_int16(str(raw_audio), str(wav_audio)):
                continue
            
            # Load and test
            audio_data = load_wav_as_int16(str(wav_audio))
            if len(audio_data) == 0:
                continue
            
            # Test with openWakeWord
            prediction = test_openWakeWord_with_audio(audio_data, f"'{text}' ({voice})")
            results.append({
                'text': text,
                'voice': voice,
                'prediction': prediction,
                'max_confidence': max(prediction.values()) if prediction else 0.0
            })
        
        # Summary
        print(f"\n{'='*50}")
        print("📊 SUMMARY OF ALL TESTS:")
        print(f"{'='*50}")
        
        best_result = None
        best_confidence = 0.0
        
        for result in results:
            confidence = result['max_confidence']
            status = "✅ DETECTED" if confidence > 0.1 else "❌ No detection"
            print(f"{status} - '{result['text']}' ({result['voice']}): {confidence:.4f}")
            
            if confidence > best_confidence:
                best_confidence = confidence
                best_result = result
        
        if best_result:
            print(f"\n🏆 Best result: '{best_result['text']}' ({best_result['voice']}) = {best_confidence:.4f}")
        else:
            print(f"\n❌ No successful detections found")
        
        print(f"\n🔍 ANALYSIS:")
        if best_confidence == 0.0:
            print("❌ All samples returned 0.0 confidence - possible issues:")
            print("   - Audio format mismatch (sample rate, bit depth)")
            print("   - Model initialization problem")
            print("   - openWakeWord version compatibility")
            print("   - Need actual training data vs. TTS audio")
        elif best_confidence < 0.1:
            print("⚠️  Low confidence scores - possible issues:")
            print("   - TTS audio doesn't match training data patterns")
            print("   - Need real human speech samples")
            print("   - Threshold too high for generated speech")
        else:
            print("✅ Some detections found - system working correctly")

if __name__ == "__main__":
    main()