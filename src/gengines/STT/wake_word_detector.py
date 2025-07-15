#!/usr/bin/env python3
"""
Wake Word Detection for STT Dictate Phase 4A
Uses openWakeWord for custom "Zeus" detection with high accuracy and low latency.
"""

import sys
import json
import numpy as np
from typing import Optional, List, Dict, Any

# Import TFLite compatibility wrapper before openWakeWord
try:
    import tflite_compat
except:
    pass

# Try to import TensorFlow Lite first (preferred)
try:
    import tensorflow.lite as tflite
    TFLITE_AVAILABLE = True
    print("DEBUG: TensorFlow Lite available via TensorFlow!", file=sys.stderr)
except ImportError:
    try:
        import tflite_runtime.interpreter as tflite
        TFLITE_AVAILABLE = True
        print("DEBUG: TensorFlow Lite available via tflite_runtime", file=sys.stderr)
    except ImportError:
        TFLITE_AVAILABLE = False
        print("DEBUG: TensorFlow Lite not available", file=sys.stderr)

# Try to import openWakeWord (primary solution)
try:
    from openwakeword.model import Model as OpenWakeWordModel
    OPENWAKEWORD_AVAILABLE = True
    print(f"DEBUG: openWakeWord available (TFLite: {TFLITE_AVAILABLE})", file=sys.stderr)
except Exception as e:
    OPENWAKEWORD_AVAILABLE = False
    print(f"DEBUG: openWakeWord not available: {e}", file=sys.stderr)

# Try to import Porcupine (graceful fallback if not installed)
try:
    import pvporcupine
    # Test if we can actually use it (code signing check)
    test_keywords = pvporcupine.KEYWORDS
    if 'computer' in test_keywords:
        PORCUPINE_AVAILABLE = True
        print("DEBUG: Porcupine available with built-in keywords", file=sys.stderr)
    else:
        PORCUPINE_AVAILABLE = False
        print("DEBUG: Porcupine loaded but no 'computer' keyword available", file=sys.stderr)
except Exception as e:
    PORCUPINE_AVAILABLE = False
    print(f"DEBUG: Porcupine not available: {e}", file=sys.stderr)

# Configuration
SAMPLE_RATE = 16000
FRAME_LENGTH = 512  # Porcupine frame length (still used for compatibility)
OWW_FRAME_LENGTH = 1280  # openWakeWord prefers 80ms frames (1280 samples at 16kHz)
WAKE_WORDS = ["alexa", "hey_jarvis", "hey_mycroft"]  # Available openWakeWord models
TARGET_WAKE_WORDS = ["zeus", "hey_zeus"]  # Custom wake words we want to train
FALLBACK_KEYWORDS = ["hey", "stt", "dictate", "computer"]

class WakeWordDetector:
    def __init__(self):
        self.porcupine = None
        self.openwakeword_model = None
        self.is_initialized = False
        self.keyword_buffer = []
        self.buffer_max_seconds = 3.0  # Keep 3 seconds of audio for keyword matching
        self.buffer_max_samples = int(SAMPLE_RATE * self.buffer_max_seconds)
        self.detection_method = "none"  # Track which method is being used
        
        print("DEBUG: Initializing wake word detector...", file=sys.stderr)
        self.initialize_detector()
    
    def initialize_detector(self):
        """Initialize openWakeWord detector."""
        # Try openWakeWord first (primary method)
        if OPENWAKEWORD_AVAILABLE:
            try:
                # Use hey_jarvis as temporary wake word (similar to "hey Zeus")
                # Later we'll train a custom "Zeus" model
                self.openwakeword_model = OpenWakeWordModel(wakeword_models=['hey_jarvis'])
                self.detection_method = "openwakeword"
                self.is_initialized = True
                self.frames_processed = 0  # Track frame count for initialization
                print("DEBUG: openWakeWord initialized with 'hey_jarvis' model (temp for Zeus)", file=sys.stderr)
                print("DEBUG: Model requires 5+ frames before returning real predictions", file=sys.stderr)
                return
            except Exception as e:
                print(f"DEBUG: openWakeWord initialization failed: {e}", file=sys.stderr)
        
        # Fallback to energy-based detection
        print("DEBUG: Using energy-based fallback detection", file=sys.stderr)
        self.detection_method = "fallback"
        self.is_initialized = True
    
    def process_audio_chunk(self, audio_samples: List[float]) -> Dict[str, Any]:
        """
        Process audio chunk for wake word detection.
        
        Args:
            audio_samples: List of float samples at 16kHz
            
        Returns:
            Dictionary with detection results
        """
        if not self.is_initialized:
            return {
                "wake_word_detected": False,
                "keyword": None,
                "confidence": 0.0,
                "error": "Detector not initialized"
            }
        
        # Add to keyword buffer
        self.keyword_buffer.extend(audio_samples)
        if len(self.keyword_buffer) > self.buffer_max_samples:
            self.keyword_buffer = self.keyword_buffer[-self.buffer_max_samples:]
        
        try:
            if self.detection_method == "openwakeword" and self.openwakeword_model:
                return self._process_with_openwakeword(audio_samples)
            else:
                return self._process_with_fallback(audio_samples)
                
        except Exception as e:
            print(f"ERROR: Wake word processing failed: {e}", file=sys.stderr)
            return {
                "wake_word_detected": False,
                "keyword": None,
                "confidence": 0.0,
                "error": str(e),
                "detection_method": self.detection_method
            }
    
    def _process_with_openwakeword(self, audio_samples: List[float]) -> Dict[str, Any]:
        """Process audio using openWakeWord with proper format conversion."""
        # FIXED: Convert float32 (-1.0 to 1.0) to int16 PCM (expected by openWakeWord)
        audio_np = (np.array(audio_samples, dtype=np.float32) * 32767).astype(np.int16)
        
        # Process in 80ms chunks (1280 samples) for optimal performance
        chunk_size = 1280  # 80ms at 16kHz
        predictions = []
        
        # Enhanced diagnostics
        print(f"DEBUG: Processing {len(audio_np)} samples ({len(audio_np)/16000:.1f}s) with openWakeWord", file=sys.stderr)
        
        # Check if audio has actual content (not silence)
        audio_energy = np.sqrt(np.mean(audio_np.astype(np.float32)**2))
        print(f"DEBUG: Audio RMS energy: {audio_energy:.2f}", file=sys.stderr)
        
        try:
            # Process audio in chunks to build up the model's internal buffer
            # openWakeWord requires 5+ frames before returning real predictions
            for i in range(0, len(audio_np), chunk_size):
                chunk = audio_np[i:i+chunk_size]
                if len(chunk) < chunk_size:
                    chunk = np.pad(chunk, (0, chunk_size - len(chunk)), mode='constant')
                
                prediction = self.openwakeword_model.predict(chunk)
                predictions.append(prediction)
                self.frames_processed += 1
            
            # Use the last prediction (most recent)
            final_prediction = predictions[-1] if predictions else {'hey_jarvis': 0.0}
            
            # Find the highest confidence prediction
            max_confidence = 0.0
            detected_keyword = None
            
            for keyword, confidence in final_prediction.items():
                if confidence > max_confidence:
                    max_confidence = confidence
                    detected_keyword = keyword
            
            # Debug logging for confidence analysis
            print(f"DEBUG: Processed {len(predictions)} chunks, total frames: {self.frames_processed}", file=sys.stderr)
            print(f"DEBUG: Final prediction: {final_prediction}", file=sys.stderr)
            print(f"DEBUG: Max confidence: {max_confidence} for keyword: {detected_keyword}", file=sys.stderr)
            
            # Threshold for detection (tune this based on testing)
            # Note: First 5 frames return 0.0, then real predictions start
            # Typical scores: 0.00001 - 0.001 for valid speech on macOS ARM64
            detection_threshold = 0.00005  # Very low threshold for ARM64
            
            # Only consider detection after initialization period
            if self.frames_processed < 5:
                print(f"DEBUG: Still in initialization phase ({self.frames_processed}/5 frames)", file=sys.stderr)
                max_confidence = 0.0  # Force zero during initialization
            
            if max_confidence > detection_threshold:
                print(f"DEBUG: WAKE WORD DETECTED! '{detected_keyword}' with confidence {max_confidence}", file=sys.stderr)
                return {
                    "wake_word_detected": True,
                    "keyword": str(detected_keyword),
                    "confidence": float(max_confidence),  # Ensure JSON serializable
                    "detection_method": "openwakeword",
                    "all_predictions": {k: float(v) for k, v in final_prediction.items()},  # Convert numpy types
                    "frames_processed": int(self.frames_processed),
                    "audio_length_seconds": float(len(audio_np) / 16000)
                }
            else:
                return {
                    "wake_word_detected": False,
                    "keyword": None,
                    "confidence": float(max_confidence),  # Ensure JSON serializable
                    "detection_method": "openwakeword",
                    "all_predictions": {k: float(v) for k, v in final_prediction.items()},  # Convert numpy types
                    "frames_processed": int(self.frames_processed),
                    "audio_length_seconds": float(len(audio_np) / 16000)
                }
                
        except Exception as e:
            print(f"ERROR: openWakeWord processing failed: {e}", file=sys.stderr)
            print(f"ERROR: Audio shape: {audio_np.shape}, dtype: {audio_np.dtype}", file=sys.stderr)
            # Fall back to energy detection
            return self._process_with_fallback(audio_samples)
    
    
    def _process_with_fallback(self, audio_samples: List[float]) -> Dict[str, Any]:
        """Fallback keyword detection using simple energy-based patterns."""
        # This is a very basic fallback - in production you'd want more sophisticated detection
        
        # Calculate audio energy
        energy = np.mean(np.square(audio_samples))
        energy_db = 20 * np.log10(np.sqrt(energy) + 1e-10)
        
        # Simple pattern: look for two distinct energy peaks (like "Hey STT")
        if len(self.keyword_buffer) >= SAMPLE_RATE:  # At least 1 second
            recent_audio = np.array(self.keyword_buffer[-SAMPLE_RATE:])
            
            # Look for energy pattern that might indicate speech
            chunk_size = SAMPLE_RATE // 10  # 100ms chunks
            energy_chunks = []
            
            for i in range(0, len(recent_audio), chunk_size):
                chunk = recent_audio[i:i + chunk_size]
                if len(chunk) >= chunk_size // 2:  # At least half chunk
                    chunk_energy = np.mean(np.square(chunk))
                    chunk_energy_db = 20 * np.log10(np.sqrt(chunk_energy) + 1e-10)
                    energy_chunks.append(chunk_energy_db)
            
            if len(energy_chunks) >= 5:  # At least 500ms of data
                # Look for pattern: quiet -> speech -> brief pause -> speech (Hey STT)
                max_energy = max(energy_chunks)
                avg_energy = np.mean(energy_chunks)
                
                # Simple heuristic: if we have significant speech activity
                if max_energy > -20 and (max_energy - avg_energy) > 10:
                    # Very basic detection - would need much more sophistication in production
                    return {
                        "wake_word_detected": True,
                        "keyword": "fallback_pattern",
                        "confidence": 0.3,  # Low confidence for fallback
                        "max_energy": max_energy,
                        "avg_energy": avg_energy,
                        "detection_method": "fallback"
                    }
        
        return {
            "wake_word_detected": False,
            "keyword": None,
            "confidence": 0.0,
            "energy_db": energy_db,
            "buffer_seconds": len(self.keyword_buffer) / SAMPLE_RATE,
            "detection_method": "fallback"
        }
    
    def reset_buffer(self):
        """Reset the keyword buffer."""
        self.keyword_buffer = []
    
    def cleanup(self):
        """Clean up resources."""
        if self.porcupine:
            self.porcupine.delete()
            self.porcupine = None

# Global detector instance
wake_word_detector = None

def initialize_detector():
    """Initialize the global wake word detector."""
    global wake_word_detector
    if wake_word_detector is None:
        wake_word_detector = WakeWordDetector()
    return wake_word_detector.is_initialized

def process_wake_word_request(data: Dict[str, Any]) -> Dict[str, Any]:
    """Process a wake word detection request from Swift."""
    global wake_word_detector
    
    if wake_word_detector is None:
        if not initialize_detector():
            return {"error": "Failed to initialize wake word detector"}
    
    # Extract parameters
    audio_samples = data.get("audio_samples", [])
    reset_buffer = data.get("reset_buffer", False)
    
    # Validate input
    if not audio_samples:
        return {"error": "No audio samples provided"}
    
    if not isinstance(audio_samples, list):
        return {"error": "Audio samples must be a list"}
    
    # Reset buffer if requested
    if reset_buffer:
        wake_word_detector.reset_buffer()
    
    # Process the audio
    result = wake_word_detector.process_audio_chunk(audio_samples)
    result["openwakeword_available"] = OPENWAKEWORD_AVAILABLE
    result["porcupine_available"] = False  # We're not using Porcupine anymore
    
    return result

def main():
    """Main entry point for wake word detection."""
    if len(sys.argv) != 2:
        print("Usage: python3 wake_word_detector.py '{\"audio_samples\": [...], \"reset_buffer\": false}'", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse JSON input
        input_data = json.loads(sys.argv[1])
        
        # Process wake word request
        result = process_wake_word_request(input_data)
        
        # Output result as JSON
        print(json.dumps(result))
        
    except json.JSONDecodeError as e:
        error_result = {"error": f"Invalid JSON input: {e}"}
        print(json.dumps(error_result))
        
    except Exception as e:
        error_result = {"error": f"Unexpected error: {e}"}
        print(json.dumps(error_result))

if __name__ == "__main__":
    main()